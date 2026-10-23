#requires -Version 5.1
# Smoke and contract tests for tools/editor-broker.ps1. No Unity Editor is launched: the Editor side
# is simulated by writing state.json / editor.json the way the package does. The live Editor run is
# tools/test-editor-broker-unity.ps1.
param([string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$ErrorActionPreference = 'Stop'

$cli = Join-Path $SkillRoot 'tools/editor-broker.ps1'
$vectorsPath = Join-Path $SkillRoot 'unity-package/Tests/Editor/broker-vectors.json'
$packageRoot = Join-Path $SkillRoot 'unity-package'
$host_ = if ($PSVersionTable.PSEdition -eq 'Core') { (Get-Process -Id $PID).Path } else { 'powershell' }

function Assert-Broker([bool]$Condition, [string]$Message) { if (-not $Condition) { throw "ASSERT: $Message" } }

. $cli

# ------------------------------------------------------------------ shared vectors (same as C#)
$vectors = [IO.File]::ReadAllText($vectorsPath) | ConvertFrom-Json
$asmdefMap = @{}
foreach ($a in $vectors.asmdefs) { $asmdefMap[$a.name] = $a.path }
$resolver = { param($name) $asmdefMap[$name] }

foreach ($c in $vectors.paths) {
    $parsed = ConvertFrom-BrokerResource $c.resource $resolver
    Assert-Broker ($parsed.ok -eq [bool]$c.ok) "path vector $($c.resource): ok=$($parsed.ok) $($parsed.error)"
    if ($c.ok) {
        Assert-Broker ($parsed.type -ceq $c.type) "path vector $($c.resource) type $($parsed.type)"
        Assert-Broker ($parsed.path -ceq $c.path) "path vector $($c.resource) path $($parsed.path)"
    }
}
foreach ($c in $vectors.overlaps) {
    Assert-Broker ((Test-BrokerOverlap $c.a $c.b) -eq [bool]$c.overlap) "overlap $($c.a) / $($c.b)"
    Assert-Broker ((Test-BrokerOverlap $c.b $c.a) -eq [bool]$c.overlap) "overlap $($c.b) / $($c.a)"
}
foreach ($c in $vectors.covers) { Assert-Broker ((Test-BrokerCovers $c.lease $c.asset) -eq [bool]$c.covered) "covers $($c.lease) / $($c.asset)" }
foreach ($c in $vectors.filters) {
    $filter = ConvertFrom-BrokerTestSpec $c.spec
    Assert-Broker (-not $filter.error) "filter $($c.spec): $($filter.error)"
    Assert-Broker ((Test-BrokerTestMatch $filter $c.fullName $c.assembly @($c.categories)) -eq [bool]$c.match) "filter $($c.spec) on $($c.fullName)"
}

function Get-Key($Item) { return "$($Item.agent)|$($Item.kind)|$($Item.path)" }
foreach ($scenario in $vectors.scenarios) {
    $state = New-BrokerState $null
    $index = 0
    foreach ($step in $scenario.steps) {
        $index++
        $label = "$($scenario.name) step $index ($($step.op))"
        $now = [long]$step.at
        switch ($step.op) {
            'take' {
                $parsed = ConvertFrom-BrokerResource $step.resource $resolver
                $r = if ($parsed.ok) { Invoke-BrokerTake $state $step.agent $step.kind $step.resource $parsed.path ([int]$step.ttl) $now } else { New-BrokerResult 'error' $parsed.error }
                Assert-Broker ($r.status -eq $step.expect) "$label expected $($step.expect) got $($r.status): $($r.message)"
                if ($step.expect -eq 'queued') { Assert-Broker ($r.position -eq [int]$step.position) "$label position $($r.position)" }
            }
            'release' {
                $p = ''
                if ($step.resource) { $p = (ConvertFrom-BrokerResource $step.resource $resolver).path }
                $count = Invoke-BrokerRelease $state $step.agent $p
                Assert-Broker ($count -eq [int]$step.count) "$label count $count"
            }
            'renew' { $count = Invoke-BrokerRenew $state $step.agent ([int]$step.ttl) $now; Assert-Broker ($count -eq [int]$step.count) "$label count $count" }
            'yield' { $count = Invoke-BrokerYield $state $step.agent $now; Assert-Broker ($count -eq [int]$step.count) "$label count $count" }
            'gate' { $r = Invoke-BrokerGate $state $step.agent $now; Assert-Broker ($r.status -eq $step.expect) "$label got $($r.status)" }
            'promote' {
                $grantedList = Invoke-BrokerPromote $state $now
                $granted = @($grantedList | ForEach-Object { Get-Key $_ })
                Assert-Broker (($granted -join ';') -ceq (@($step.granted) -join ';')) "$label granted [$($granted -join ';')]"
            }
            'leases' {
                $actual = @($state.leases | ForEach-Object { Get-Key $_ } | Sort-Object -CaseSensitive)
                $expected = @($step.list | Sort-Object -CaseSensitive)
                Assert-Broker (($actual -join ';') -ceq ($expected -join ';')) "$label leases [$($actual -join ';')]"
            }
            'waiting' {
                $actual = @($state.waiting | ForEach-Object { Get-Key $_ })
                Assert-Broker (($actual -join ';') -ceq (@($step.list) -join ';')) "$label waiting [$($actual -join ';')]"
            }
            'window' { $state.window = ConvertTo-BrokerWindow ([pscustomobject]@{ id = 'W-test'; lane = $step.lane; phase = 'draining'; holder = [string]$step.holder }) }
            'endwindow' { $state.window = ConvertTo-BrokerWindow ([pscustomobject]@{}) }
            'yielded' {
                $mine = @($state.leases | Where-Object { Test-BrokerSameAgent $_.agent $step.agent })
                Assert-Broker ($mine.Count -gt 0) "$label agent has no lease"
                Assert-Broker (@($mine | Where-Object { $_.yielded -ne [bool]$step.value }).Count -eq 0) "$label yielded"
            }
            'request' {
                $requestPaths = @(([string]$step.paths).Split(';') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $r = Invoke-BrokerRequest $state $step.agent $step.lane $step.kind $requestPaths ([string]$step.tests) ([string]$step.mode) ([string]$step.scene) ([double]$step.minutes) ([string]$step.reason) $now
                Assert-Broker ($r.status -eq $step.expect) "$label expected $($step.expect) got $($r.status): $($r.message)"
            }
            'touch' { [void](Update-BrokerRoster $state $step.agent 'test' $now ([string]$step.role) ([string]$step.doing)) }
            'roster' {
                $actual = @($state.roster | ForEach-Object { "$($_.agent)|$($_.role)|$($_.doing)" })
                Assert-Broker (($actual -join ';') -ceq (@($step.list) -join ';')) "$label roster [$($actual -join ';')]"
            }
            default { throw "$label unknown op" }
        }
    }
}

foreach ($c in $vectors.forecasts) {
    $state = New-BrokerState ([pscustomobject]@{ jobs = $c.jobs; window = $c.window })
    $forecast = Get-BrokerForecast $state (Get-BrokerLaneAverages $c.lanes) ([long]$c.now)
    $actual = @($forecast | ForEach-Object { "$($_.jobId)|$($_.order)|$($_.startMs)|$($_.doneMs)" })
    Assert-Broker (($actual -join ';') -ceq (@($c.expect) -join ';')) "forecast $($c.name): [$($actual -join ';')]"
}
foreach ($c in $vectors.boards) {
    $entries = ConvertFrom-BrokerBoard $c.text
    $actual = @($entries | ForEach-Object { "$($_.id)|$($_.from)|$(@($_.to) -join ',')|$($_.text)" })
    Assert-Broker (($actual -join ';') -ceq (@($c.entries) -join ';')) "board $($c.name): [$($actual -join ';')]"
    $unread = @(Get-BrokerBoardUnread $entries ([long]$c.readId) $c.agent | ForEach-Object { $_.id })
    Assert-Broker (($unread -join ';') -ceq (@($c.unread) -join ';')) "board $($c.name) unread: [$($unread -join ';')]"
}
foreach ($c in $vectors.boardFormats) {
    $text = Format-BrokerBoardEntry ([long]$c.number) ([long]$c.now) $c.from @($c.to) $c.text
    Assert-Broker ($text -ceq $c.expect) "board format M$($c.number): [$text]"
}
Write-Output "vectors: $(@($vectors.paths).Count) paths, $(@($vectors.scenarios).Count) scenarios, $(@($vectors.filters).Count) filters, $(@($vectors.forecasts).Count) forecasts, $(@($vectors.boards).Count + @($vectors.boardFormats).Count) board cases passed"

# ------------------------------------------------------------------ package metadata
$metaGuids = @{}
foreach ($item in Get-ChildItem -LiteralPath $packageRoot -Recurse -Force) {
    if ($item.Name -like '*.meta') {
        $target = $item.FullName.Substring(0, $item.FullName.Length - 5)
        Assert-Broker (Test-Path -LiteralPath $target) "orphan meta: $($item.FullName)"
        $guid = (Get-Content -LiteralPath $item.FullName | Where-Object { $_ -match '^guid: ' }) -replace '^guid: ', ''
        Assert-Broker ($guid -match '^[0-9a-f]{32}$') "bad guid in $($item.FullName)"
        Assert-Broker (-not $metaGuids.ContainsKey($guid)) "duplicate guid $guid"
        $metaGuids[$guid] = $item.FullName
        continue
    }
    Assert-Broker (Test-Path -LiteralPath ($item.FullName + '.meta')) "missing .meta for $($item.FullName) (git installs need it)"
}
$packageJson = [IO.File]::ReadAllText((Join-Path $packageRoot 'package.json')) | ConvertFrom-Json
Assert-Broker ($packageJson.unity -eq '6000.0') 'package must declare Unity 6 (6000.0) as minimum'
Write-Output "package metadata: $($metaGuids.Count) meta files, unique GUIDs"

# ------------------------------------------------------------------ CLI processes on a fake project
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('uga-broker-cli-test-' + [guid]::NewGuid().ToString('N'))
$project = Join-Path $tempRoot 'Fake Project'
function New-FakeProject([string]$Root) {
    foreach ($dir in @('Assets/Game/Combat', 'ProjectSettings', 'Packages')) { New-Item -ItemType Directory -Path (Join-Path $Root $dir) -Force | Out-Null }
    [IO.File]::WriteAllText((Join-Path $Root 'ProjectSettings/ProjectVersion.txt'), "m_EditorVersion: 6000.6.0f1`n")
    [IO.File]::WriteAllText((Join-Path $Root 'Packages/manifest.json'), "{`n  `"dependencies`": {`n    `"com.unity.ugui`": `"2.0.0`",`n    `"com.unity.test-framework`": `"1.6.0`"`n  }`n}`n")
    [IO.File]::WriteAllText((Join-Path $Root 'Assets/Game/Combat/Game.Combat.asmdef'), '{ "name": "Game.Combat" }')
    [IO.File]::WriteAllText((Join-Path $Root 'Assets/Game/Combat/Sword.cs'), 'public sealed class Sword {}')
}

function Invoke-Cli([string[]]$CliArgs, [int]$Expect = 0, [string]$Root = $project) {
    # Windows PowerShell turns redirected native stderr into terminating errors under 'Stop'.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & $host_ -NoProfile -ExecutionPolicy Bypass -File $cli @CliArgs -ProjectRoot $Root 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $previous }
    $code = $LASTEXITCODE
    Assert-Broker ($code -eq $Expect) ("editor-broker " + ($CliArgs -join ' ') + " exited $code, expected $Expect`n" + ($output -join "`n"))
    return ($output -join "`n")
}

function Set-FakeState([scriptblock]$Mutate) { [void](Invoke-BrokerUpdate $project { param($s, $ctx) & $Mutate $s; $ctx.save = $true }) }

function Write-FakeEditor([hashtable]$Overrides = @{}) {
    $editor = [ordered]@{ schema = 1; pid = $PID; unityVersion = '6000.6.0f1'; packageVersion = [string]$packageJson.version; projectPath = $project
        heartbeatMs = (Get-BrokerNowMs); phase = 'idle'; isCompiling = $false; isUpdating = $false; isPlaying = $false; compileFailed = $false
        brokerPaused = $false; activeScene = ''; loadedScenes = @(); dirtyScenes = @(); sessionId = ''; projectSettingsApplied = ''
        settings = @(
            [ordered]@{ name = 'kAutoRefreshMode'; scope = 'session'; current = '1'; desired = '0'; ok = $true; note = '' },
            [ordered]@{ name = 'EnterPlayModeOptions'; scope = 'project'; current = 'DisableDomainReload'; desired = 'DisableDomainReload'; ok = $true; note = '' })
        adapters = @([ordered]@{ name = 'coplay-mcp'; present = $true; ok = $true; note = 'HTTP transport (many clients).' })
        lastError = '' }
    foreach ($key in $Overrides.Keys) { $editor[$key] = $Overrides[$key] }
    $dir = Get-BrokerDir $project
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'editor.json'), ($editor | ConvertTo-Json -Depth 10), $script:Utf8NoBom)
}

$previousMachineDir = $env:UGA_MACHINE_DIR
try {
    New-FakeProject $project
    $env:UGA_MACHINE_DIR = Join-Path $tempRoot 'machine'

    # several projects on one machine: the registry lists each broker; UGA_PROJECT_ROOT selects one.
    $registry = Join-Path $env:UGA_MACHINE_DIR 'brokers'
    New-Item -ItemType Directory -Path $registry -Force | Out-Null
    $nowMs = Get-BrokerNowMs
    [IO.File]::WriteAllText((Join-Path $registry 'a.json'), ([ordered]@{ projectPath = 'C:/Games/Alpha'; pid = $PID; unityVersion = '6000.6.0f1'; heartbeatMs = $nowMs; phase = 'idle'; sessionId = 'S1'; leases = 2; queuedJobs = 1; window = '' } | ConvertTo-Json))
    [IO.File]::WriteAllText((Join-Path $registry 'b.json'), ([ordered]@{ projectPath = 'C:/Games/Beta'; pid = $PID; unityVersion = '6000.3.14f1'; heartbeatMs = $nowMs - 3600000; phase = 'idle'; sessionId = ''; leases = 0; queuedJobs = 0; window = '' } | ConvertTo-Json))
    $projects = Invoke-Cli @('projects')
    Assert-Broker ($projects -like '*live  C:/Games/Alpha*session S1*2 lease(s)*') "projects should list the live broker:`n$projects"
    Assert-Broker ($projects -like '*stale*C:/Games/Beta*') "projects should mark the stale broker:`n$projects"
    # doctor names only other live brokers: not stale ones and not the project itself.
    [IO.File]::WriteAllText((Join-Path $registry 'self.json'), ([ordered]@{ projectPath = $project.Replace('\', '/'); pid = $PID; unityVersion = '6000.6.0f1'; heartbeatMs = $nowMs; phase = 'idle'; sessionId = ''; leases = 0; queuedJobs = 0; window = '' } | ConvertTo-Json))
    $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $doctorText = (& $host_ -NoProfile -ExecutionPolicy Bypass -File $cli doctor -ProjectRoot $project 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $ErrorActionPreference = $previous
    Assert-Broker ($doctorText -like '*1 other live broker(s) on this machine: C:/Games/Alpha.*') "doctor should name only the other live broker:`n$doctorText"
    Assert-Broker ($doctorText -notlike '*C:/Games/Beta*') "doctor must not list a stale broker:`n$doctorText"
    $env:UGA_PROJECT_ROOT = $project
    try {
        $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $viaEnv = & $host_ -NoProfile -ExecutionPolicy Bypass -File $cli status 2>&1 | ForEach-Object { "$_" }
        $ErrorActionPreference = $previous
        Assert-Broker ($LASTEXITCODE -eq 0 -and ($viaEnv -join "`n") -like '*Session:*') 'UGA_PROJECT_ROOT should select the project without -ProjectRoot'
    } finally { Remove-Item Env:UGA_PROJECT_ROOT -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $registry -Recurse -Force

    # telemetry: CLI updates carry the Editor's counters through, a lease granted after waiting
    # records how long it waited, and 'stats' turns counters and history into averages and peaks.
    $tNow = Get-BrokerNowMs
    [void](Invoke-BrokerUpdate $project { param($s, $ctx)
        $s.telemetry = [ordered]@{ sessionId = ''; sinceMs = $tNow - 600000; endedMs = 0; jobs = 4; failed = 1; blocked = 0; canceled = 0
            waitMs = 40000; waitMaxMs = 25000; runMs = 20000; windows = 2; windowMs = 30000; windowMaxMs = 20000; drainMs = 6000
            queueLevel = 0; queueSinceMs = $tNow - 300000; queueIntegral = 600000; queuePeak = 3
            waitersLevel = 0; waitersSinceMs = $tNow; waitersIntegral = 0; waitersPeak = 1
            leaseWaits = 1; leaseWaitMs = 7000; leaseWaitMaxMs = 7000
            agents = @([ordered]@{ agent = 'core'; jobs = 4; failed = 1; blocked = 0; waitMs = 40000; waitMaxMs = 25000; runMs = 20000; leaseWaits = 1; leaseWaitMs = 7000; leaseWaitMaxMs = 7000 })
            lanes = @([ordered]@{ lane = 'sync'; jobs = 4; waitMs = 40000; waitMaxMs = 25000; runMs = 20000; windows = 2; windowMs = 30000; drainMs = 6000 }) }
        $ctx.save = $true })
    [void](Invoke-Cli @('take', '-Agent', 'ta', '-Resource', 'folder:Assets/Tele/'))
    [void](Invoke-Cli @('take', '-Agent', 'tb', '-Resource', 'asset:Assets/Tele/x.asset') 3)
    [void](Invoke-Cli @('release', '-Agent', 'ta'))
    [void](Invoke-Cli @('take', '-Agent', 'tb', '-Resource', 'asset:Assets/Tele/x.asset'))
    $tState = Invoke-BrokerUpdate $project { param($s, $ctx) }
    Assert-Broker ([int]$tState.telemetry.jobs -eq 4) 'CLI updates must keep the Editor telemetry'
    $tb = @($tState.leases | Where-Object { $_.agent -eq 'tb' })[0]
    Assert-Broker ([long]$tb.waitedMs -gt 0) "a lease granted after waiting must record waitedMs (got $($tb.waitedMs))"
    $history = [ordered]@{ sessionId = 'S0'; sinceMs = $tNow - 7200000; endedMs = $tNow - 3600000; jobs = 6; waitMs = 60000; waitMaxMs = 40000
        windows = 3; drainMs = 9000; queueIntegral = 3600000; queueLevel = 0; queueSinceMs = $tNow - 3600000; queuePeak = 5; agents = @(); lanes = @() }
    [IO.File]::WriteAllText((Join-Path (Get-BrokerDir $project) 'telemetry.jsonl'), (($history | ConvertTo-Json -Compress) + "`n"), $script:Utf8NoBom)
    $statsText = Invoke-Cli @('stats')
    Assert-Broker ($statsText -like '*Jobs: 4 (1 failed*wait avg 10 s, max 25 s*') "stats text:`n$statsText"
    Assert-Broker ($statsText -like '*core*') "stats should list agents:`n$statsText"
    $stats = (Invoke-Cli @('stats', '-Json')) | ConvertFrom-Json
    Assert-Broker ($stats.current.avgWaitMs -eq 10000 -and $stats.current.queuePeak -eq 3) 'stats: current averages'
    # 600 s of queue-time over a 10-minute segment, plus the seconds this test took.
    Assert-Broker ([Math]::Abs($stats.current.avgQueue - 1.0) -lt 0.05) "stats: average queue should be about 1.0, got $($stats.current.avgQueue)"
    Assert-Broker ($stats.project.segments -eq 2 -and $stats.project.jobs -eq 10 -and $stats.project.queuePeak -eq 5) 'stats: project totals over history'
    [void](Invoke-Cli @('release', '-Agent', 'tb'))

    # team brief: the roster, the queue with an ETA from telemetry, and the team board with unread
    # counts. Posting goes through the lock; a brief marks the board as read for that agent.
    [void](Invoke-Cli @('take', '-Agent', 'core', '-Resource', 'folder:Assets/Team/', '-Role', 'developer', '-Doing', 'score model'))
    $said = Invoke-Cli @('say', '-Agent', 'core', '-Message', "Renamed Score.Add to AddPoints.`n# not a heading")
    Assert-Broker ($said -like 'posted M* to all*team-board.md*') "say output:`n$said"
    [void](Invoke-Cli @('say', '-Agent', 'qa', '-To', 'ui,core', '-Message', 'Tooltip overlaps at 1280x720.'))
    [void](Invoke-Cli @('say', '-Agent', 'qa', '-To', 'bad name', '-Message', 'x') 2)
    [void](Invoke-Cli @('say', '-Agent', 'qa', '-Message', ' ') 2)
    [void](Invoke-Cli @('say', '-Agent', 'qa', '-Message', ('x' * 301)) 2)
    $gateText = Invoke-Cli @('gate', '-Agent', 'ui')
    Assert-Broker ($gateText -like '*2 new message(s) for you*') "gate should point ui at the board:`n$gateText"
    $requestText = Invoke-Cli @('request', '-Agent', 'core', '-Lane', 'sync')
    Assert-Broker ($requestText -like '*ETA (rough): window #1 of the queue*') "request should print an ETA:`n$requestText"
    $requestJson = (Invoke-Cli @('request', '-Agent', 'ui', '-Lane', 'hot', '-Minutes', '2', '-Json')).Split("`n") | Where-Object { $_ -like '{*' } | Select-Object -First 1 | ConvertFrom-Json
    Assert-Broker ([long]$requestJson.doneMs -gt [long]$requestJson.startMs -and [int]$requestJson.unread -eq 2) "request -Json should carry the ETA and unread count: $($requestJson | ConvertTo-Json -Compress)"
    $briefText = Invoke-Cli @('brief', '-Agent', 'ui', '-Doing', 'upgrade screen')
    foreach ($want in @('*Team (5):*', '*core `[developer`]*score model | cold Assets/Team/*', '*Queue (start -> done, ETA from telemetry):*',
                        '*#1 J* core sync: ~*', '*<- yours*', '*Board: 2 new, 0 other, 2 total*', '*core->all: Renamed Score.Add to AddPoints. / \# not a heading*', '*qa->ui,core: Tooltip overlaps*')) {
        Assert-Broker ($briefText -like $want) "brief misses $want`n$briefText"
    }
    $briefAgain = (Invoke-Cli @('brief', '-Agent', 'ui', '-Json')) | ConvertFrom-Json
    Assert-Broker (@($briefAgain.board.unread).Count -eq 0 -and $briefAgain.board.total -eq 2) 'a second brief must find nothing new'
    Assert-Broker ((@($briefAgain.team | Where-Object { $_.agent -eq 'ui' })[0].doing) -eq 'upgrade screen') 'brief -Doing should reach the roster'
    Assert-Broker ($briefAgain.estimates -eq 'telemetry' -and @($briefAgain.queue).Count -eq 2) 'brief should forecast both queued jobs from telemetry'
    $coreBrief = (Invoke-Cli @('brief', '-Agent', 'core', '-Json')) | ConvertFrom-Json
    Assert-Broker (@($coreBrief.board.unread).Count -eq 1 -and $coreBrief.board.othersNew -eq 0) 'core gets the message to ui,core but not its own'
    $teamState = Invoke-BrokerUpdate $project { param($s, $ctx) }
    Assert-Broker (@($teamState.roster | Where-Object { $_.agent -eq 'qa' }).Count -eq 1) 'say should add the sender to the roster'
    Assert-Broker ((Invoke-Cli @('status')) -like '*Team: core (seen*') 'status should list the team'
    $boardFile = [IO.File]::ReadAllText((Join-Path (Get-BrokerDir $project) 'team-board.md'))
    Assert-Broker ($boardFile.StartsWith('# Team board') -and (ConvertFrom-BrokerBoard $boardFile).Count -eq 2) "board file:`n$boardFile"
    Set-FakeState { param($s) foreach ($j in $s.jobs) { if ($j.status -eq 'queued') { Complete-BrokerJob $j 'canceled' 'test' (Get-BrokerNowMs) } } }
    [void](Invoke-Cli @('release', '-Agent', 'core'))
    Remove-Item -LiteralPath (Join-Path (Get-BrokerDir $project) 'telemetry.jsonl')

    # install: embed is idempotent and leaves the manifest alone; git mode writes JSON without a BOM.
    $manifestBefore = [IO.File]::ReadAllText((Join-Path $project 'Packages/manifest.json'))
    [void](Invoke-Cli @('install'))
    Assert-Broker (Test-Path -LiteralPath (Join-Path $project 'Packages/com.neoxider.uga-editor-broker/package.json')) 'embedded package missing'
    $again = Invoke-Cli @('install')
    Assert-Broker ($again -like '*already embedded*') 'second install should be a no-op'
    Assert-Broker ([IO.File]::ReadAllText((Join-Path $project 'Packages/manifest.json')) -ceq $manifestBefore) 'embed must not touch manifest.json'
    $gitProject = Join-Path $tempRoot 'Git Project'
    New-FakeProject $gitProject
    [void](Invoke-Cli @('install', '-Mode', 'git', '-GitRef', 'v9.9.9') 0 $gitProject)
    $bytes = [IO.File]::ReadAllBytes((Join-Path $gitProject 'Packages/manifest.json'))
    Assert-Broker (-not ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB)) 'manifest.json must not start with a BOM (Unity rejects it)'
    $gitManifest = [IO.File]::ReadAllText((Join-Path $gitProject 'Packages/manifest.json')) | ConvertFrom-Json
    Assert-Broker ($gitManifest.dependencies.'com.unity.ugui' -eq '2.0.0') 'existing dependency lost'
    Assert-Broker ($gitManifest.dependencies.'com.neoxider.uga-editor-broker' -like '*unity-package#v9.9.9') 'git dependency missing'

    # leases through real processes, including asmdef resolution and exit codes.
    [void](Invoke-Cli @('take', '-Agent', 'coder', '-Resource', 'asmdef:Game.Combat'))
    $queued = Invoke-Cli @('take', '-Agent', 'art', '-Resource', 'asset:Assets/Game/Combat/Icon.png') 3
    Assert-Broker ($queued -like '*position 1*') 'second agent should queue'
    [void](Invoke-Cli @('take', '-Agent', 'art', '-Resource', 'asset:Assets/Game/Combat/Icon.png', '-Wait', '-TimeoutSec', '2') 6)
    [void](Invoke-Cli @('take', '-Agent', 'bad', '-Resource', 'asset:../x.png') 2)
    [void](Invoke-Cli @('take', '-Agent', 'bad name', '-Resource', 'asset:Assets/x.png') 2)
    $board = Invoke-Cli @('status')
    Assert-Broker ($board -like '*coder cold Assets/Game/Combat/*' -and $board -like '*Waiting (FIFO)*') "board missing lease or queue:`n$board"

    # staging stays inside the agent's lease.
    $staged = Invoke-Cli @('stage', '-Agent', 'coder', '-Path', 'Assets/Game/Combat/Sword.cs')
    $stagedFile = Join-Path (Get-BrokerDir $project) 'staging/coder/Assets/Game/Combat/Sword.cs'
    Assert-Broker ((Test-Path -LiteralPath $stagedFile) -and ([IO.File]::ReadAllText($stagedFile) -like '*class Sword*')) "stage did not copy the live file: $staged"
    [void](Invoke-Cli @('stage', '-Agent', 'coder', '-Path', 'Assets/Game/Combat/Shield.cs') 2)
    [void](Invoke-Cli @('stage', '-Agent', 'coder', '-Path', 'Assets/Game/Combat/Shield.cs', '-New'))
    [void](Invoke-Cli @('stage', '-Agent', 'coder', '-Path', 'Assets/Other/Hack.cs', '-New') 2)

    # requests, gate and wait outcomes (the Editor is simulated by editing state.json).
    [void](Invoke-Cli @('request', '-Agent', 'coder', '-Lane', 'sync', '-Paths', 'Assets/Other/Thing.png') 2)
    $syncText = Invoke-Cli @('request', '-Agent', 'coder', '-Lane', 'sync', '-Json')
    $syncJob = ($syncText.Split("`n") | Where-Object { $_ -like '{*' } | Select-Object -First 1 | ConvertFrom-Json).jobId
    Assert-Broker ($syncJob -like 'J*') "sync job id missing: $syncText"
    [void](Invoke-Cli @('request', '-Agent', 'qa', '-Lane', 'hot', '-Tests', 'group:([') 2)
    $hotText = Invoke-Cli @('request', '-Agent', 'qa', '-Lane', 'hot', '-Tests', 'category:Smoke', '-Json')
    $hotJob = ($hotText.Split("`n") | Where-Object { $_ -like '{*' } | Select-Object -First 1 | ConvertFrom-Json).jobId
    [void](Invoke-Cli @('wait', '-Job', $hotJob, '-TimeoutSec', '2') 6)
    [void](Invoke-Cli @('gate', '-Agent', 'coder'))
    Set-FakeState { param($s) $s.window = ConvertTo-BrokerWindow ([pscustomobject]@{ id = 'W99'; lane = 'sync'; phase = 'draining' }) }
    [void](Invoke-Cli @('gate', '-Agent', 'coder') 4)
    [void](Invoke-Cli @('gate', '-Agent', 'coder', '-Wait', '-TimeoutSec', '2') 6)
    Set-FakeState { param($s)
        $s.window = ConvertTo-BrokerWindow ([pscustomobject]@{})
        foreach ($j in $s.jobs) {
            if ($j.id -eq $syncJob) { Complete-BrokerJob $j 'passed' 'Applied 1 file(s).' (Get-BrokerNowMs) }
            if ($j.id -eq $hotJob) { Complete-BrokerJob $j 'failed' '1 of 3 PlayMode tests failed.' (Get-BrokerNowMs); [void]$j.details.Add('Game.Tests.Hit: expected 3') }
        }
    }
    [void](Invoke-Cli @('wait', '-Job', $syncJob))
    $failedText = Invoke-Cli @('wait', '-Job', $hotJob) 8
    Assert-Broker ($failedText -like '*expected 3*') 'failed job details missing'
    [void](Invoke-Cli @('cancel', '-Agent', 'qa', '-Job', $hotJob) 2)
    $exclusiveText = Invoke-Cli @('request', '-Agent', 'lead', '-Lane', 'exclusive', '-Reason', 'Install Input System', '-Json')
    $exclusiveJob = ($exclusiveText.Split("`n") | Where-Object { $_ -like '{*' } | Select-Object -First 1 | ConvertFrom-Json).jobId
    [void](Invoke-Cli @('cancel', '-Agent', 'coder', '-Job', $exclusiveJob) 2)
    [void](Invoke-Cli @('cancel', '-Agent', 'lead', '-Job', $exclusiveJob))
    Set-FakeState { param($s) foreach ($j in $s.jobs) { if ($j.id -eq $syncJob) { $j.status = 'blocked' } } }
    [void](Invoke-Cli @('wait', '-Job', $syncJob) 9)

    # session lifecycle refuses to drop live leases without -Force.
    [void](Invoke-Cli @('session', 'start', '-Agent', 'lead'))
    Assert-Broker ((Invoke-BrokerUpdate $project { param($s, $ctx) }).sessionId -like 'S*') 'session id missing'
    [void](Invoke-Cli @('session', 'stop') 2)
    [void](Invoke-Cli @('session', 'stop', '-Force'))

    # doctor: no heartbeat -> not ready; healthy simulated Editor -> ready; stdio transport -> not ready.
    $doctor = Invoke-Cli @('doctor') 9
    Assert-Broker ($doctor -like '*No live Editor heartbeat*') "doctor should flag a missing Editor:`n$doctor"
    Write-FakeEditor
    $doctor = Invoke-Cli @('doctor')
    Assert-Broker ($doctor -like '*READY*') "doctor should be ready:`n$doctor"
    Write-FakeEditor @{ adapters = @([ordered]@{ name = 'coplay-mcp'; present = $true; ok = $false; note = 'stdio transport: every new client disconnects the others.' }) }
    $doctor = Invoke-Cli @('doctor') 9
    Assert-Broker ($doctor -like '*stdio transport*') 'doctor should explain the stdio problem'
    Write-FakeEditor @{ settings = @([ordered]@{ name = 'EnterPlayModeOptions'; scope = 'project'; current = 'disabled'; desired = 'DisableDomainReload'; ok = $false; note = '' }) }
    [void](Invoke-Cli @('doctor') 9)
    $fixed = Invoke-Cli @('doctor', '-Fix') 0
    Assert-Broker ($fixed -like '*Requested project settings*') "doctor -Fix should request project settings:`n$fixed"
    Assert-Broker ((Invoke-BrokerUpdate $project { param($s, $ctx) }).projectSettingsRequest -like 'P*') 'project settings request missing'
    Write-FakeEditor @{ unityVersion = '2022.3.10f1' }
    $oldProject = Join-Path $tempRoot 'Old Project'
    New-FakeProject $oldProject
    [IO.File]::WriteAllText((Join-Path $oldProject 'ProjectSettings/ProjectVersion.txt'), "m_EditorVersion: 2022.3.10f1`n")
    $oldDoctor = Invoke-Cli @('doctor') 9 $oldProject
    Assert-Broker ($oldDoctor -like '*requires Unity 6*') 'doctor must require Unity 6'

    # a corrupt state file recovers from the backup and records it.
    [IO.File]::WriteAllText((Join-Path (Get-BrokerDir $project) 'state.json'), '{ broken')
    $recovered = Invoke-Cli @('status')
    Assert-Broker ($recovered -like '*state-recovered*') "recovery not reported:`n$recovered"

    # concurrency: eight processes race for one asset (exactly one wins), then hammer distinct assets.
    [void](Invoke-Cli @('release', '-Agent', 'coder'))
    [void](Invoke-Cli @('release', '-Agent', 'art'))
    $race = @(1..8 | ForEach-Object {
        $p = Start-Process -FilePath $host_ -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$cli`"", 'take', '-Agent', "racer$_", '-Resource', 'asset:Assets/Race/Prize.asset', '-ProjectRoot', "`"$project`"") -PassThru -WindowStyle Hidden
        [void]$p.Handle  # keep the handle so ExitCode is readable after exit
        $p
    })
    $race | Wait-Process -Timeout 120
    $codes = @($race | ForEach-Object { $_.ExitCode })
    Assert-Broker (@($codes | Where-Object { $_ -eq 0 }).Count -eq 1) "exactly one racer must win, codes: $($codes -join ',')"
    Assert-Broker (@($codes | Where-Object { $_ -eq 3 }).Count -eq 7) "seven racers must queue, codes: $($codes -join ',')"
    $afterRace = Invoke-BrokerUpdate $project { param($s, $ctx) }
    Assert-Broker ($afterRace.leases.Count -eq 1 -and $afterRace.waiting.Count -eq 7) 'race left an inconsistent state'
    foreach ($i in 1..8) { [void](Invoke-Cli @('release', '-Agent', "racer$i")) }

    $startRevision = (Invoke-BrokerUpdate $project { param($s, $ctx) }).revision
    $rounds = 4
    $workerScript = Join-Path $tempRoot 'stress-worker.ps1'
    [IO.File]::WriteAllText($workerScript, @'
param([string]$Cli, [string]$Project, [string]$Name, [int]$Rounds, [string]$Shell, [string]$Log)
$ErrorActionPreference = 'Continue'
foreach ($n in 1..$Rounds) {
    $out = & $Shell -NoProfile -ExecutionPolicy Bypass -File $Cli take -Agent $Name -Resource "asset:Assets/Stress/$Name.asset" -ProjectRoot $Project 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { Add-Content -LiteralPath $Log -Value "$Name take round ${n}: exit $LASTEXITCODE $($out -join ' | ')"; exit 11 }
    $out = & $Shell -NoProfile -ExecutionPolicy Bypass -File $Cli release -Agent $Name -ProjectRoot $Project 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) { Add-Content -LiteralPath $Log -Value "$Name release round ${n}: exit $LASTEXITCODE $($out -join ' | ')"; exit 12 }
}
exit 0
'@)
    $stressLog = Join-Path $tempRoot 'stress.log'
    $workers = @(1..8 | ForEach-Object {
        $p = Start-Process -FilePath $host_ -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$workerScript`"", '-Cli', "`"$cli`"", '-Project', "`"$project`"", '-Name', "worker$_", '-Rounds', $rounds, '-Shell', $host_, '-Log', "`"$stressLog`"") -PassThru -WindowStyle Hidden
        [void]$p.Handle
        $p
    })
    $workers | Wait-Process -Timeout 600
    $stressNotes = if (Test-Path -LiteralPath $stressLog) { "`n" + ((Get-Content -LiteralPath $stressLog) -join "`n") } else { '' }
    Assert-Broker (@($workers | Where-Object { $_.ExitCode -ne 0 }).Count -eq 0) ('stress worker failed: ' + (@($workers | ForEach-Object { $_.ExitCode }) -join ',') + $stressNotes)
    $final = Invoke-BrokerUpdate $project { param($s, $ctx) }
    $expectedRevision = $startRevision + 8 * $rounds * 2
    Assert-Broker ($final.revision -eq $expectedRevision) "lost updates: revision $($final.revision), expected $expectedRevision"
    Assert-Broker ($final.leases.Count -eq 0) 'stress left leases behind'
    Write-Output "concurrency: 1 of 8 racers won; $(8 * $rounds * 2) parallel updates, none lost"
    Write-Output 'editor-broker CLI tests passed'
}
finally {
    $env:UGA_MACHINE_DIR = $previousMachineDir
    $resolved = Resolve-Path -LiteralPath $tempRoot -ErrorAction SilentlyContinue
    if ($resolved -and (Split-Path -Leaf $resolved.Path).StartsWith('uga-broker-cli-test-')) { Remove-Item -LiteralPath $resolved.Path -Recurse -Force }
}
