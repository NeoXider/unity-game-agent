#requires -Version 5.1
<#
Unity Game Agent editor broker CLI: several agents share ONE Unity Editor.
State lives in <project>/Library/UgaBroker and is executed by the com.neoxider.uga-editor-broker
package inside the Editor. This CLI works while the Editor compiles, reloads, plays or is closed.
Written for Windows PowerShell 5.1 and PowerShell 7+ (pwsh on macOS/Linux); tested on 5.1. See tools/shared-editor.md.

'stats' prints the project's telemetry (waits per agent, queue length, window and drain times).
'brief' tells one agent who else works in the project, what the queue holds with a rough ETA, what
it holds itself and what is new on the team board; 'say' posts to that board
(Library/UgaBroker/team-board.md).

Exit codes: 0 ok | 2 invalid request | 3 lease queued | 4 gate says wait | 6 timeout |
7 Editor offline | 8 job failed | 9 job blocked/canceled or doctor not ready.
#>
param(
    [Parameter(Position=0)]
    [ValidateSet('install','doctor','session','take','renew','release','yield','gate','stage','request','wait','done','cancel','status','stats','projects','brief','say')]
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
    # Team board and roster: say -Message [-To agent,...]; any agent command accepts -Role and -Doing.
    [string]$Message,
    [string[]]$To,
    [string]$Role,
    [string]$Doing,
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
# Set by the CLI for agent commands: every saved update records the caller in the roster.
$script:BrokerSeen = $null
$script:BrokerUnread = 0

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

function Get-BrokerNormalizedPath([string]$Raw, [bool]$Folder, [bool]$AllowProjectSettings = $false) {
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
    $settings = $AllowProjectSettings -and -not $Folder -and $root -ieq 'ProjectSettings'
    if ($root -ine 'Assets' -and $root -ine 'Packages' -and -not $settings) { return $null }
    if (-not $Folder -and $segments.Count -lt 2) { return $null }
    $segments[0] = if ($settings) { 'ProjectSettings' } elseif ($root -ieq 'Assets') { 'Assets' } else { 'Packages' }
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
            # ProjectSettings files (Build Settings, tags and layers) can be leased like assets.
            $p = Get-BrokerNormalizedPath $value $false $true
            if ($null -eq $p) { return & $fail 'An asset resource needs an Assets/, Packages/ or ProjectSettings/ file path.' }
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
        grantedMs = [long]$s.grantedMs; expiresMs = [long]$s.expiresMs; yielded = [bool]$s.yielded; note = [string]$s.note
        waitedMs = [long]$s.waitedMs; counted = [bool]$s.counted }
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
        summary = [string]$s.summary; details = (New-BrokerStringList $s.details); counted = [bool]$s.counted }
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

function ConvertTo-BrokerMember($s) {
    return [ordered]@{ agent = [string]$s.agent; role = [string]$s.role; doing = [string]$s.doing; firstSeenMs = [long]$s.firstSeenMs
        lastSeenMs = [long]$s.lastSeenMs; lastCommand = [string]$s.lastCommand; readId = [long]$s.readId }
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
        roster = New-BrokerList (@($Source.roster) | Where-Object { $null -ne $_ } | ForEach-Object { ConvertTo-BrokerMember $_ })
    }
    # Telemetry is counted by the Editor (BrokerTelemetry.cs); the CLI only carries it through.
    if ($null -ne $Source.telemetry) { $state.telemetry = $Source.telemetry }
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

function Add-BrokerLease($State, [string]$Agent, [string]$Kind, [string]$ResourceText, [string]$LeasePath, [long]$TtlMs, [long]$Now, [long]$WaitedMs = 0) {
    $lease = [ordered]@{ id = (New-BrokerId $State 'L'); agent = $Agent; kind = $Kind; resource = $ResourceText; path = $LeasePath
        grantedMs = $Now; expiresMs = 0; yielded = $false; note = ''; waitedMs = [Math]::Max([long]0, $WaitedMs); counted = $false }
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
        $waitedMs = 0
        if ($ownWaiterIndex -ge 0) { $waitedMs = $Now - [long]$State.waiting[$ownWaiterIndex].requestedMs; $State.waiting.RemoveAt($ownWaiterIndex) }
        $lease = Add-BrokerLease $State $Agent $LeaseKind $ResourceText $LeasePath $ttlMs $Now $waitedMs
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
        [void]$granted.Add((Add-BrokerLease $State $w.agent $w.kind $w.resource $w.path ([long][Math]::Max(10, $w.ttlSec) * 1000) $Now ($Now - [long]$w.requestedMs)))
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
        if ($null -ne $script:BrokerSeen) {
            $__buSeen = $script:BrokerSeen
            if ($__buCtx.save) { [void](Update-BrokerRoster $__buState $__buSeen.agent $__buSeen.command (Get-BrokerNowMs) $__buSeen.role $__buSeen.doing) }
            $__buMember = @($__buState.roster | Where-Object { Test-BrokerSameAgent $_.agent $__buSeen.agent }) | Select-Object -First 1
            $__buReadId = if ($null -ne $__buMember) { [long]$__buMember.readId } else { [long]0 }
            $script:BrokerUnread = @(Get-BrokerBoardUnread (Read-BrokerBoard $__buProject) $__buReadId $__buSeen.agent).Count
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

# ---------------------------------------------------------------- telemetry (counted by BrokerTelemetry.cs)
function Get-BrokerRatio([double]$Total, [double]$Count) { if ($Count -le 0) { return 0 } return $Total / $Count }

# One segment (the live counters or a line of telemetry.jsonl) as averages and peaks.
function Get-BrokerTelemetryView($T, [long]$Now) {
    $since = [long]$T.sinceMs
    $until = if ([long]$T.endedMs -gt 0) { [long]$T.endedMs } else { $Now }
    $span = [Math]::Max([long]1, $until - $since)
    # [long]0: with a plain 0 PowerShell picks Math.Max(int, int) and overflows on millisecond stamps.
    $avgLevel = { param($integral, $level, $levelSince)
        $from = if ([long]$levelSince -gt 0) { [long]$levelSince } else { $since }
        ([double]$integral + [double]$level * [Math]::Max([long]0, $until - $from)) / $span }
    $agents = foreach ($a in @($T.agents)) {
        if ($null -eq $a) { continue }
        [ordered]@{ agent = [string]$a.agent; jobs = [int]$a.jobs; failed = [int]$a.failed; blocked = [int]$a.blocked
            avgWaitMs = [long](Get-BrokerRatio $a.waitMs $a.jobs); maxWaitMs = [long]$a.waitMaxMs; avgRunMs = [long](Get-BrokerRatio $a.runMs $a.jobs)
            leaseWaits = [int]$a.leaseWaits; avgLeaseWaitMs = [long](Get-BrokerRatio $a.leaseWaitMs $a.leaseWaits); maxLeaseWaitMs = [long]$a.leaseWaitMaxMs }
    }
    $lanes = foreach ($l in @($T.lanes)) {
        if ($null -eq $l) { continue }
        [ordered]@{ lane = [string]$l.lane; jobs = [int]$l.jobs; avgWaitMs = [long](Get-BrokerRatio $l.waitMs $l.jobs); maxWaitMs = [long]$l.waitMaxMs
            avgRunMs = [long](Get-BrokerRatio $l.runMs $l.jobs); windows = [int]$l.windows; avgWindowMs = [long](Get-BrokerRatio $l.windowMs $l.windows)
            avgDrainMs = [long](Get-BrokerRatio $l.drainMs $l.windows) }
    }
    return [ordered]@{
        sessionId = [string]$T.sessionId; sinceMs = $since; endedMs = [long]$T.endedMs; minutes = [Math]::Round($span / 60000.0, 1)
        jobs = [int]$T.jobs; failed = [int]$T.failed; blocked = [int]$T.blocked; canceled = [int]$T.canceled
        avgWaitMs = [long](Get-BrokerRatio $T.waitMs $T.jobs); maxWaitMs = [long]$T.waitMaxMs; avgRunMs = [long](Get-BrokerRatio $T.runMs $T.jobs)
        windows = [int]$T.windows; avgWindowMs = [long](Get-BrokerRatio $T.windowMs $T.windows); maxWindowMs = [long]$T.windowMaxMs
        avgDrainMs = [long](Get-BrokerRatio $T.drainMs $T.windows)
        avgQueue = [Math]::Round((& $avgLevel $T.queueIntegral $T.queueLevel $T.queueSinceMs), 2); queuePeak = [int]$T.queuePeak
        avgLeaseWaiters = [Math]::Round((& $avgLevel $T.waitersIntegral $T.waitersLevel $T.waitersSinceMs), 2); leaseWaitersPeak = [int]$T.waitersPeak
        leaseWaits = [int]$T.leaseWaits; avgLeaseWaitMs = [long](Get-BrokerRatio $T.leaseWaitMs $T.leaseWaits); maxLeaseWaitMs = [long]$T.leaseWaitMaxMs
        agents = @($agents); lanes = @($lanes)
    }
}

# Every closed segment in telemetry.jsonl plus the live one, summed up for the project.
function Get-BrokerStats([string]$Project, $State, [long]$Now) {
    $history = New-Object System.Collections.ArrayList
    $file = Join-Path (Get-BrokerDir $Project) 'telemetry.jsonl'
    if (Test-Path -LiteralPath $file) {
        foreach ($line in [IO.File]::ReadAllLines($file)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try { [void]$history.Add((Get-BrokerTelemetryView ($line | ConvertFrom-Json) $Now)) } catch { continue }
        }
    }
    $current = if ($null -ne $State.telemetry -and [long]$State.telemetry.sinceMs -gt 0) { Get-BrokerTelemetryView $State.telemetry $Now } else { $null }
    $all = New-Object System.Collections.ArrayList
    foreach ($v in $history) { [void]$all.Add($v) }
    if ($null -ne $current) { [void]$all.Add($current) }
    # Ordered dictionaries do not work with Measure-Object -Property: sum by hand.
    $jobs = 0; $minutes = 0.0; $waitTotal = 0.0; $queueWeighted = 0.0; $windows = 0; $drainTotal = 0.0; $maxWait = [long]0; $queuePeak = 0
    foreach ($v in $all) {
        $jobs += $v.jobs; $minutes += $v.minutes; $windows += $v.windows
        $waitTotal += [double]$v.avgWaitMs * $v.jobs; $queueWeighted += [double]$v.avgQueue * $v.minutes; $drainTotal += [double]$v.avgDrainMs * $v.windows
        $maxWait = [Math]::Max($maxWait, [long]$v.maxWaitMs); $queuePeak = [Math]::Max($queuePeak, [int]$v.queuePeak)
    }
    # Not $project: PowerShell names ignore case, and that would overwrite the [string]$Project parameter.
    $totals = [ordered]@{
        segments = $all.Count; minutes = [Math]::Round($minutes, 1); jobs = $jobs
        avgWaitMs = [long](Get-BrokerRatio $waitTotal $jobs); maxWaitMs = $maxWait
        avgQueue = [Math]::Round((Get-BrokerRatio $queueWeighted $minutes), 2); queuePeak = $queuePeak
        windows = $windows; avgDrainMs = [long](Get-BrokerRatio $drainTotal $windows)
    }
    return [ordered]@{ current = $current; history = @($history); project = $totals }
}

function Format-BrokerStats($Stats) {
    $lines = New-Object System.Collections.ArrayList
    $c = $Stats.current
    if ($null -eq $c) { [void]$lines.Add('No telemetry yet: the Editor counts it while the broker runs.') }
    else {
        $label = if ($c.sessionId) { "Session $($c.sessionId)" } else { 'Outside a session' }
        [void]$lines.Add("$label, $($c.minutes) min")
        [void]$lines.Add("  Jobs: $($c.jobs) ($($c.failed) failed, $($c.blocked) blocked, $($c.canceled) canceled); wait avg $(Format-BrokerAge $c.avgWaitMs), max $(Format-BrokerAge $c.maxWaitMs); run avg $(Format-BrokerAge $c.avgRunMs)")
        [void]$lines.Add("  Queue: avg $($c.avgQueue) queued job(s), peak $($c.queuePeak); lease waiters avg $($c.avgLeaseWaiters), peak $($c.leaseWaitersPeak)")
        [void]$lines.Add("  Windows: $($c.windows), run avg $(Format-BrokerAge $c.avgWindowMs), max $(Format-BrokerAge $c.maxWindowMs); drain avg $(Format-BrokerAge $c.avgDrainMs)")
        [void]$lines.Add("  Lease waits: $($c.leaseWaits), avg $(Format-BrokerAge $c.avgLeaseWaitMs), max $(Format-BrokerAge $c.maxLeaseWaitMs)")
        if (@($c.agents).Count -gt 0) {
            [void]$lines.Add('  Agent            jobs  wait avg  wait max   run avg  lease waits  lease wait avg')
            foreach ($a in @($c.agents | Sort-Object { $_.agent })) {
                [void]$lines.Add(('  {0,-15} {1,5} {2,9} {3,9} {4,9} {5,12} {6,15}' -f $a.agent, $a.jobs, (Format-BrokerAge $a.avgWaitMs), (Format-BrokerAge $a.maxWaitMs), (Format-BrokerAge $a.avgRunMs), $a.leaseWaits, (Format-BrokerAge $a.avgLeaseWaitMs)))
            }
        }
        if (@($c.lanes).Count -gt 0) {
            [void]$lines.Add('  Lane        jobs  wait avg  windows  window avg  drain avg')
            foreach ($l in @($c.lanes | Sort-Object { $_.lane })) {
                [void]$lines.Add(('  {0,-10} {1,5} {2,9} {3,8} {4,11} {5,10}' -f $l.lane, $l.jobs, (Format-BrokerAge $l.avgWaitMs), $l.windows, (Format-BrokerAge $l.avgWindowMs), (Format-BrokerAge $l.avgDrainMs)))
            }
        }
    }
    $p = $Stats.project
    [void]$lines.Add("Project ($($p.segments) segment(s), $($p.minutes) min): $($p.jobs) job(s), wait avg $(Format-BrokerAge $p.avgWaitMs), max $(Format-BrokerAge $p.maxWaitMs); queue avg $($p.avgQueue), peak $($p.queuePeak); $($p.windows) window(s), drain avg $(Format-BrokerAge $p.avgDrainMs)")
    return ($lines -join "`n")
}

# ---------------------------------------------------------------- team: roster, queue forecast and board (mirror BrokerTeam.cs)
$script:BrokerTeamConfig = [ordered]@{
    rosterTtlMs = 7200000; activeMs = 600000; maxMessageChars = 300; maxRoleChars = 32; maxDoingChars = 120
    briefMessages = 5; messageLineChars = 160
    hotMaxWaitMs = 600000; hotBatchSize = 3   # the scheduler's hot rule (BrokerConfig.cs)
}
# Guesses for a lane without telemetry yet; the sync and exclusive waits are the scheduler's maximum.
$script:BrokerForecastDefaults = @{
    sync = @{ runMs = 30000; drainMs = 10000; waitMs = 30000 }
    hot = @{ runMs = 60000; drainMs = 10000; waitMs = 120000 }
    exclusive = @{ runMs = 0; drainMs = 10000; waitMs = 120000 }
}

function Get-BrokerOneLine([string]$Text, [int]$Max) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $line = ($Text -replace '\s+', ' ').Trim()
    if ($line.Length -gt $Max) { $line = $line.Substring(0, $Max).TrimEnd() }
    return $line
}

function Test-BrokerBusy($State, [string]$Agent, [long]$Now) {
    if (@($State.leases | Where-Object { $_.expiresMs -gt $Now -and (Test-BrokerSameAgent $_.agent $Agent) }).Count -gt 0) { return $true }
    if (@($State.waiting | Where-Object { $_.expiresMs -gt $Now -and (Test-BrokerSameAgent $_.agent $Agent) }).Count -gt 0) { return $true }
    return @($State.jobs | Where-Object { $_.status -in @('queued','running') -and (Test-BrokerSameAgent $_.agent $Agent) }).Count -gt 0
}

# Records that an agent called the broker. Agents quiet for longer than the roster TTL that hold
# nothing drop out, so the roster lists the agents of the current work, not of last week.
function Update-BrokerRoster($State, [string]$Agent, [string]$CommandName, [long]$Now, [string]$RoleText = '', [string]$DoingText = '') {
    $member = @($State.roster | Where-Object { Test-BrokerSameAgent $_.agent $Agent }) | Select-Object -First 1
    if ($null -eq $member) {
        $member = ConvertTo-BrokerMember ([pscustomobject]@{ agent = $Agent; firstSeenMs = $Now })
        [void]$State.roster.Add($member)
    }
    $member.lastSeenMs = $Now
    $member.lastCommand = [string]$CommandName
    $roleLine = Get-BrokerOneLine $RoleText $script:BrokerTeamConfig.maxRoleChars
    if ($roleLine) { $member.role = $roleLine }
    $doingLine = Get-BrokerOneLine $DoingText $script:BrokerTeamConfig.maxDoingChars
    if ($doingLine) { $member.doing = $doingLine }
    $cutoff = $Now - $script:BrokerTeamConfig.rosterTtlMs
    $State.roster = New-BrokerList ($State.roster | Where-Object { $_.lastSeenMs -gt $cutoff -or (Test-BrokerSameAgent $_.agent $Agent) -or (Test-BrokerBusy $State $_.agent $Now) })
    return $member
}

# Sums the per-lane counters of telemetry segments (closed history plus the live one).
function Get-BrokerLaneTotals($Segments) {
    $totals = [ordered]@{}
    foreach ($segment in @($Segments)) {
        if ($null -eq $segment) { continue }
        foreach ($l in @($segment.lanes)) {
            if ($null -eq $l -or [string]::IsNullOrEmpty([string]$l.lane)) { continue }
            $key = [string]$l.lane
            if (-not $totals.Contains($key)) { $totals[$key] = [ordered]@{ lane = $key; jobs = 0; waitMs = [long]0; windows = 0; windowMs = [long]0; drainMs = [long]0 } }
            $t = $totals[$key]
            $t.jobs += [int]$l.jobs; $t.waitMs += [long]$l.waitMs; $t.windows += [int]$l.windows
            $t.windowMs += [long]$l.windowMs; $t.drainMs += [long]$l.drainMs
        }
    }
    return @($totals.Values)
}

# Average window run, drain and job wait per lane; a lane without data keeps the defaults.
function Get-BrokerLaneAverages($Lanes) {
    $averages = @{}
    foreach ($name in @('sync', 'hot', 'exclusive')) {
        $d = $script:BrokerForecastDefaults[$name]
        $averages[$name] = @{ runMs = [long]$d.runMs; drainMs = [long]$d.drainMs; waitMs = [long]$d.waitMs; measured = $false }
    }
    foreach ($l in @($Lanes)) {
        if ($null -eq $l -or -not $averages.ContainsKey([string]$l.lane)) { continue }
        $a = $averages[[string]$l.lane]
        if ([int]$l.windows -gt 0) {
            $a.runMs = [long][Math]::Floor([double]$l.windowMs / [int]$l.windows)
            $a.drainMs = [long][Math]::Floor([double]$l.drainMs / [int]$l.windows)
            $a.measured = $true
        }
        if ([int]$l.jobs -gt 0) { $a.waitMs = [long][Math]::Floor([double]$l.waitMs / [int]$l.jobs) }
    }
    return $averages
}

function Get-BrokerJobDurationMs($JobItem, $Average) {
    if ($JobItem.kind -eq 'exclusive' -and $Average.measured) { return [long]$Average.runMs }
    return [long][Math]::Round([double]$JobItem.minutes * 60000)
}

function New-BrokerForecastEntry($JobItem, [int]$Order, [long]$Start, [long]$Done) {
    return [ordered]@{ jobId = [string]$JobItem.id; agent = [string]$JobItem.agent; lane = [string]$JobItem.lane; kind = [string]$JobItem.kind
        status = [string]$JobItem.status; order = $Order; startMs = $Start; doneMs = $Done; waitsForCold = $false }
}

function Test-BrokerBatchJob([string]$WindowLane, $JobItem) { return $WindowLane -eq 'sync' -or ($WindowLane -eq 'hot' -and $JobItem.kind -eq 'tests') }

# Adds the jobs of one window, in run order, and returns when the window ends. The sync jobs and the
# tests of a hot window run as one batch; sessions and exclusive work follow one by one. A job that
# has started keeps its start and ends no earlier than now.
function Add-BrokerForecastWindow($Forecast, [string]$WindowLane, $Jobs, [long]$Cursor, $Averages, [int]$Order, [long]$Now) {
    $avg = $Averages[$WindowLane]
    $batch = @($Jobs | Where-Object { Test-BrokerBatchJob $WindowLane $_ })
    if ($batch.Count -gt 0) {
        $started = [long]0
        foreach ($j in $batch) { if ([long]$j.startedMs -gt 0 -and ($started -eq 0 -or [long]$j.startedMs -lt $started)) { $started = [long]$j.startedMs } }
        if ($started -gt 0) { $start = $started; $done = [Math]::Max($Now, $started + [long]$avg.runMs) }
        else { $start = $Cursor; $done = $Cursor + [long]$avg.runMs }
        foreach ($j in $batch) { [void]$Forecast.Add((New-BrokerForecastEntry $j $Order $start $done)) }
        $Cursor = $done
    }
    foreach ($j in @($Jobs | Where-Object { -not (Test-BrokerBatchJob $WindowLane $_) })) {
        $duration = Get-BrokerJobDurationMs $j $avg
        if ([long]$j.startedMs -gt 0) { $start = [long]$j.startedMs; $done = [Math]::Max($Now, $start + $duration) }
        else { $start = $Cursor; $done = $Cursor + $duration }
        [void]$Forecast.Add((New-BrokerForecastEntry $j $Order $start $done))
        $Cursor = $done
    }
    return $Cursor
}

# A planned window opens after the previous one plus a drain, and not before its oldest job is as
# old as the lane's average wait (which folds in how long agents take to yield) or $NotBefore.
function Add-BrokerPlannedWindow($Forecast, [string]$WindowLane, $Jobs, [long]$Cursor, $Averages, [int]$Order, [long]$Now, [long]$NotBefore = 0) {
    $avg = $Averages[$WindowLane]
    $oldest = [long]::MaxValue
    foreach ($j in $Jobs) { if ([long]$j.createdMs -lt $oldest) { $oldest = [long]$j.createdMs } }
    $start = [Math]::Max([Math]::Max($Cursor + [long]$avg.drainMs, $oldest + [long]$avg.waitMs), $NotBefore)
    return Add-BrokerForecastWindow $Forecast $WindowLane $Jobs $start $Averages $Order $Now
}

# Rough plan of the queue in the scheduler's order: the active window (order 0), one sync window for
# every staged change, each exclusive request, then one hot window (tests first, then sessions).
# Jobs queued later can still go first (a new sync request opens before waiting hot work).
function Get-BrokerForecast($State, $Averages, [long]$Now) {
    $forecast = New-Object System.Collections.ArrayList
    $cursor = $Now
    $taken = @{}
    if ((Test-BrokerWindow $State) -and $Averages.ContainsKey([string]$State.window.lane)) {
        $w = $State.window
        $inWindow = New-Object System.Collections.ArrayList
        foreach ($id in @($w.jobIds)) {
            $taken[[string]$id] = $true
            $item = @($State.jobs | Where-Object { $_.id -eq $id }) | Select-Object -First 1
            if ($null -ne $item -and $item.status -in @('queued', 'running')) { [void]$inWindow.Add($item) }
        }
        if ([long]$w.startedMs -le 0) {
            $drain = [long]$Averages[[string]$w.lane].drainMs
            $deadline = if ([long]$w.drainDeadlineMs -gt 0) { [long]$w.drainDeadlineMs } else { [long]$w.requestedMs + $drain }
            $cursor = [Math]::Max($Now, [Math]::Min($deadline, [long]$w.requestedMs + $drain))
        }
        $cursor = Add-BrokerForecastWindow $forecast ([string]$w.lane) $inWindow $cursor $Averages 0 $Now
    }
    $indexed = for ($i = 0; $i -lt $State.jobs.Count; $i++) {
        $j = $State.jobs[$i]
        if ($j.status -eq 'queued' -and -not $taken.ContainsKey([string]$j.id)) { [pscustomobject]@{ job = $j; index = $i } }
    }
    # Sort-Object is not stable in Windows PowerShell: the list index breaks ties like LINQ OrderBy.
    $queued = @($indexed | Sort-Object @{ Expression = { [long]$_.job.createdMs } }, @{ Expression = { $_.index } } | ForEach-Object { $_.job })
    $order = 0
    $sync = @($queued | Where-Object { $_.lane -eq 'sync' })
    if ($sync.Count -gt 0) { $order++; $cursor = Add-BrokerPlannedWindow $forecast 'sync' $sync $cursor $Averages $order $Now }
    foreach ($e in @($queued | Where-Object { $_.lane -eq 'exclusive' })) { $order++; $cursor = Add-BrokerPlannedWindow $forecast 'exclusive' @($e) $cursor $Averages $order $Now }
    $hot = @(@($queued | Where-Object { $_.lane -eq 'hot' -and $_.kind -eq 'tests' }) + @($queued | Where-Object { $_.lane -eq 'hot' -and $_.kind -ne 'tests' }))
    if ($hot.Count -gt 0) {
        # Cold work wins: while a lease holder has not yielded or a lease request waits, the hot window
        # opens only at the scheduler's maximum wait (or with a full batch). The forecast then gives
        # that latest time and says so; agents yielding earlier make it sooner.
        $coldQuiet = @($State.leases | Where-Object { $_.expiresMs -gt $Now -and -not $_.yielded }).Count -eq 0 -and $State.waiting.Count -eq 0
        $held = -not $coldQuiet -and $hot.Count -lt $script:BrokerTeamConfig.hotBatchSize
        $notBefore = [long]0
        if ($held) { foreach ($j in $hot) { $due = [long]$j.createdMs + $script:BrokerTeamConfig.hotMaxWaitMs; if ($notBefore -eq 0 -or $due -lt $notBefore) { $notBefore = $due } } }
        $first = $forecast.Count
        $order++; $cursor = Add-BrokerPlannedWindow $forecast 'hot' $hot $cursor $Averages $order $Now $notBefore
        if ($held) { for ($i = $first; $i -lt $forecast.Count; $i++) { $forecast[$i].waitsForCold = $true } }
    }
    return ,$forecast
}

# Telemetry history (telemetry.jsonl) as raw segments; the live segment is in the state.
function Get-BrokerTelemetryHistory([string]$Project) {
    $segments = New-Object System.Collections.ArrayList
    $file = Join-Path (Get-BrokerDir $Project) 'telemetry.jsonl'
    if (-not (Test-Path -LiteralPath $file)) { return ,$segments }
    foreach ($line in [IO.File]::ReadAllLines($file)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { [void]$segments.Add(($line | ConvertFrom-Json)) } catch { continue }
    }
    return ,$segments
}

# The team board is a Markdown log in Library/UgaBroker. Every entry is a '### M<n> <UTC time> <from> -> <to>'
# heading and a body; ids come from the state counter and are appended under the state lock.
$script:BrokerBoardHeader = (@'
# Team board

Notes between the agents of this project, oldest first. Post with
`editor-broker.ps1 say -Agent <you> -Message "..." [-To <agent>]`; `brief` shows what is new for you.
Post through the broker (it appends under the state lock) instead of editing this file.
'@).Replace("`r`n", "`n") + "`n`n"

function Get-BrokerBoardFile([string]$Project) { return Join-Path (Get-BrokerDir $Project) 'team-board.md' }

# LF line ends, no blank edges, and no line that would start a Markdown heading (or a new entry).
function ConvertTo-BrokerBoardText([string]$Text) {
    $lines = ([string]$Text -replace "`r`n?", "`n").Trim().Split("`n")
    $clean = foreach ($line in $lines) { if ($line.StartsWith('#')) { '\' + $line.TrimEnd() } else { $line.TrimEnd() } }
    return (@($clean) -join "`n")
}

function Format-BrokerBoardEntry([long]$Number, [long]$Now, [string]$From, [string[]]$To, [string]$Text) {
    $at = [DateTimeOffset]::FromUnixTimeMilliseconds($Now).UtcDateTime.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    return "### M$Number ${at}Z $From -> $(@($To) -join ',')`n$(ConvertTo-BrokerBoardText $Text)`n`n"
}

function ConvertFrom-BrokerBoard([string]$Text) {
    $entries = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrEmpty($Text)) { return ,$entries }
    $current = $null
    $body = $null
    $finish = { if ($null -ne $current) { $current.text = (@($body) -join "`n").Trim(); [void]$entries.Add($current) } }
    foreach ($raw in $Text.Split("`n")) {
        $line = $raw.TrimEnd("`r")
        $m = [regex]::Match($line, '^### M(\d{1,18}) (\d{4}-\d\d-\d\d \d\d:\d\d:\d\dZ) (\S+) -> (\S+)\s*$')
        if ($m.Success) {
            . $finish
            $current = [ordered]@{ id = 'M' + $m.Groups[1].Value; number = [long]$m.Groups[1].Value; at = $m.Groups[2].Value
                from = $m.Groups[3].Value; to = @($m.Groups[4].Value.Split(',') | Where-Object { $_ }); text = '' }
            $body = New-Object System.Collections.ArrayList
            continue
        }
        if ($null -ne $current) { [void]$body.Add($line) }
    }
    . $finish
    return ,$entries
}

function Read-BrokerBoard([string]$Project) {
    $file = Get-BrokerBoardFile $Project
    if (-not (Test-Path -LiteralPath $file)) { return ,(New-Object System.Collections.ArrayList) }
    $entries = ConvertFrom-BrokerBoard ([IO.File]::ReadAllText($file, [Text.Encoding]::UTF8))
    return ,$entries
}

# Call inside Invoke-BrokerUpdate: the id comes from the state and the append runs under its lock.
function Add-BrokerBoardMessage([string]$Project, $State, [string]$From, [string[]]$To, [string]$Text, [long]$Now) {
    $file = Get-BrokerBoardFile $Project
    $id = New-BrokerId $State 'M'
    $entry = Format-BrokerBoardEntry ([long]$id.Substring(1)) $Now $From $To $Text
    if (-not (Test-Path -LiteralPath $file)) { $entry = $script:BrokerBoardHeader + $entry }
    [IO.File]::AppendAllText($file, $entry, $script:Utf8NoBom)
    return $id
}

function Test-BrokerBoardFor($Entry, [string]$Agent) {
    if (Test-BrokerSameAgent $Entry.from $Agent) { return $false }
    foreach ($t in @($Entry.to)) { if ($t -ieq 'all' -or (Test-BrokerSameAgent $t $Agent)) { return $true } }
    return $false
}

function Get-BrokerBoardUnread($Entries, [long]$ReadId, [string]$Agent) {
    return @($Entries | Where-Object { $_.number -gt $ReadId -and (Test-BrokerBoardFor $_ $Agent) })
}

# Short job name for the brief: "sync", "hot/tests", "hot/session 3 min", "exclusive".
function Get-BrokerJobShort($JobItem) {
    if ($null -eq $JobItem) { return '' }
    $name = if ($JobItem.lane -eq $JobItem.kind) { [string]$JobItem.lane } else { "$($JobItem.lane)/$($JobItem.kind)" }
    if ($JobItem.kind -eq 'session') { $name += " $($JobItem.minutes) min" }
    return $name
}

# One line of at most $Max characters: line breaks become ' / '.
function Get-BrokerClip([string]$Text, [int]$Max) {
    $line = @(([string]$Text).Split("`n") | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' / '
    if ($line.Length -gt $Max) { $line = $line.Substring(0, $Max - 3).TrimEnd() + '...' }
    return $line
}

# Everything one agent needs before its next step, kept short because it lands in the agent's context:
# who else works here, the queue with a rough ETA, what blocks it and what is new on the team board.
# Marks the board as read for the agent.
function Get-BrokerBrief([string]$Project, $State, $Editor, [string]$Agent, [long]$Now, $History, [string]$RoleText = '', [string]$DoingText = '') {
    $segments = @($History) + @($State.telemetry) | Where-Object { $null -ne $_ }
    $averages = Get-BrokerLaneAverages (Get-BrokerLaneTotals $segments)
    $forecast = Get-BrokerForecast $State $averages $Now
    $member = Update-BrokerRoster $State $Agent 'brief' $Now $RoleText $DoingText
    $entries = Read-BrokerBoard $Project
    $unread = @(Get-BrokerBoardUnread $entries $member.readId $Agent)
    $othersNew = @($entries | Where-Object { $_.number -gt $member.readId -and -not (Test-BrokerSameAgent $_.from $Agent) -and -not (Test-BrokerBoardFor $_ $Agent) }).Count
    foreach ($e in $entries) { if ($e.number -gt $member.readId) { $member.readId = [long]$e.number } }

    $names = New-Object System.Collections.ArrayList
    $addName = { param($n) if ($n -and -not @($names | Where-Object { Test-BrokerSameAgent $_ $n })) { [void]$names.Add([string]$n) } }
    foreach ($m in $State.roster) { & $addName $m.agent }
    foreach ($l in $State.leases) { & $addName $l.agent }
    foreach ($w in $State.waiting) { & $addName $w.agent }
    foreach ($j in @($State.jobs | Where-Object { $_.status -in @('queued', 'running') })) { & $addName $j.agent }
    $team = foreach ($name in $names) {
        $m = @($State.roster | Where-Object { Test-BrokerSameAgent $_.agent $name }) | Select-Object -First 1
        $seen = if ($null -ne $m) { [long]$m.lastSeenMs } else { [long]0 }
        [ordered]@{ agent = $name; you = (Test-BrokerSameAgent $name $Agent); role = $(if ($null -ne $m) { $m.role } else { '' }); doing = $(if ($null -ne $m) { $m.doing } else { '' })
            lastSeenMs = $seen; active = (($seen -gt 0 -and $Now - $seen -le $script:BrokerTeamConfig.activeMs) -or (Test-BrokerBusy $State $name $Now))
            leases = @($State.leases | Where-Object { $_.expiresMs -gt $Now -and (Test-BrokerSameAgent $_.agent $name) } | ForEach-Object { "$($_.kind) $($_.path)" + $(if ($_.yielded) { ' (yielded)' } else { '' }) })
            waiting = @($State.waiting | Where-Object { Test-BrokerSameAgent $_.agent $name } | ForEach-Object { "$($_.kind) $($_.path)" })
            jobs = @($State.jobs | Where-Object { $_.status -in @('queued', 'running') -and (Test-BrokerSameAgent $_.agent $name) } | ForEach-Object { "$($_.id) $(Get-BrokerJobShort $_)" + $(if ($_.status -eq 'running') { ' running' } else { '' }) }) }
    }
    $queue = foreach ($f in $forecast) {
        $item = @($State.jobs | Where-Object { $_.id -eq $f.jobId }) | Select-Object -First 1
        $entry = [ordered]@{}
        foreach ($k in $f.Keys) { $entry[$k] = $f[$k] }
        $entry.label = Get-BrokerJobShort $item
        $entry.mine = Test-BrokerSameAgent $f.agent $Agent
        $entry
    }
    $myWaiting = for ($i = 0; $i -lt $State.waiting.Count; $i++) {
        $w = $State.waiting[$i]
        if (-not (Test-BrokerSameAgent $w.agent $Agent)) { continue }
        $behind = New-Object System.Collections.ArrayList
        foreach ($l in $State.leases) { if ($l.expiresMs -gt $Now -and (Test-BrokerConflict $w.agent $w.kind $w.path $l.agent $l.kind $l.path) -and -not $behind.Contains($l.agent)) { [void]$behind.Add($l.agent) } }
        for ($k = 0; $k -lt $i; $k++) { $e = $State.waiting[$k]; if ((Test-BrokerConflict $w.agent $w.kind $w.path $e.agent $e.kind $e.path) -and -not $behind.Contains($e.agent)) { [void]$behind.Add($e.agent) } }
        [ordered]@{ id = $w.id; kind = $w.kind; path = $w.path; position = $i + 1; behind = @($behind) }
    }
    $window = $null
    if (Test-BrokerWindow $State) {
        $w = $State.window
        $unyielded = if ($w.phase -eq 'draining') { @($State.leases | Where-Object { $_.expiresMs -gt $Now -and -not $_.yielded -and -not (Test-BrokerSameAgent $_.agent $w.holder) } | ForEach-Object { $_.agent } | Select-Object -Unique) } else { @() }
        $window = [ordered]@{ id = $w.id; lane = $w.lane; phase = $w.phase; holder = $w.holder; jobIds = @($w.jobIds); unyielded = @($unyielded); drainDeadlineMs = [long]$w.drainDeadlineMs }
    }
    $measured = @($averages.Values | Where-Object { $_.measured }).Count -gt 0
    return [ordered]@{
        agent = $Agent; atMs = $Now; sessionId = $State.sessionId; sessionOwner = $State.sessionOwner; paused = [bool]$State.paused
        editor = $(if ($null -eq $Editor) { $null } else { [ordered]@{ phase = [string]$Editor.phase; heartbeatAgeMs = (Get-BrokerEditorAgeMs $Editor); compileFailed = [bool]$Editor.compileFailed } })
        window = $window; team = @($team); queue = @($queue); estimates = $(if ($measured) { 'telemetry' } else { 'defaults' })
        mine = [ordered]@{
            leases = @($State.leases | Where-Object { $_.expiresMs -gt $Now -and (Test-BrokerSameAgent $_.agent $Agent) } | ForEach-Object { [ordered]@{ id = $_.id; kind = $_.kind; path = $_.path; expiresInMs = $_.expiresMs - $Now; yielded = [bool]$_.yielded } })
            waiting = @($myWaiting)
        }
        board = [ordered]@{ path = (Get-BrokerBoardFile $Project); total = $entries.Count; unreadTotal = $unread.Count
            unread = @($unread | Select-Object -Last $script:BrokerTeamConfig.briefMessages); othersNew = $othersNew }
    }
}

function Format-BrokerBrief($Brief) {
    $now = [long]$Brief.atMs
    $lines = New-Object System.Collections.ArrayList
    $session = if ($Brief.sessionId) { "session $($Brief.sessionId) (owner $($Brief.sessionOwner))" } else { 'no session' }
    $editorText = if ($null -eq $Brief.editor) { 'Editor offline' } else { "Editor $($Brief.editor.phase)" + $(if ($Brief.editor.compileFailed) { ', COMPILE ERRORS' } else { '' }) }
    [void]$lines.Add("Brief for $($Brief.agent): $session, $editorText" + $(if ($Brief.paused) { ', broker PAUSED' } else { '' }) + '.')
    [void]$lines.Add("Team ($(@($Brief.team).Count)):")
    foreach ($m in @($Brief.team)) {
        $line = "  $($m.agent)" + $(if ($m.you) { ' [you]' } elseif ($m.role) { " [$($m.role)]" } else { '' })
        if (-not $m.you) { $line += $(if ($m.lastSeenMs -gt 0) { ' ' + (Format-BrokerAge ($now - $m.lastSeenMs)) + ' ago' } else { ' not seen' }) }
        if (-not $m.active) { $line += ' (quiet)' }
        if ($m.doing) { $line += ": $($m.doing)" }
        $leases = @($m.leases)
        if ($leases.Count -gt 0) { $line += ' | ' + (@($leases | Select-Object -First 3) -join ', ') + $(if ($leases.Count -gt 3) { " +$($leases.Count - 3)" } else { '' }) }
        if (@($m.jobs).Count -gt 0) { $line += ' | ' + (@($m.jobs) -join ', ') }
        [void]$lines.Add($line)
    }
    if ($null -ne $Brief.window) {
        $w = $Brief.window
        $waits = if (@($w.unyielded).Count -gt 0) { ', waits for ' + (@($w.unyielded) -join ', ') + ' to yield' } else { '' }
        [void]$lines.Add("Window: $($w.id) $($w.lane)/$($w.phase)" + $(if ($w.holder) { " for $($w.holder)" } else { '' }) + $waits + '.')
    }
    if (@($Brief.queue).Count -gt 0) {
        $source = if ($Brief.estimates -eq 'telemetry') { 'ETA from telemetry' } else { 'ETA from defaults, no telemetry yet' }
        [void]$lines.Add("Queue (start -> done, $source):")
        foreach ($q in @($Brief.queue)) {
            $slot = if ($q.order -eq 0) { 'now' } else { '#' + $q.order }
            $start = if ($q.status -eq 'running') { 'running' } elseif ($q.waitsForCold) { 'by ~' + (Format-BrokerAge ($q.startMs - $now)) } elseif ($q.startMs -le $now) { 'next' } else { '~' + (Format-BrokerAge ($q.startMs - $now)) }
            $why = if ($q.waitsForCold) { ', waits for cold work to go quiet' } else { '' }
            [void]$lines.Add("  $slot $($q.jobId) $($q.agent) $($q.label): $start -> ~$(Format-BrokerAge ($q.doneMs - $now))$why" + $(if ($q.mine) { ' <- yours' } else { '' }))
        }
    } else { [void]$lines.Add('Queue: empty.') }
    $mine = @()
    foreach ($w in @($Brief.mine.waiting)) { $mine += "waiting $($w.id) $($w.path) #$($w.position)" + $(if (@($w.behind).Count -gt 0) { ' behind ' + (@($w.behind) -join ', ') } else { '' }) }
    foreach ($l in @($Brief.mine.leases | Where-Object { $_.expiresInMs -lt 120000 })) { $mine += "$($l.path) expires in $(Format-BrokerAge $l.expiresInMs), renew" }
    if ($mine.Count -gt 0) { [void]$lines.Add('You: ' + ($mine -join '; ') + '.') }
    $b = $Brief.board
    [void]$lines.Add("Board: $($b.unreadTotal) new, $($b.othersNew) other, $($b.total) total (Library/UgaBroker/team-board.md).")
    if ($b.unreadTotal -gt @($b.unread).Count) { [void]$lines.Add("  ($($b.unreadTotal - @($b.unread).Count) older new in the file)") }
    foreach ($e in @($b.unread)) { [void]$lines.Add("  $($e.id) $($e.from)->$(@($e.to) -join ','): $(Get-BrokerClip $e.text $script:BrokerTeamConfig.messageLineChars)") }
    $next = @()
    if ($null -ne $Brief.window -and @($Brief.window.unyielded | Where-Object { Test-BrokerSameAgent $_ $Brief.agent }).Count -gt 0) { $next += "save and yield, $($Brief.window.id) waits for you" }
    if (@($Brief.queue | Where-Object { $_.mine }).Count -gt 0) { $next += 'keep working, your jobs run without you' }
    if ($b.unreadTotal -gt 0) { $next += 'reply with say -To <agent> if needed' }
    if ($next.Count -gt 0) { [void]$lines.Add('Next: ' + ($next -join '; ') + '.') }
    return ($lines -join "`n")
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
    if ($State.roster.Count -gt 0) {
        [void]$lines.Add('Team: ' + ((@($State.roster | Sort-Object { -[long]$_.lastSeenMs }) | ForEach-Object { "$($_.agent) (seen $(Format-BrokerAge ($now - $_.lastSeenMs)) ago)" }) -join ', ') + '. Each agent: brief -Agent <name>.')
    }
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
    if ($Json) {
        if ($null -ne $script:BrokerSeen) { $Result.unread = $script:BrokerUnread }
        Write-Output ($Result | ConvertTo-Json -Depth 10 -Compress); return
    }
    $parts = @($Result.status)
    if ($Result.leaseId) { $parts += $Result.leaseId }
    if ($Result.jobId) { $parts += $Result.jobId }
    if ($Result.position) { $parts += "position $($Result.position)" }
    Write-Output (($parts -join ' ') + ': ' + $Result.message)
    if ($Extra) { Write-Output $Extra }
    if ($null -ne $script:BrokerSeen -and $script:BrokerUnread -gt 0) { Write-Output "Team board: $script:BrokerUnread new message(s) for you; run brief -Agent $($script:BrokerSeen.agent)." }
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
    $needsAgent = @('take','renew','release','yield','gate','stage','request','done','cancel','brief','say')
    if ($Command -in $needsAgent -and -not (Test-BrokerAgent $Agent)) { Stop-Broker 'Pass -Agent <name> (letters, digits, ., _ or -; at most 48).' 2 }
    if ($Command -in $needsAgent) { $script:BrokerSeen = @{ agent = $Agent; command = $Command; role = $Role; doing = $Doing } }
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
        'stats' {
            $state = Invoke-BrokerUpdate $project { param($s, $ctx) }
            $stats = Get-BrokerStats $project $state $now
            if ($Json) { Write-Output ($stats | ConvertTo-Json -Depth 8 -Compress) } else { Write-Output (Format-BrokerStats $stats) }
        }
        'brief' {
            $editor = Read-BrokerEditor $project
            $history = Get-BrokerTelemetryHistory $project
            [void](Invoke-BrokerUpdate $project { param($s, $ctx)
                [void](Invoke-BrokerPromote $s $now)
                $script:BrokerBrief = Get-BrokerBrief $project $s $editor $Agent $now $history $Role $Doing
                $ctx.save = $true })
            if ($Json) { Write-Output ($script:BrokerBrief | ConvertTo-Json -Depth 8 -Compress) } else { Write-Output (Format-BrokerBrief $script:BrokerBrief) }
        }
        'say' {
            $text = ConvertTo-BrokerBoardText $Message
            if ([string]::IsNullOrWhiteSpace($text)) { Stop-Broker 'say needs -Message "<text>".' 2 }
            if ($text.Length -gt $script:BrokerTeamConfig.maxMessageChars) { Stop-Broker "Message is longer than $($script:BrokerTeamConfig.maxMessageChars) characters: keep it to one short note and link a file for details." 2 }
            $recipients = @(@($To) | ForEach-Object { if ($_) { $_.Split(@(',', ';'), [StringSplitOptions]::RemoveEmptyEntries) } } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            if ($recipients.Count -eq 0 -or @($recipients | Where-Object { $_ -ieq 'all' }).Count -gt 0) { $recipients = @('all') }
            foreach ($r in $recipients) { if ($r -ne 'all' -and -not (Test-BrokerAgent $r)) { Stop-Broker "Invalid recipient '$r': use agent names or all." 2 } }
            [void](Invoke-BrokerUpdate $project { param($s, $ctx)
                $script:BrokerSaid = Add-BrokerBoardMessage $project $s $Agent $recipients $text $now
                $ctx.save = $true })
            $file = Get-BrokerBoardFile $project
            if ($Json) { Write-Output ([ordered]@{ status = 'posted'; id = $script:BrokerSaid; to = $recipients; path = $file; unread = $script:BrokerUnread } | ConvertTo-Json -Compress) }
            else {
                Write-Output "posted $($script:BrokerSaid) to $($recipients -join ', '): $file"
                if ($script:BrokerUnread -gt 0) { Write-Output "Team board: $script:BrokerUnread new message(s) for you; run brief -Agent $Agent." }
            }
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
            $history = Get-BrokerTelemetryHistory $project
            $segments = @($history) + @($state.telemetry) | Where-Object { $null -ne $_ }
            $forecast = Get-BrokerForecast $state (Get-BrokerLaneAverages (Get-BrokerLaneTotals $segments)) $now
            $eta = @($forecast | Where-Object { $_.jobId -eq $result.jobId }) | Select-Object -First 1
            $etaText = ''
            if ($null -ne $eta) {
                $result.startMs = $eta.startMs; $result.doneMs = $eta.doneMs
                $slot = if ($eta.order -eq 0) { 'the current window' } else { "window #$($eta.order) of the queue" }
                $when = if ($eta.waitsForCold) { "starts by ~$(Format-BrokerAge ($eta.startMs - $now)) (hot work waits until cold work goes quiet)" } else { "starts in ~$(Format-BrokerAge ($eta.startMs - $now))" }
                $etaText = "ETA (rough): $slot, $when, done in ~$(Format-BrokerAge ($eta.doneMs - $now)). Keep working meanwhile; brief shows the whole queue."
            }
            Write-BrokerResult $result $etaText
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
