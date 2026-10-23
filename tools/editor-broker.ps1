#requires -Version 5.1
<#
Unity Game Agent editor broker CLI: several agents share ONE Unity Editor.
State lives in <project>/Library/UgaBroker and is executed by the com.neoxider.uga-editor-broker
package inside the Editor. This CLI works while the Editor compiles, reloads, plays or is closed.
Written for Windows PowerShell 5.1 and PowerShell 7+ (pwsh on macOS/Linux); tested on 5.1. See tools/shared-editor.md.

Exit codes: 0 ok | 2 invalid request | 3 lease queued | 4 gate says wait | 6 timeout |
7 Editor offline | 8 job failed | 9 job blocked/canceled or doctor not ready.
#>
param(
    [Parameter(Position=0)]
    [ValidateSet('install','doctor','session','take','renew','release','yield','gate','stage','request','wait','done','cancel','status','projects')]
    [string]$Command = 'status',
    [Parameter(Position=1)][string]$Action,
    # Several projects on one machine: give every agent its project explicitly (this parameter,
    # UGA_PROJECT_ROOT, or the Unity CLI's UNITY_PROJECT_PATH); the current directory is the fallback.
    [string]$ProjectRoot = $(if ($env:UGA_PROJECT_ROOT) { $env:UGA_PROJECT_ROOT } elseif ($env:UNITY_PROJECT_PATH) { $env:UNITY_PROJECT_PATH } else { (Get-Location).Path }),
    [string]$Agent,
    [string[]]$Resource,
    [ValidateSet('cold','focus')][string]$Kind = 'cold',
    [int]$TtlSec = 0,
    [ValidateSet('sync','hot','exclusive')][string]$Lane,
    [ValidateSet('sync','tests','session','exclusive')][string]$JobKind,
    [string[]]$Paths,
    [string]$Tests,
    [ValidateSet('PlayMode','EditMode')][string]$TestMode = 'PlayMode',
    [string]$Scene,
    [double]$Minutes = 0,
    [string]$Reason,
    [string]$Job,
    [string]$Path,
    [switch]$New,
    [switch]$Wait,
    [int]$TimeoutSec = 1800,
    [ValidateSet('embed','git')][string]$Mode = 'embed',
    [string]$GitRef,
    [switch]$Fix,
    [switch]$Force,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$script:BrokerPackageName = 'com.neoxider.uga-editor-broker'
$script:BrokerSchema = 1
$script:BrokerNowOverride = $null
$script:BrokerConfig = [ordered]@{
    defaultTtlSec = 900; maxTtlSec = 3600; focusMaxHoldMs = 180000; waiterTtlMs = 900000
    sessionDefaultMinutes = 5.0; exclusiveDefaultMinutes = 10.0; maxFinishedJobs = 50; maxViolations = 50
}
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding $false

class BrokerCliError : System.Exception {
    [int]$Code
    BrokerCliError([string]$message, [int]$code) : base($message) { $this.Code = $code }
}

function Get-BrokerNowMs {
    if ($null -ne $script:BrokerNowOverride) { return [long]$script:BrokerNowOverride }
    return [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
}

function Stop-Broker([string]$Message, [int]$Code = 2) { throw [BrokerCliError]::new($Message, $Code) }

# ---------------------------------------------------------------- paths and resources
function Test-BrokerAgent([string]$Name) { return [bool]($Name -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,47}$') }

function Get-BrokerNormalizedPath([string]$Raw, [bool]$Folder) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $value = $Raw.Trim().Replace('\', '/')
    while ($value.Contains('//')) { $value = $value.Replace('//', '/') }
    while ($value.StartsWith('./')) { $value = $value.Substring(2) }
    $endsWithSlash = $value.EndsWith('/')
    if ($endsWithSlash -and -not $Folder) { return $null }
    $value = $value.TrimEnd('/')
    if ($value.Length -eq 0 -or $value.StartsWith('/') -or $value.Contains(':')) { return $null }
    $segments = $value.Split('/')
    foreach ($segment in $segments) { if ($segment.Length -eq 0 -or $segment -eq '.' -or $segment -eq '..') { return $null } }
    $root = $segments[0]
    if ($root -ine 'Assets' -and $root -ine 'Packages') { return $null }
    if (-not $Folder -and $segments.Count -lt 2) { return $null }
    $segments[0] = if ($root -ieq 'Assets') { 'Assets' } else { 'Packages' }
    $joined = $segments -join '/'
    if ($Folder) { return $joined + '/' }
    return $joined
}

function Find-BrokerAsmdef([string]$Project, [string]$Name) {
    foreach ($rootName in @('Assets', 'Packages')) {
        $dir = Join-Path $Project $rootName
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $dir -Recurse -Filter '*.asmdef' -File -ErrorAction SilentlyContinue) {
            try {
                $parsed = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
                if ([string]$parsed.name -ceq $Name) { return $file.FullName.Substring($Project.Length).TrimStart('\', '/').Replace('\', '/') }
            } catch { continue }
        }
    }
    return $null
}

# Returns @{ ok; type; path; error }. $Resolver maps an assembly name to its .asmdef path.
function ConvertFrom-BrokerResource([string]$Resource, [scriptblock]$Resolver) {
    $fail = { param($m) return @{ ok = $false; type = ''; path = ''; error = $m } }
    if ([string]::IsNullOrWhiteSpace($Resource)) { return & $fail 'Resource is empty.' }
    $separator = $Resource.IndexOf(':')
    if ($separator -le 0) { return & $fail 'Resource must look like type:path (scene, prefab, asset, folder, asmdef).' }
    $type = $Resource.Substring(0, $separator).Trim().ToLowerInvariant()
    $value = $Resource.Substring($separator + 1).Trim()
    switch ($type) {
        'scene' {
            $p = Get-BrokerNormalizedPath $value $false
            if ($null -eq $p -or -not $p.EndsWith('.unity', [StringComparison]::OrdinalIgnoreCase)) { return & $fail 'A scene resource needs an Assets/ or Packages/ path ending in .unity.' }
            return @{ ok = $true; type = $type; path = $p; error = '' }
        }
        'prefab' {
            $p = Get-BrokerNormalizedPath $value $false
            if ($null -eq $p -or -not $p.EndsWith('.prefab', [StringComparison]::OrdinalIgnoreCase)) { return & $fail 'A prefab resource needs an Assets/ or Packages/ path ending in .prefab.' }
            return @{ ok = $true; type = $type; path = $p; error = '' }
        }
        'asset' {
            $p = Get-BrokerNormalizedPath $value $false
            if ($null -eq $p) { return & $fail 'An asset resource needs an Assets/ or Packages/ file path.' }
            return @{ ok = $true; type = $type; path = $p; error = '' }
        }
        'folder' {
            $p = Get-BrokerNormalizedPath $value $true
            if ($null -eq $p) { return & $fail 'A folder resource needs an Assets/ or Packages/ folder path.' }
            return @{ ok = $true; type = $type; path = $p; error = '' }
        }
        'asmdef' {
            $asmdefPath = if ($value.EndsWith('.asmdef', [StringComparison]::OrdinalIgnoreCase)) { $value } elseif ($Resolver) { & $Resolver $value } else { $null }
            if ([string]::IsNullOrEmpty($asmdefPath)) { return & $fail ('Unknown assembly definition: ' + $value) }
            $normalized = Get-BrokerNormalizedPath $asmdefPath $false
            if ($null -eq $normalized) { return & $fail ('Assembly definition is outside Assets/ or Packages/: ' + $asmdefPath) }
            return @{ ok = $true; type = $type; path = $normalized.Substring(0, $normalized.LastIndexOf('/') + 1); error = '' }
        }
        default { return & $fail ("Unknown resource type '" + $type + "'. Use scene, prefab, asset, folder or asmdef.") }
    }
}

function Test-BrokerOverlap([string]$A, [string]$B) {
    if ([string]::IsNullOrEmpty($A) -or [string]::IsNullOrEmpty($B)) { return $false }
    if ([string]::Equals($A, $B, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($A.EndsWith('/') -and $B.StartsWith($A, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($B.EndsWith('/') -and $A.StartsWith($B, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}

function Test-BrokerCovers([string]$LeasePath, [string]$AssetPath) {
    if ([string]::IsNullOrEmpty($LeasePath) -or [string]::IsNullOrEmpty($AssetPath)) { return $false }
    $asset = $AssetPath.Replace('\', '/')
    if ([string]::Equals($LeasePath, $asset, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($LeasePath.EndsWith('/') -and $asset.StartsWith($LeasePath, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    if ($asset.EndsWith('.meta', [StringComparison]::OrdinalIgnoreCase)) { return Test-BrokerCovers $LeasePath $asset.Substring(0, $asset.Length - 5) }
    return $false
}

# ---------------------------------------------------------------- test selection
function ConvertFrom-BrokerTestSpec([string]$Spec) {
    $filter = @{ names = @(); groups = @(); categories = @(); assemblies = @(); error = '' }
    if ([string]::IsNullOrWhiteSpace($Spec)) { $filter.error = 'Test selection is empty.'; return $filter }
    foreach ($raw in $Spec.Split(';')) {
        $clause = $raw.Trim()
        if ($clause.Length -eq 0) { continue }
        $separator = $clause.IndexOf(':')
        $type = if ($separator -gt 0) { $clause.Substring(0, $separator).Trim().ToLowerInvariant() } else { 'name' }
        $value = if ($separator -gt 0) { $clause.Substring($separator + 1).Trim() } else { $clause }
        if ($value.Length -eq 0) { $filter.error = "Empty value in test clause '$clause'."; return $filter }
        switch ($type) {
            'name' { $filter.names += $value }
            'category' { $filter.categories += $value }
            'assembly' { $filter.assemblies += $value }
            'group' {
                try { [void][regex]::new($value) } catch { $filter.error = "Invalid group regex '$value': " + $_.Exception.InnerException.Message; return $filter }
                $filter.groups += $value
            }
            default { $filter.error = "Unknown test clause type '$type'. Use name, group, category or assembly."; return $filter }
        }
    }
    if (($filter.names.Count + $filter.groups.Count + $filter.categories.Count + $filter.assemblies.Count) -eq 0) { $filter.error = 'Test selection is empty.' }
    return $filter
}

function Test-BrokerTestMatch($Filter, [string]$FullName, [string]$Assembly, [string[]]$Categories) {
    if ($Filter.names.Count -gt 0 -and -not ($Filter.names -ccontains $FullName)) { return $false }
    if ($Filter.groups.Count -gt 0 -and -not ($Filter.groups | Where-Object { [regex]::IsMatch($FullName, $_) })) { return $false }
    if ($Filter.assemblies.Count -gt 0 -and -not ($Filter.assemblies | Where-Object { $_ -ieq $Assembly })) { return $false }
    if ($Filter.categories.Count -gt 0 -and -not ($Filter.categories | Where-Object { @($Categories) -ccontains $_ })) { return $false }
    return $true
}

# ---------------------------------------------------------------- state model
function New-BrokerList($Items) {
    $list = New-Object System.Collections.ArrayList
    if ($null -ne $Items) { foreach ($item in @($Items)) { if ($null -ne $item) { [void]$list.Add($item) } } }
    return ,$list
}

function New-BrokerStringList($Items) {
    $list = New-Object System.Collections.ArrayList
    if ($null -ne $Items) { foreach ($item in @($Items)) { if ($null -ne $item) { [void]$list.Add([string]$item) } } }
    return ,$list
}

function ConvertTo-BrokerLease($s) {
    return [ordered]@{ id = [string]$s.id; agent = [string]$s.agent; kind = [string]$s.kind; resource = [string]$s.resource; path = [string]$s.path
        grantedMs = [long]$s.grantedMs; expiresMs = [long]$s.expiresMs; yielded = [bool]$s.yielded; note = [string]$s.note }
}

function ConvertTo-BrokerWaiter($s) {
    return [ordered]@{ id = [string]$s.id; agent = [string]$s.agent; kind = [string]$s.kind; resource = [string]$s.resource; path = [string]$s.path
        requestedMs = [long]$s.requestedMs; expiresMs = [long]$s.expiresMs; ttlSec = [int]$s.ttlSec }
}

function ConvertTo-BrokerJob($s) {
    $status = if ([string]::IsNullOrEmpty([string]$s.status)) { 'queued' } else { [string]$s.status }
    return [ordered]@{ id = [string]$s.id; agent = [string]$s.agent; lane = [string]$s.lane; kind = [string]$s.kind
        paths = (New-BrokerStringList $s.paths); tests = [string]$s.tests; testMode = [string]$s.testMode; scene = [string]$s.scene
        minutes = [double]$s.minutes; reason = [string]$s.reason; createdMs = [long]$s.createdMs; status = $status
        startedMs = [long]$s.startedMs; finishedMs = [long]$s.finishedMs; windowId = [string]$s.windowId; doneRequested = [bool]$s.doneRequested
        summary = [string]$s.summary; details = (New-BrokerStringList $s.details) }
}

function ConvertTo-BrokerWindow($s) {
    return [ordered]@{ id = [string]$s.id; lane = [string]$s.lane; phase = [string]$s.phase; holder = [string]$s.holder
        requestedMs = [long]$s.requestedMs; drainDeadlineMs = [long]$s.drainDeadlineMs; startedMs = [long]$s.startedMs
        phaseStartedMs = [long]$s.phaseStartedMs; deadlineMs = [long]$s.deadlineMs; jobIds = (New-BrokerStringList $s.jobIds)
        currentJob = [string]$s.currentJob; note = [string]$s.note; appliedFiles = (New-BrokerStringList $s.appliedFiles); sceneSetup = [string]$s.sceneSetup }
}

function ConvertTo-BrokerViolation($s) {
    return [ordered]@{ atMs = [long]$s.atMs; agent = [string]$s.agent; kind = [string]$s.kind; detail = [string]$s.detail }
}

function New-BrokerState($Source) {
    if ($null -eq $Source) { $Source = [pscustomobject]@{} }
    $nextId = [long]$Source.nextId
    if ($nextId -lt 1) { $nextId = 1 }
    $state = [ordered]@{
        schema = $script:BrokerSchema; revision = [long]$Source.revision; updatedMs = [long]$Source.updatedMs; nextId = $nextId
        sessionId = [string]$Source.sessionId; sessionStartedMs = [long]$Source.sessionStartedMs; sessionOwner = [string]$Source.sessionOwner
        paused = [bool]$Source.paused; projectSettingsRequest = [string]$Source.projectSettingsRequest
        leases = New-BrokerList (@($Source.leases) | Where-Object { $null -ne $_ } | ForEach-Object { ConvertTo-BrokerLease $_ })
        waiting = New-BrokerList (@($Source.waiting) | Where-Object { $null -ne $_ } | ForEach-Object { ConvertTo-BrokerWaiter $_ })
        jobs = New-BrokerList (@($Source.jobs) | Where-Object { $null -ne $_ } | ForEach-Object { ConvertTo-BrokerJob $_ })
        window = ConvertTo-BrokerWindow $(if ($null -ne $Source.window) { $Source.window } else { [pscustomobject]@{} })
        violations = New-BrokerList (@($Source.violations) | Where-Object { $null -ne $_ } | ForEach-Object { ConvertTo-BrokerViolation $_ })
    }
    return $state
}

function New-BrokerId($State, [string]$Prefix) {
    $id = $Prefix + $State.nextId
    $State.nextId = [long]$State.nextId + 1
    return $id
}

function Test-BrokerWindow($State) { return -not [string]::IsNullOrEmpty($State.window.id) }
function Test-BrokerSameAgent([string]$A, [string]$B) { return [string]::Equals($A, $B, [StringComparison]::OrdinalIgnoreCase) }

# ---------------------------------------------------------------- lease and job rules (mirror BrokerOps.cs)
function Invoke-BrokerExpire($State, [long]$Now) {
    $before = $State.leases.Count + $State.waiting.Count
    $State.leases = New-BrokerList ($State.leases | Where-Object { $_.expiresMs -gt $Now })
    $State.waiting = New-BrokerList ($State.waiting | Where-Object { $_.expiresMs -gt $Now })
    return $before - ($State.leases.Count + $State.waiting.Count)
}

function Test-BrokerConflict([string]$AgentA, [string]$KindA, [string]$PathA, [string]$AgentB, [string]$KindB, [string]$PathB) {
    if (Test-BrokerSameAgent $AgentA $AgentB) { return $false }
    if ($KindA -eq 'focus' -and $KindB -eq 'focus') { return $true }
    return (Test-BrokerOverlap $PathA $PathB)
}

function Get-BrokerFocusExpiry($State, [string]$Agent, [long]$GrantedMs, [long]$TtlMs, [long]$Now) {
    $cfg = $script:BrokerConfig
    $othersWaiting = @($State.waiting | Where-Object { $_.kind -eq 'focus' -and -not (Test-BrokerSameAgent $_.agent $Agent) }).Count -gt 0
    if ($othersWaiting) { return [Math]::Min($Now + $TtlMs, $GrantedMs + $cfg.focusMaxHoldMs) }
    return $Now + [Math]::Min($TtlMs, [long]$cfg.focusMaxHoldMs)
}

function Get-BrokerTtlSec([int]$TtlSec) {
    $cfg = $script:BrokerConfig
    if ($TtlSec -le 0) { $TtlSec = $cfg.defaultTtlSec }
    return [Math]::Max(10, [Math]::Min($cfg.maxTtlSec, $TtlSec))
}

function Test-BrokerHoldsCover($State, [string]$Agent, [string]$AssetPath, [long]$Now) {
    return @($State.leases | Where-Object { $_.expiresMs -gt $Now -and $_.kind -eq 'cold' -and (Test-BrokerSameAgent $_.agent $Agent) -and (Test-BrokerCovers $_.path $AssetPath) }).Count -gt 0
}

function New-BrokerResult([string]$Status, [string]$Message) {
    return [ordered]@{ status = $Status; message = $Message; leaseId = ''; jobId = ''; position = 0 }
}

function Add-BrokerLease($State, [string]$Agent, [string]$Kind, [string]$ResourceText, [string]$LeasePath, [long]$TtlMs, [long]$Now) {
    $lease = [ordered]@{ id = (New-BrokerId $State 'L'); agent = $Agent; kind = $Kind; resource = $ResourceText; path = $LeasePath
        grantedMs = $Now; expiresMs = 0; yielded = $false; note = '' }
    $lease.expiresMs = if ($Kind -eq 'focus') { Get-BrokerFocusExpiry $State $Agent $Now $TtlMs $Now } else { $Now + $TtlMs }
    [void]$State.leases.Add($lease)
    return $lease
}

function Invoke-BrokerTake($State, [string]$Agent, [string]$LeaseKind, [string]$ResourceText, [string]$LeasePath, [int]$Ttl, [long]$Now) {
    if (-not (Test-BrokerAgent $Agent)) { return New-BrokerResult 'error' 'Invalid agent name.' }
    if ($LeaseKind -ne 'cold' -and $LeaseKind -ne 'focus') { return New-BrokerResult 'error' 'Kind must be cold or focus.' }
    if ([string]::IsNullOrEmpty($LeasePath)) { return New-BrokerResult 'error' 'Resource path is empty.' }
    [void](Invoke-BrokerExpire $State $Now)
    $ttlMs = [long](Get-BrokerTtlSec $Ttl) * 1000
    if ($LeaseKind -eq 'focus') {
        if (-not $LeasePath.EndsWith('.unity', [StringComparison]::OrdinalIgnoreCase)) { return New-BrokerResult 'error' 'Focus is granted for a scene resource only.' }
        if (-not (Test-BrokerHoldsCover $State $Agent $LeasePath $Now)) { return New-BrokerResult 'error' 'Take a cold lease on the scene before asking for focus.' }
    }
    $own = @($State.leases | Where-Object { (Test-BrokerSameAgent $_.agent $Agent) -and $_.kind -eq $LeaseKind -and [string]::Equals($_.path, $LeasePath, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
    if ($null -ne $own) {
        $own.expiresMs = if ($LeaseKind -eq 'focus') { Get-BrokerFocusExpiry $State $Agent $own.grantedMs $ttlMs $Now } else { $Now + $ttlMs }
        $r = New-BrokerResult 'renewed' 'Lease renewed.'; $r.leaseId = $own.id; return $r
    }
    $ownWaiterIndex = -1
    for ($i = 0; $i -lt $State.waiting.Count; $i++) {
        $w = $State.waiting[$i]
        if ((Test-BrokerSameAgent $w.agent $Agent) -and $w.kind -eq $LeaseKind -and [string]::Equals($w.path, $LeasePath, [StringComparison]::OrdinalIgnoreCase)) { $ownWaiterIndex = $i; break }
    }
    $earlier = if ($ownWaiterIndex -lt 0) { $State.waiting.Count } else { $ownWaiterIndex }
    $blockers = New-Object System.Collections.ArrayList
    foreach ($l in $State.leases) {
        if ($l.expiresMs -gt $Now -and (Test-BrokerConflict $Agent $LeaseKind $LeasePath $l.agent $l.kind $l.path) -and -not $blockers.Contains($l.agent)) { [void]$blockers.Add($l.agent) }
    }
    for ($i = 0; $i -lt $earlier; $i++) {
        $w = $State.waiting[$i]
        $label = $w.agent + ' (queued)'
        if ((Test-BrokerConflict $Agent $LeaseKind $LeasePath $w.agent $w.kind $w.path) -and -not $blockers.Contains($label)) { [void]$blockers.Add($label) }
    }
    if ($blockers.Count -eq 0) {
        if ($ownWaiterIndex -ge 0) { $State.waiting.RemoveAt($ownWaiterIndex) }
        $lease = Add-BrokerLease $State $Agent $LeaseKind $ResourceText $LeasePath $ttlMs $Now
        $r = New-BrokerResult 'granted' 'Lease granted.'; $r.leaseId = $lease.id; return $r
    }
    $message = 'Waiting behind ' + ($blockers -join ', ') + '.'
    if ($ownWaiterIndex -ge 0) {
        $existing = $State.waiting[$ownWaiterIndex]
        $existing.expiresMs = $Now + $script:BrokerConfig.waiterTtlMs
        $existing.ttlSec = [int]($ttlMs / 1000)
        $r = New-BrokerResult 'queued' $message; $r.leaseId = $existing.id; $r.position = $ownWaiterIndex + 1; return $r
    }
    $waiter = [ordered]@{ id = (New-BrokerId $State 'Q'); agent = $Agent; kind = $LeaseKind; resource = $ResourceText; path = $LeasePath
        requestedMs = $Now; expiresMs = $Now + $script:BrokerConfig.waiterTtlMs; ttlSec = [int]($ttlMs / 1000) }
    [void]$State.waiting.Add($waiter)
    $r = New-BrokerResult 'queued' $message; $r.leaseId = $waiter.id; $r.position = $State.waiting.Count; return $r
}

function Invoke-BrokerPromote($State, [long]$Now) {
    [void](Invoke-BrokerExpire $State $Now)
    $granted = New-Object System.Collections.ArrayList
    $i = 0
    while ($i -lt $State.waiting.Count) {
        $w = $State.waiting[$i]
        if ($w.kind -eq 'focus' -and -not (Test-BrokerHoldsCover $State $w.agent $w.path $Now)) { $State.waiting.RemoveAt($i); continue }
        $blocked = $false
        foreach ($l in $State.leases) { if ($l.expiresMs -gt $Now -and (Test-BrokerConflict $w.agent $w.kind $w.path $l.agent $l.kind $l.path)) { $blocked = $true; break } }
        if (-not $blocked) {
            for ($j = 0; $j -lt $i; $j++) { $e = $State.waiting[$j]; if (Test-BrokerConflict $w.agent $w.kind $w.path $e.agent $e.kind $e.path) { $blocked = $true; break } }
        }
        if ($blocked) { $i++; continue }
        $State.waiting.RemoveAt($i)
        [void]$granted.Add((Add-BrokerLease $State $w.agent $w.kind $w.resource $w.path ([long][Math]::Max(10, $w.ttlSec) * 1000) $Now))
    }
    return ,$granted
}

function Invoke-BrokerRelease($State, [string]$Agent, [string]$LeasePath) {
    $match = { param($a, $p) (Test-BrokerSameAgent $a $Agent) -and ([string]::IsNullOrEmpty($LeasePath) -or [string]::Equals($p, $LeasePath, [StringComparison]::OrdinalIgnoreCase)) }
    $before = $State.leases.Count + $State.waiting.Count
    $State.leases = New-BrokerList ($State.leases | Where-Object { -not (& $match $_.agent $_.path) })
    $State.waiting = New-BrokerList ($State.waiting | Where-Object { -not (& $match $_.agent $_.path) })
    return $before - ($State.leases.Count + $State.waiting.Count)
}

function Invoke-BrokerRenew($State, [string]$Agent, [int]$Ttl, [long]$Now) {
    [void](Invoke-BrokerExpire $State $Now)
    $ttlMs = [long](Get-BrokerTtlSec $Ttl) * 1000
    $count = 0
    foreach ($l in $State.leases) {
        if (-not (Test-BrokerSameAgent $l.agent $Agent)) { continue }
        $l.expiresMs = if ($l.kind -eq 'focus') { Get-BrokerFocusExpiry $State $Agent $l.grantedMs $ttlMs $Now } else { $Now + $ttlMs }
        $count++
    }
    foreach ($w in $State.waiting) { if (Test-BrokerSameAgent $w.agent $Agent) { $w.expiresMs = $Now + $script:BrokerConfig.waiterTtlMs; $count++ } }
    return $count
}

function Invoke-BrokerYield($State, [string]$Agent, [long]$Now) {
    $count = 0
    foreach ($l in $State.leases) { if ($l.expiresMs -gt $Now -and (Test-BrokerSameAgent $l.agent $Agent)) { $l.yielded = $true; $count++ } }
    return $count
}

function Invoke-BrokerGate($State, [string]$Agent, [long]$Now) {
    [void](Invoke-BrokerExpire $State $Now)
    $mine = @($State.leases | Where-Object { Test-BrokerSameAgent $_.agent $Agent })
    if ((Test-BrokerWindow $State) -and -not (Test-BrokerSameAgent $State.window.holder $Agent)) {
        foreach ($l in $mine) { $l.yielded = $true }
        return New-BrokerResult 'wait' ('Window ' + $State.window.id + ' (' + $State.window.lane + ', ' + $State.window.phase + ') owns the Editor. Retry after it ends.')
    }
    foreach ($l in $mine) { $l.yielded = $false }
    return New-BrokerResult 'go' 'The Editor is free for your leased resources.'
}

function Invoke-BrokerRequest($State, [string]$Agent, [string]$RequestLane, [string]$RequestKind, [string[]]$RequestPaths, [string]$RequestTests,
                              [string]$RequestMode, [string]$RequestScene, [double]$RequestMinutes, [string]$RequestReason, [long]$Now) {
    if (-not (Test-BrokerAgent $Agent)) { return New-BrokerResult 'error' 'Invalid agent name.' }
    [void](Invoke-BrokerExpire $State $Now)
    $cfg = $script:BrokerConfig
    $job = ConvertTo-BrokerJob ([pscustomobject]@{ agent = $Agent; lane = $RequestLane; kind = $RequestKind; createdMs = $Now })
    switch ($RequestLane + '/' + $RequestKind) {
        'sync/sync' {
            foreach ($raw in @($RequestPaths)) {
                if ([string]::IsNullOrWhiteSpace($raw)) { continue }
                $p = Get-BrokerNormalizedPath $raw $false
                if ($null -eq $p) { return New-BrokerResult 'error' ('Invalid import path: ' + $raw) }
                if (-not (Test-BrokerHoldsCover $State $Agent $p $Now)) { return New-BrokerResult 'error' ('Import path is not under your lease: ' + $p) }
                [void]$job.paths.Add($p)
            }
        }
        'hot/tests' {
            if ([string]::IsNullOrWhiteSpace($RequestTests)) { return New-BrokerResult 'error' 'A test request needs -Tests.' }
            $filter = ConvertFrom-BrokerTestSpec $RequestTests
            if ($filter.error) { return New-BrokerResult 'error' $filter.error }
            $job.tests = $RequestTests.Trim()
            $job.testMode = if ([string]::IsNullOrEmpty($RequestMode)) { 'PlayMode' } else { $RequestMode }
            if ($job.testMode -cne 'PlayMode' -and $job.testMode -cne 'EditMode') { return New-BrokerResult 'error' 'Test mode must be PlayMode or EditMode.' }
        }
        { $_ -eq 'hot/session' -or $_ -eq 'hot/smoke' } {
            $value = if ($RequestMinutes -gt 0) { $RequestMinutes } elseif ($RequestKind -eq 'smoke') { 0.05 } else { $cfg.sessionDefaultMinutes }
            $job.minutes = [Math]::Max(0.05, [Math]::Min(30.0, $value))
            if (-not [string]::IsNullOrWhiteSpace($RequestScene)) {
                $s = Get-BrokerNormalizedPath $RequestScene $false
                if ($null -eq $s -or -not $s.EndsWith('.unity', [StringComparison]::OrdinalIgnoreCase)) { return New-BrokerResult 'error' 'Session scene must be an Assets/ or Packages/ .unity path.' }
                $job.scene = $s
            }
            $job.reason = [string]$RequestReason
        }
        'exclusive/exclusive' {
            if ([string]::IsNullOrWhiteSpace($RequestReason)) { return New-BrokerResult 'error' 'An exclusive request needs -Reason.' }
            $job.reason = $RequestReason.Trim()
            $value = if ($RequestMinutes -gt 0) { $RequestMinutes } else { $cfg.exclusiveDefaultMinutes }
            $job.minutes = [Math]::Max(1.0, [Math]::Min(60.0, $value))
        }
        default { return New-BrokerResult 'error' ('Unknown lane/kind: ' + $RequestLane + '/' + $RequestKind) }
    }
    foreach ($existing in $State.jobs) {
        if ($existing.status -ne 'queued' -or -not (Test-BrokerSameAgent $existing.agent $Agent)) { continue }
        if ($existing.lane -ne $job.lane -or $existing.kind -ne $job.kind -or $existing.tests -cne $job.tests -or $existing.scene -cne $job.scene -or $existing.testMode -cne $job.testMode) { continue }
        if ((@($existing.paths) -join '|').ToLowerInvariant() -ne (@($job.paths) -join '|').ToLowerInvariant()) { continue }
        $r = New-BrokerResult 'exists' 'Same request is already queued.'; $r.jobId = $existing.id; return $r
    }
    $job.id = New-BrokerId $State 'J'
    [void]$State.jobs.Add($job)
    $r = New-BrokerResult 'queued' 'Request queued.'; $r.jobId = $job.id; return $r
}

function Complete-BrokerJob($JobItem, [string]$Status, [string]$Summary, [long]$Now) {
    $JobItem.status = $Status; $JobItem.summary = $Summary; $JobItem.finishedMs = $Now
}

function Invoke-BrokerCancel($State, [string]$Agent, [string]$JobId, [long]$Now) {
    $item = @($State.jobs | Where-Object { $_.id -eq $JobId }) | Select-Object -First 1
    if ($null -eq $item) { return New-BrokerResult 'error' "Unknown job $JobId." }
    if (-not (Test-BrokerSameAgent $item.agent $Agent)) { return New-BrokerResult 'error' "Job $JobId belongs to $($item.agent)." }
    if ($item.status -ne 'queued') { return New-BrokerResult 'error' 'Only a queued job can be canceled.' }
    Complete-BrokerJob $item 'canceled' "Canceled by $Agent." $Now
    $r = New-BrokerResult 'canceled' 'Job canceled.'; $r.jobId = $JobId; return $r
}

function Invoke-BrokerDone($State, [string]$Agent, [string]$JobId) {
    $item = @($State.jobs | Where-Object { $_.id -eq $JobId }) | Select-Object -First 1
    if ($null -eq $item) { return New-BrokerResult 'error' "Unknown job $JobId." }
    if (-not (Test-BrokerSameAgent $item.agent $Agent)) { return New-BrokerResult 'error' "Job $JobId belongs to $($item.agent)." }
    if ($item.kind -ne 'session' -and $item.kind -ne 'exclusive') { return New-BrokerResult 'error' 'Only a Play Mode session or an exclusive window can be finished early.' }
    if ($item.status -in @('passed','failed','blocked','canceled')) { return New-BrokerResult 'error' "Job $JobId already finished." }
    $item.doneRequested = $true
    $r = New-BrokerResult 'done-requested' 'The broker will close it on its next tick.'; $r.jobId = $JobId; return $r
}

function Add-BrokerViolation($State, [string]$Agent, [string]$ViolationKind, [string]$Detail, [long]$Now) {
    [void]$State.violations.Add([ordered]@{ atMs = $Now; agent = $Agent; kind = $ViolationKind; detail = $Detail })
    while ($State.violations.Count -gt $script:BrokerConfig.maxViolations) { $State.violations.RemoveAt(0) }
}

# ---------------------------------------------------------------- storage
function Get-BrokerProject([string]$Start) {
    # Resolve against the PowerShell location; .NET would use the process working directory.
    $dir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Start)
    while ($dir) {
        if ((Test-Path -LiteralPath (Join-Path $dir 'Assets')) -and (Test-Path -LiteralPath (Join-Path $dir 'ProjectSettings'))) { return $dir.TrimEnd('\', '/') }
        $parent = [IO.Path]::GetDirectoryName($dir)
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    Stop-Broker "No Unity project (Assets/ and ProjectSettings/) at or above $Start. Pass -ProjectRoot." 2
}

function Get-BrokerDir([string]$Project) { return Join-Path (Join-Path $Project 'Library') 'UgaBroker' }

# Holders keep the lock for a read-modify-write only, but waiters are not served in order: on a
# loaded machine (several agents plus a compiling Editor) one caller can lose many rounds in a row.
function Enter-BrokerLock([string]$Dir, [int]$TimeoutMs = 30000) {
    if (-not (Test-Path -LiteralPath $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $file = Join-Path $Dir 'state.lock'
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $stream = $null
        try {
            $stream = [IO.FileStream]::new($file, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            $stream.Lock(0, 1)
            return $stream
        } catch {
            # .NET errors arrive wrapped in MethodInvocationException; only lock contention is retried.
            $reason = $_.Exception
            while ($reason.InnerException) { $reason = $reason.InnerException }
            if ($stream) { $stream.Dispose() }
            if ($reason -isnot [System.IO.IOException]) { throw }
            if ($timer.ElapsedMilliseconds -ge $TimeoutMs) { Stop-Broker 'Broker state stayed locked; retry. Never delete state.lock while an Editor runs.' 6 }
            Start-Sleep -Milliseconds 15
        }
    }
}

function Exit-BrokerLock($Stream) {
    if ($Stream) { try { $Stream.Unlock(0, 1) } catch { } finally { $Stream.Dispose() } }
}

function Read-BrokerJsonFile([string]$File) {
    try {
        $text = [IO.File]::ReadAllText($File, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        return $text | ConvertFrom-Json
    } catch { return $null }
}

function Write-BrokerTextAtomic([string]$File, [string]$Text, [string]$Backup) {
    $temp = $File + '.tmp'
    [IO.File]::WriteAllText($temp, $Text, $script:Utf8NoBom)
    if (Test-Path -LiteralPath $File) { [IO.File]::Replace($temp, $File, $Backup) } else { [IO.File]::Move($temp, $File) }
}

# Runs the scriptblock with (state, ctx) under the lock; the state is written only when it sets
# ctx.save. Locals carry a __bu prefix: PowerShell scriptblocks see the caller's variables
# dynamically, so common names here would shadow the caller's variables inside the scriptblock.
function Invoke-BrokerUpdate([string]$__buProject, [scriptblock]$__buMutate) {
    $__buDir = Get-BrokerDir $__buProject
    $__buLock = Enter-BrokerLock $__buDir
    try {
        $__buFile = Join-Path $__buDir 'state.json'
        $__buBackup = Join-Path $__buDir 'state.json.bak'
        $__buRecovered = ''
        $__buParsed = $null
        if (Test-Path -LiteralPath $__buFile) {
            $__buParsed = Read-BrokerJsonFile $__buFile
            if ($null -eq $__buParsed) {
                $__buParsed = if (Test-Path -LiteralPath $__buBackup) { Read-BrokerJsonFile $__buBackup } else { $null }
                $__buRecovered = if ($null -ne $__buParsed) { 'state.json.bak' } else { 'an empty state' }
            }
        }
        $__buState = New-BrokerState $__buParsed
        $__buCtx = @{ save = $false }
        & $__buMutate $__buState $__buCtx | Out-Null
        if ($__buRecovered) {
            Add-BrokerViolation $__buState '' 'state-recovered' "state.json was unreadable; recovered from $__buRecovered." (Get-BrokerNowMs)
            $__buCtx.save = $true
        }
        if ($__buCtx.save) {
            $__buState.revision = [long]$__buState.revision + 1
            $__buState.updatedMs = Get-BrokerNowMs
            Write-BrokerTextAtomic $__buFile ($__buState | ConvertTo-Json -Depth 20) $__buBackup
        }
        return $__buState
    } finally { Exit-BrokerLock $__buLock }
}

function Read-BrokerEditor([string]$Project) {
    $file = Join-Path (Get-BrokerDir $Project) 'editor.json'
    for ($i = 0; $i -lt 5; $i++) {
        if (-not (Test-Path -LiteralPath $file)) { return $null }
        $parsed = Read-BrokerJsonFile $file
        if ($null -ne $parsed) { return $parsed }
        Start-Sleep -Milliseconds 50
    }
    return $null
}

function Get-BrokerMachineDir {
    if ($env:UGA_MACHINE_DIR) { return $env:UGA_MACHINE_DIR }
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { return Join-Path $env:LOCALAPPDATA 'UnityGameAgent' }
    return Join-Path $HOME '.unity-game-agent'
}

# Every Editor that hosts a broker keeps one entry here (see BrokerMachine.cs).
function Get-BrokerMachineEntries {
    $dir = Join-Path (Get-BrokerMachineDir) 'brokers'
    $entries = New-Object System.Collections.ArrayList
    if (-not (Test-Path -LiteralPath $dir)) { return ,$entries }
    $now = Get-BrokerNowMs
    foreach ($file in Get-ChildItem -LiteralPath $dir -Filter '*.json' -File) {
        $entry = Read-BrokerJsonFile $file.FullName
        if ($null -eq $entry) { continue }
        $alive = ($now - [long]$entry.heartbeatMs) -lt 15000 -and $null -ne (Get-Process -Id ([int]$entry.pid) -ErrorAction SilentlyContinue)
        [void]$entries.Add([ordered]@{ projectPath = [string]$entry.projectPath; pid = [int]$entry.pid; alive = $alive
            unityVersion = [string]$entry.unityVersion; heartbeatAgeMs = $now - [long]$entry.heartbeatMs; phase = [string]$entry.phase
            sessionId = [string]$entry.sessionId; leases = [int]$entry.leases; queuedJobs = [int]$entry.queuedJobs; window = [string]$entry.window })
    }
    return ,$entries
}

function Get-BrokerEditorAgeMs($Editor) {
    if ($null -eq $Editor) { return [long]::MaxValue }
    return (Get-BrokerNowMs) - [long]$Editor.heartbeatMs
}

# ---------------------------------------------------------------- presentation
function Format-BrokerAge([long]$Ms) {
    if ($Ms -lt 0) { $Ms = 0 }
    if ($Ms -lt 1000) { return "$Ms ms" }
    if ($Ms -lt 120000) { return ([long]($Ms / 1000)).ToString() + ' s' }
    return ([long]($Ms / 60000)).ToString() + ' min'
}

function Format-BrokerBoard($State, $Editor) {
    $now = Get-BrokerNowMs
    $lines = New-Object System.Collections.ArrayList
    $session = if ($State.sessionId) { "$($State.sessionId) (owner $($State.sessionOwner))" } else { 'none' }
    [void]$lines.Add('Session: ' + $session + $(if ($State.paused) { '  [PAUSED]' } else { '' }))
    if ($null -eq $Editor) { [void]$lines.Add('Editor: no heartbeat (open the project in Unity with the broker package installed)') }
    else {
        $extra = ''
        if ($Editor.compileFailed) { $extra += ', COMPILE ERRORS' }
        if (@($Editor.dirtyScenes).Count -gt 0) { $extra += ', dirty: ' + (@($Editor.dirtyScenes) -join ', ') }
        [void]$lines.Add("Editor: $($Editor.phase), heartbeat " + (Format-BrokerAge (Get-BrokerEditorAgeMs $Editor)) + ' ago' + $extra)
    }
    if (Test-BrokerWindow $State) {
        $w = $State.window
        $line = "Window: $($w.id) $($w.lane)/$($w.phase)"
        if ($w.holder) { $line += " holder $($w.holder)" }
        $line += ' jobs ' + (@($w.jobIds) -join ',')
        if ($w.phase -eq 'draining') {
            $pending = @($State.leases | Where-Object { $_.expiresMs -gt $now -and -not $_.yielded -and -not (Test-BrokerSameAgent $_.agent $w.holder) } | ForEach-Object { $_.agent } | Select-Object -Unique)
            $line += ' waiting for: ' + ($pending -join ', ') + ' (deadline in ' + (Format-BrokerAge ($w.drainDeadlineMs - $now)) + ')'
        }
        [void]$lines.Add($line)
    } else { [void]$lines.Add('Window: none') }
    [void]$lines.Add('Leases:')
    if ($State.leases.Count -eq 0) { [void]$lines.Add('  (none)') }
    foreach ($l in @($State.leases | Sort-Object grantedMs)) {
        [void]$lines.Add("  $($l.id) $($l.agent) $($l.kind) $($l.path) expires in " + (Format-BrokerAge ($l.expiresMs - $now)) + $(if ($l.yielded) { ' yielded' } else { '' }))
    }
    if ($State.waiting.Count -gt 0) {
        [void]$lines.Add('Waiting (FIFO):')
        foreach ($w in $State.waiting) { [void]$lines.Add("  $($w.id) $($w.agent) $($w.kind) $($w.path)") }
    }
    [void]$lines.Add('Jobs:')
    $open = @($State.jobs | Where-Object { $_.status -notin @('passed','failed','blocked','canceled') } | Sort-Object createdMs)
    if ($open.Count -eq 0) { [void]$lines.Add('  (none queued)') }
    foreach ($j in $open) {
        $label = if ($j.kind -eq 'tests') { " $($j.testMode) $($j.tests)" } elseif ($j.kind -eq 'session') { " $($j.minutes) min $($j.scene)" } elseif ($j.kind -eq 'exclusive') { " $($j.reason)" } else { '' }
        [void]$lines.Add("  $($j.id) $($j.agent) $($j.lane)/$($j.kind) $($j.status) age " + (Format-BrokerAge ($now - $j.createdMs)) + $label)
    }
    foreach ($j in @($State.jobs | Where-Object { $_.status -in @('passed','failed','blocked','canceled') } | Sort-Object finishedMs -Descending | Select-Object -First 5)) {
        [void]$lines.Add("  $($j.id) $($j.agent) $($j.lane)/$($j.kind) $($j.status): $($j.summary)")
    }
    if ($State.violations.Count -gt 0) {
        [void]$lines.Add('Violations (latest):')
        foreach ($v in @($State.violations | Select-Object -Last 5)) { [void]$lines.Add("  $($v.kind)" + $(if ($v.agent) { " [$($v.agent)]" } else { '' }) + ": $($v.detail)") }
    }
    return ($lines -join [Environment]::NewLine)
}

function Write-BrokerResult($Result, [string]$Extra = '') {
    if ($Json) { Write-Output ($Result | ConvertTo-Json -Depth 10 -Compress); return }
    $parts = @($Result.status)
    if ($Result.leaseId) { $parts += $Result.leaseId }
    if ($Result.jobId) { $parts += $Result.jobId }
    if ($Result.position) { $parts += "position $($Result.position)" }
    Write-Output (($parts -join ' ') + ': ' + $Result.message)
    if ($Extra) { Write-Output $Extra }
}

# ---------------------------------------------------------------- commands
function Get-BrokerSkillPackage {
    $source = Join-Path (Split-Path -Parent $PSScriptRoot) 'unity-package'
    if (-not (Test-Path -LiteralPath (Join-Path $source 'package.json'))) { Stop-Broker "Broker package source not found at $source." 2 }
    return $source
}

function Get-BrokerInstalledVersion([string]$Project) {
    $embedded = Join-Path (Join-Path $Project 'Packages') $script:BrokerPackageName
    $manifest = Read-BrokerJsonFile (Join-Path $embedded 'package.json')
    if ($null -ne $manifest) { return @{ mode = 'embed'; version = [string]$manifest.version } }
    $projectManifest = Read-BrokerJsonFile (Join-Path (Join-Path $Project 'Packages') 'manifest.json')
    if ($null -ne $projectManifest -and $projectManifest.dependencies.PSObject.Properties.Name -contains $script:BrokerPackageName) {
        return @{ mode = 'manifest'; version = [string]$projectManifest.dependencies.($script:BrokerPackageName) }
    }
    return $null
}

function Invoke-BrokerInstall([string]$Project, [bool]$Overwrite = $Force) {
    $source = Get-BrokerSkillPackage
    $sourceVersion = [string](Read-BrokerJsonFile (Join-Path $source 'package.json')).version
    $packagesDir = Join-Path $Project 'Packages'
    if ($Mode -eq 'embed') {
        $target = Join-Path $packagesDir $script:BrokerPackageName
        $existing = Read-BrokerJsonFile (Join-Path $target 'package.json')
        if ($null -ne $existing) {
            if ([string]$existing.name -ne $script:BrokerPackageName) { Stop-Broker "$target is not the broker package; refusing to replace it." 2 }
            if ([string]$existing.version -eq $sourceVersion -and -not $Overwrite) { Write-Output "Broker package $sourceVersion is already embedded."; return }
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        Copy-Item -LiteralPath $source -Destination $target -Recurse
        Write-Output "Embedded $script:BrokerPackageName $sourceVersion in Packages/. Unity imports it on the next refresh or focus."
        return
    }
    # The repository has no release tags yet, so the default follows main; -GitRef pins a tag or commit.
    $ref = if ($GitRef) { $GitRef } else { 'main' }
    $manifestPath = Join-Path $packagesDir 'manifest.json'
    $manifest = Read-BrokerJsonFile $manifestPath
    if ($null -eq $manifest) { Stop-Broker "Cannot read $manifestPath." 2 }
    $url = "https://github.com/NeoXider/unity-game-agent.git?path=/unity-package#$ref"
    $manifest.dependencies | Add-Member -NotePropertyName $script:BrokerPackageName -NotePropertyValue $url -Force
    # Unity rejects a manifest that starts with a byte order mark.
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 20), $script:Utf8NoBom)
    Write-Output "Added $script:BrokerPackageName -> $url to Packages/manifest.json (pass -GitRef <tag|commit> to pin a version)."
}

function Invoke-BrokerDoctor([string]$Project) {
    $report = New-Object System.Collections.ArrayList
    $ready = $true
    $add = { param($level, $text) [void]$report.Add("$level $text") }
    $versionFile = Join-Path $Project 'ProjectSettings/ProjectVersion.txt'
    $unityVersion = ''
    if (Test-Path -LiteralPath $versionFile) {
        $line = Get-Content -LiteralPath $versionFile | Where-Object { $_ -match '^m_EditorVersion:' } | Select-Object -First 1
        $unityVersion = ($line -replace '^m_EditorVersion:\s*', '').Trim()
    }
    $major = 0
    [void][int]::TryParse(($unityVersion -split '\.')[0], [ref]$major)
    if ($major -ge 6000) { & $add 'OK  ' "Unity $unityVersion (Unity 6 or newer is required)." }
    else { & $add 'FIX ' "Unity '$unityVersion': the shared-editor broker requires Unity 6 (6000.0) or newer."; $ready = $false }

    $source = Get-BrokerSkillPackage
    $expected = [string](Read-BrokerJsonFile (Join-Path $source 'package.json')).version
    $installed = Get-BrokerInstalledVersion $Project
    if ($null -eq $installed) {
        if ($Fix) { Invoke-BrokerInstall $Project | ForEach-Object { & $add 'DONE' $_ }; $installed = Get-BrokerInstalledVersion $Project }
        else { & $add 'FIX ' 'Broker package is not installed: run editor-broker.ps1 install (or doctor -Fix).'; $ready = $false }
    }
    if ($null -ne $installed) {
        if ($installed.mode -eq 'embed' -and $installed.version -ne $expected) {
            if ($Fix) { Invoke-BrokerInstall $Project $true | ForEach-Object { & $add 'DONE' $_ } }
            else { & $add 'FIX ' "Embedded broker package is $($installed.version); this CLI expects $expected. Run install -Force."; $ready = $false }
        } else { & $add 'OK  ' "Broker package installed ($($installed.mode) $($installed.version))." }
    }

    $editor = Read-BrokerEditor $Project
    $age = Get-BrokerEditorAgeMs $editor
    if ($null -eq $editor -or $age -gt 15000) {
        & $add 'FIX ' 'No live Editor heartbeat: open the project in Unity 6 and wait for the import to finish.'
        $ready = $false
    } else {
        & $add 'OK  ' "Editor live (pid $($editor.pid), $($editor.phase), heartbeat $(Format-BrokerAge $age) ago)."
        if ([string]$editor.packageVersion -ne $expected) { & $add 'FIX ' "Editor runs broker $($editor.packageVersion); expected $expected (wait for the import)."; $ready = $false }
        $state = Invoke-BrokerUpdate $Project { param($s, $ctx) }
        $projectFix = $false
        foreach ($setting in @($editor.settings)) {
            if ($setting.ok) { continue }
            if ($setting.scope -eq 'project') { $projectFix = $true; & $add 'FIX ' "$($setting.name): $($setting.current) -> $($setting.desired). $($setting.note)" }
            elseif ($setting.scope -eq 'session') { & $add 'INFO' "$($setting.name) is $($setting.current); 'session start' sets $($setting.desired)." }
            else { & $add 'WARN' "$($setting.name): $($setting.current) (wanted $($setting.desired)). $($setting.note)" }
        }
        if ($projectFix) {
            if ($Fix) {
                $requestId = 'P' + (Get-BrokerNowMs)
                [void](Invoke-BrokerUpdate $Project { param($s, $ctx) $s.projectSettingsRequest = $requestId; $ctx.save = $true })
                & $add 'DONE' "Requested project settings ($requestId); the Editor applies them and runs one smoke Play Mode check."
            } else { $ready = $false }
        }
        foreach ($adapter in @($editor.adapters)) {
            $level = if ($adapter.ok) { 'OK  ' } else { 'FIX ' }
            if (-not $adapter.ok) { $ready = $false }
            & $add $level "$($adapter.name): $($adapter.note)"
        }
        if ($state.sessionId) { & $add 'INFO' "Agent session $($state.sessionId) is active (owner $($state.sessionOwner))." }
    }
    $self = $Project.Replace('\', '/').TrimEnd('/')
    # The function returns its list as one object; enumerate it from a variable, not straight into a pipe.
    $registered = Get-BrokerMachineEntries
    $others = @($registered | Where-Object { $_.alive -and -not [string]::Equals($_.projectPath.Replace('\', '/').TrimEnd('/'), $self, [StringComparison]::OrdinalIgnoreCase) })
    if ($others.Count -gt 0) {
        & $add 'INFO' ("$($others.Count) other live broker(s) on this machine: " + (($others | ForEach-Object { $_.projectPath }) -join '; ') +
            '. Each project keeps its own leases and queues; pass -ProjectRoot (or UGA_PROJECT_ROOT) and pin MCP per project.')
    }
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $freeGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $commitGB = [Math]::Round($os.FreeVirtualMemory / 1MB, 1)
            if ($commitGB -lt 4) { & $add 'WARN' "Only $commitGB GB of commit memory (RAM + page file) is left; another Editor may fail at startup with 'Array buffer allocation failed'. Close idle Editors or browser windows first." }
            elseif ($freeGB -lt 6) { & $add 'WARN' "Only $freeGB GB of physical memory is free; another Editor or a Play Mode run may swap. Close idle Editors first." }
            else { & $add 'INFO' "$freeGB GB of physical memory and $commitGB GB of commit memory free." }
        }
    }
    $cli = Get-Command unity -ErrorAction SilentlyContinue
    if ($cli) { & $add 'INFO' "Unity CLI found: $($cli.Source)." } else { & $add 'INFO' 'Unity CLI not found (optional; MCP for Unity works without it).' }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        # Windows PowerShell turns native stderr into terminating errors under 'Stop'.
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $branch = & git -C $Project rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0) {
                $dirty = @(& git -C $Project status --porcelain 2>$null).Count
                & $add 'INFO' "git branch $branch, $dirty changed path(s). One folder and one branch for the whole session."
            } else { & $add 'INFO' 'Not a git repository.' }
        } finally { $ErrorActionPreference = $previous }
    }
    foreach ($line in $report) { Write-Output $line }
    if ($ready) { Write-Output 'READY: the project can host a shared-editor agent session.' }
    else { Stop-Broker 'NOT READY: fix the FIX lines above (doctor -Fix applies what it can).' 9 }
}

function Wait-BrokerJob([string]$Project, [string]$JobId) {
    $deadline = (Get-BrokerNowMs) + [long]$TimeoutSec * 1000
    $offlineSince = 0
    $warned = $false
    while ($true) {
        $state = Invoke-BrokerUpdate $Project { param($s, $ctx) }
        $item = @($state.jobs | Where-Object { $_.id -eq $JobId }) | Select-Object -First 1
        if ($null -eq $item) { Stop-Broker "Unknown job $JobId (finished jobs are kept for the latest $($script:BrokerConfig.maxFinishedJobs))." 2 }
        if ($item.status -in @('passed','failed','blocked','canceled')) {
            if ($Json) { Write-Output ($item | ConvertTo-Json -Depth 10 -Compress) }
            else {
                Write-Output "$($item.id) $($item.status): $($item.summary)"
                foreach ($d in @($item.details)) { Write-Output "  $d" }
            }
            switch ($item.status) { 'passed' { return } 'failed' { Stop-Broker "$($item.id) failed." 8 } default { Stop-Broker "$($item.id) $($item.status)." 9 } }
        }
        $now = Get-BrokerNowMs
        if ((Get-BrokerEditorAgeMs (Read-BrokerEditor $Project)) -gt 30000) {
            if ($offlineSince -eq 0) { $offlineSince = $now }
            if (-not $warned) { Write-Warning 'No Editor heartbeat: the job runs when the Editor is back.'; $warned = $true }
            if ($now - $offlineSince -gt 600000) { Stop-Broker 'The Editor has been offline for 10 minutes.' 7 }
        } else { $offlineSince = 0 }
        if ($now -ge $deadline) { Stop-Broker "Timed out after $TimeoutSec s; $JobId is still $($item.status)." 6 }
        Start-Sleep -Milliseconds 1000
    }
}

function Invoke-BrokerCli {
    if ($Command -eq 'projects') {
        $entries = Get-BrokerMachineEntries
        if ($Json) { Write-Output (@($entries) | ConvertTo-Json -Depth 5 -Compress); return }
        if ($entries.Count -eq 0) { Write-Output 'No broker has registered on this machine yet.'; return }
        foreach ($e in @($entries | Sort-Object { -not $_.alive }, projectPath)) {
            $state = if ($e.alive) { 'live' } else { 'stale (' + (Format-BrokerAge $e.heartbeatAgeMs) + ' old)' }
            $session = if ($e.sessionId) { "session $($e.sessionId)" } else { 'no session' }
            $window = if ($e.window) { ", window $($e.window)" } else { '' }
            Write-Output "$state  $($e.projectPath)  Unity $($e.unityVersion), pid $($e.pid), $($e.phase), $session, $($e.leases) lease(s), $($e.queuedJobs) queued$window"
        }
        return
    }
    $project = Get-BrokerProject $ProjectRoot
    $now = Get-BrokerNowMs
    $needsAgent = @('take','renew','release','yield','gate','stage','request','done','cancel')
    if ($Command -in $needsAgent -and -not (Test-BrokerAgent $Agent)) { Stop-Broker 'Pass -Agent <name> (letters, digits, ., _ or -; at most 48).' 2 }
    $resolver = { param($name) Find-BrokerAsmdef $project $name }

    switch ($Command) {
        'install' { Invoke-BrokerInstall $project }
        'doctor' { Invoke-BrokerDoctor $project }
        'status' {
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) }
            if ($Job) {
                $item = @($state.jobs | Where-Object { $_.id -eq $Job }) | Select-Object -First 1
                if ($null -eq $item) { Stop-Broker "Unknown job $Job." 2 }
                if ($Json) { Write-Output ($item | ConvertTo-Json -Depth 10 -Compress) } else { Write-Output "$($item.id) $($item.status): $($item.summary)"; foreach ($d in @($item.details)) { Write-Output "  $d" } }
                return
            }
            $editor = Read-BrokerEditor $project
            if ($Json) { Write-Output ([ordered]@{ state = $state; editor = $editor } | ConvertTo-Json -Depth 20 -Compress) } else { Write-Output (Format-BrokerBoard $state $editor) }
        }
        'session' {
            if ($Action -notin @('start','stop')) { Stop-Broker "Use: session start -Agent <owner> | session stop" 2 }
            if ($Action -eq 'start') {
                if (-not (Test-BrokerAgent $Agent)) { Stop-Broker 'session start needs -Agent <owner>.' 2 }
                $state = Invoke-BrokerUpdate $project { param($s, $ctx)
                    if (-not $s.sessionId) { $s.sessionId = 'S' + $now; $s.sessionStartedMs = $now; $s.sessionOwner = $Agent; $ctx.save = $true } }
                Write-Output "Session $($state.sessionId) active (owner $($state.sessionOwner))."
            } else {
                $state = Invoke-BrokerUpdate $project { param($s, $ctx)
                    [void](Invoke-BrokerExpire $s $now)
                    if ($s.leases.Count -gt 0 -and -not $Force) { return }
                    $s.sessionId = ''; $s.sessionOwner = ''; $s.sessionStartedMs = 0; $ctx.save = $true }
                if ($state.sessionId) { Stop-Broker ('Leases are still held by: ' + ((@($state.leases | ForEach-Object { $_.agent }) | Select-Object -Unique) -join ', ') + '. Release them or pass -Force.') 2 }
                Write-Output 'Session stopped; the Editor restores the saved preferences.'
            }
            $editor = Read-BrokerEditor $project
            if ((Get-BrokerEditorAgeMs $editor) -gt 15000) { Write-Warning 'No live Editor: settings apply when the Editor connects.'; return }
            $want = [string]$state.sessionId
            $until = (Get-BrokerNowMs) + 30000
            while ((Get-BrokerNowMs) -lt $until) {
                $editor = Read-BrokerEditor $project
                if ($null -ne $editor -and [string]$editor.sessionId -eq $want) {
                    foreach ($setting in @($editor.settings | Where-Object { $_.scope -eq 'session' })) { Write-Output ('  ' + $(if ($setting.ok) { 'OK  ' } else { 'FIX ' }) + "$($setting.name) = $($setting.current)  ($($setting.note))") }
                    return
                }
                Start-Sleep -Milliseconds 500
            }
            Write-Warning 'The Editor did not confirm the session settings within 30 s; check the board.'
        }
        { $_ -in @('take', 'release') } {
            $parsedList = New-Object System.Collections.ArrayList
            foreach ($text in @($Resource)) {
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                $parsed = ConvertFrom-BrokerResource $text $resolver
                if (-not $parsed.ok) { Stop-Broker $parsed.error 2 }
                [void]$parsedList.Add(@{ text = $text; path = $parsed.path })
            }
            if ($Command -eq 'take' -and $parsedList.Count -eq 0) { Stop-Broker 'take needs -Resource <type:path>[,...].' 2 }
            if ($Command -eq 'release') {
                $state = Invoke-BrokerUpdate $project { param($s, $ctx)
                    $script:BrokerReleased = 0
                    if ($parsedList.Count -eq 0) { $script:BrokerReleased = Invoke-BrokerRelease $s $Agent '' }
                    else { foreach ($p in $parsedList) { $script:BrokerReleased += Invoke-BrokerRelease $s $Agent $p.path } }
                    [void](Invoke-BrokerPromote $s $now); $ctx.save = $true }
                Write-BrokerResult (New-BrokerResult $(if ($script:BrokerReleased -gt 0) { 'released' } else { 'none' }) "$script:BrokerReleased lease(s) or request(s) released.")
                return
            }
            $deadline = $now + [long]$TimeoutSec * 1000
            while ($true) {
                $tick = Get-BrokerNowMs
                $results = New-Object System.Collections.ArrayList
                $state = Invoke-BrokerUpdate $project { param($s, $ctx)
                    foreach ($p in $parsedList) { [void]$results.Add((Invoke-BrokerTake $s $Agent $Kind $p.text $p.path $TtlSec $tick)) }
                    [void](Invoke-BrokerPromote $s $tick); $ctx.save = $true }
                $errors = @($results | Where-Object { $_.status -eq 'error' })
                if ($errors.Count -gt 0) { foreach ($r in $errors) { Write-BrokerResult $r }; Stop-Broker 'Lease request rejected.' 2 }
                $held = @($parsedList | Where-Object { $p = $_; @($state.leases | Where-Object { (Test-BrokerSameAgent $_.agent $Agent) -and $_.kind -eq $Kind -and [string]::Equals($_.path, $p.path, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 })
                if ($held.Count -eq $parsedList.Count) {
                    foreach ($r in $results) { if ($r.status -eq 'queued') { $r.status = 'granted'; $r.message = 'Granted after waiting.' } ; Write-BrokerResult $r }
                    return
                }
                if (-not $Wait) { foreach ($r in $results) { Write-BrokerResult $r }; Stop-Broker 'Queued: run take again with -Wait, or work on something else and retry.' 3 }
                if ((Get-BrokerNowMs) -ge $deadline) { Stop-Broker "Still queued after $TimeoutSec s." 6 }
                Start-Sleep -Milliseconds 1000
            }
        }
        'renew' {
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) $script:BrokerCount = Invoke-BrokerRenew $s $Agent $TtlSec $now; [void](Invoke-BrokerPromote $s $now); $ctx.save = $true }
            Write-BrokerResult (New-BrokerResult $(if ($script:BrokerCount -gt 0) { 'renewed' } else { 'none' }) "$script:BrokerCount lease(s) or request(s) renewed.")
        }
        'yield' {
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) $script:BrokerCount = Invoke-BrokerYield $s $Agent $now; $ctx.save = $true }
            Write-BrokerResult (New-BrokerResult 'yielded' "$script:BrokerCount lease(s) marked safe for a window.")
        }
        'gate' {
            $deadline = $now + [long]$TimeoutSec * 1000
            while ($true) {
                $tick = Get-BrokerNowMs
                $state = Invoke-BrokerUpdate $project { param($s, $ctx) $script:BrokerGate = Invoke-BrokerGate $s $Agent $tick; $ctx.save = $true }
                if ($script:BrokerGate.status -eq 'go') { Write-BrokerResult $script:BrokerGate; return }
                if (-not $Wait) { Write-BrokerResult $script:BrokerGate; Stop-Broker 'Wait for the window to end (gate -Wait blocks until it does).' 4 }
                if ((Get-BrokerNowMs) -ge $deadline) { Stop-Broker "Window still active after $TimeoutSec s." 6 }
                Start-Sleep -Milliseconds 1000
            }
        }
        'stage' {
            $assetPath = Get-BrokerNormalizedPath $Path $false
            if ($null -eq $assetPath) { Stop-Broker 'stage needs -Path Assets/... (a file under Assets/ or Packages/).' 2 }
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) }
            if (-not (Test-BrokerHoldsCover $state $Agent $assetPath $now)) { Stop-Broker "$assetPath is not under a cold lease of $Agent. Take one first." 2 }
            $staged = Join-Path (Join-Path (Join-Path (Get-BrokerDir $project) 'staging') $Agent) ($assetPath.Replace('/', [IO.Path]::DirectorySeparatorChar))
            New-Item -ItemType Directory -Path (Split-Path -Parent $staged) -Force | Out-Null
            $live = Join-Path $project ($assetPath.Replace('/', [IO.Path]::DirectorySeparatorChar))
            if (-not (Test-Path -LiteralPath $staged)) {
                if (Test-Path -LiteralPath $live) { Copy-Item -LiteralPath $live -Destination $staged }
                elseif (-not $New) { Stop-Broker "$assetPath does not exist yet; pass -New to stage a new file." 2 }
            }
            if ($Json) { Write-Output ([ordered]@{ status = 'staged'; path = $assetPath; staged = $staged } | ConvertTo-Json -Compress) }
            else { Write-Output "Edit this file, then request a sync: $staged" }
        }
        'request' {
            if (-not $Lane) { Stop-Broker 'request needs -Lane sync|hot|exclusive.' 2 }
            $kindValue = if ($JobKind) { $JobKind } elseif ($Lane -eq 'sync') { 'sync' } elseif ($Lane -eq 'exclusive') { 'exclusive' } elseif ($Tests) { 'tests' } else { 'session' }
            $pathList = @(@($Paths) | ForEach-Object { if ($_) { $_.Split(@(';', ','), [StringSplitOptions]::RemoveEmptyEntries) } } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $state = Invoke-BrokerUpdate $project { param($s, $ctx)
                $script:BrokerRequest = Invoke-BrokerRequest $s $Agent $Lane $kindValue $pathList $Tests $TestMode $Scene $Minutes $Reason $now
                if ($script:BrokerRequest.status -ne 'error') { $ctx.save = $true } }
            $result = $script:BrokerRequest
            if ($result.status -eq 'error') { Write-BrokerResult $result; Stop-Broker 'Request rejected.' 2 }
            if ($Lane -eq 'sync' -and $pathList.Count -eq 0) {
                $stagingDir = Join-Path (Join-Path (Get-BrokerDir $project) 'staging') $Agent
                $count = if (Test-Path -LiteralPath $stagingDir) { @(Get-ChildItem -LiteralPath $stagingDir -Recurse -File).Count } else { 0 }
                if ($count -eq 0) { Write-Warning 'Nothing is staged for this agent; the sync window will only refresh and compile.' }
            }
            Write-BrokerResult $result
            if ($Wait) { Wait-BrokerJob $project $result.jobId }
        }
        'wait' {
            if (-not $Job) { Stop-Broker 'wait needs -Job <id>.' 2 }
            Wait-BrokerJob $project $Job
        }
        'done' {
            if (-not $Job) { Stop-Broker 'done needs -Job <id>.' 2 }
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) $script:BrokerDone = Invoke-BrokerDone $s $Agent $Job; if ($script:BrokerDone.status -ne 'error') { $ctx.save = $true } }
            Write-BrokerResult $script:BrokerDone
            if ($script:BrokerDone.status -eq 'error') { Stop-Broker 'Not finished.' 2 }
        }
        'cancel' {
            if (-not $Job) { Stop-Broker 'cancel needs -Job <id>.' 2 }
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) $script:BrokerCancel = Invoke-BrokerCancel $s $Agent $Job $now; if ($script:BrokerCancel.status -ne 'error') { $ctx.save = $true } }
            Write-BrokerResult $script:BrokerCancel
            if ($script:BrokerCancel.status -eq 'error') { Stop-Broker 'Not canceled.' 2 }
        }
    }
}

# Dot-source for tests: no project access on import.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-BrokerCli; exit 0 }
    catch [BrokerCliError] { Write-Error $_.Exception.Message -ErrorAction Continue; exit $_.Exception.Code }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}
