#requires -Version 5.1
param([string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$ErrorActionPreference = 'Stop'

function Assert-WorkspaceTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Assert-WorkspaceRefusal([scriptblock]$Action, [string]$Pattern) {
    $caught = $false
    try { & $Action | Out-Null } catch {
        if ($_.Exception.Message -notlike $Pattern) { throw "Wrong refusal: $_ (wanted $Pattern)" }
        $caught = $true
    }
    Assert-WorkspaceTest $caught "Expected refusal: $Pattern"
}

. (Join-Path $SkillRoot 'tools/unity-workspace.ps1')
$script:RealEditorProcessFinder = ${function:Get-UgaEditorProcesses}

# All machine-dependent calls are replaced. No real Unity is launched by this suite.
function Get-UgaMemory { return [pscustomobject]@{ PhysicalGB=16; CommitGB=24 } }
$script:FixtureFreeBytes = 1TB
$script:FixtureEditorPath = $null
$script:FixtureUnityProcesses = @()
$script:FixtureLifecycleEnabled = $false
function Get-Process([int]$Id) {
    if ($script:FixtureLifecycleEnabled -and $Id -in @(401,402,403)) {
        if ($Id -ne 401) { throw "finish tried to close a worker or foreign Editor: $Id" }
        return $script:FixtureMainProcess
    }
    return Microsoft.PowerShell.Management\Get-Process -Id $Id
}
function Get-UgaVolume([string]$Path) { return [pscustomobject]@{ FileSystemType='NTFS'; SizeRemaining=$script:FixtureFreeBytes; UniqueId='fixture-volume' } }
function Get-UgaEditorProcesses([string]$Path) { if ($Path -eq $script:FixtureEditorPath) { return [pscustomobject]@{ ProcessId=12345 } }; return & $script:RealEditorProcessFinder $Path }
function Get-CimInstance([string]$ClassName, [string]$Filter) { if ($ClassName -eq 'Win32_Process') { return $script:FixtureUnityProcesses }; return [pscustomobject]@{ BuildNumber=26100 } }
function Get-UgaVolumeLockRoot { return Join-Path $fixtureRoot 'volume-locks' }
function Start-UgaUnity { throw 'TEST GUARD: launching Unity is forbidden.' }

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('uga-workspace-test-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $fixtureRoot 'Canonical Project'
$workspaces = $fixture + '.ws'
$clone = Join-Path $workspaces 'shared-tests'
$testChildren = @()

function Wait-FixtureSignal([string]$Path) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $Path)) {
        if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out waiting for fixture signal: $Path" }
        Start-Sleep -Milliseconds 50
    }
}

function Invoke-FixtureWorkspace([string]$Action, [string]$Task = 'feature-one', [switch]$Delete, [switch]$Explicit, [string]$ChosenBase) {
    $Command=$Action; $Name=$Task; $ProjectRoot=$fixture; $Root=$null; $Base=$ChosenBase
    $NoLibrary=[switch]$true; $Remove=$Delete; $Confirm=$Explicit
    Invoke-UgaWorkspace
}

try {
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    # Native parser: quoted option names, slash normalization, escaped quotes,
    # empty arguments and trailing backslashes roundtrip through the real Win32 API.
    $quotedEditor = '"C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe" "-projectPath" "D:/Git/RedoSchool/"'
    # Complete Win32_Process command line observed for worker PID 40024, parent
    # 8724 (2026-10-15). Keep both -name options and all other arguments intact.
    $realWorkerLine = '"C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe" "-adb2" "-batchMode" "-noUpm" "-name" "AssetImportWorkerHW1" "-projectPath" "D:/Git/RedoSchool" "-logFile" "Logs/AssetImportWorkerHW1.log" "-srvPort" "6361" "-parentPid" "8724" "-analyticsCloudUserId" "anonymous" "-analyticsLocalProjectId" "927bdb6a2bfa4174f9edac1c7b40b838" "-editorAnalyticsEnabled" "1" "-cbmEditorLicense" "e4dcf0e7a7ce68ec387d068ba85b42018998e551" "-cbmMachineId" "QMjs+86VhRLYASdclE5vz9y0fm0=" "-noDiagnosticSwitchPersistentStore" "-job-worker-count" "7" "-background-job-worker-count" "8" "-asset-garbage-collectors" "1" "-force-d3d12" "-name" "AssetImport"'
    $workerTokens = @(Split-UgaCommandLine $realWorkerLine)
    $workerNames = @(Get-UgaOption $workerTokens '-name' -Multiple)
    Assert-WorkspaceTest ($workerNames.Count -eq 2 -and $workerNames[0] -eq 'AssetImportWorkerHW1' -and $workerNames[1] -eq 'AssetImport') 'Repeated worker names were not preserved.'
    Assert-WorkspaceTest ((Get-UgaProcessProject $quotedEditor) -eq 'D:\Git\RedoSchool') 'Quoted -projectPath was missed.'
    Assert-WorkspaceTest ((Get-UgaProcessProject 'Unity.exe -projectPath "D:\Git\Space Project"') -eq 'D:\Git\Space Project') 'Unquoted option compatibility failed.'
    $roundtrip = @('Unity.exe','-projectPath','D:\Git\Space Project\','empty follows','','literal"quote','slash\\"quote')
    $parsed = @(Split-UgaCommandLine (($roundtrip | ForEach-Object { ConvertTo-UgaNativeArgument $_ }) -join ' '))
    Assert-WorkspaceTest ($parsed.Count -eq $roundtrip.Count) 'Native token count mismatch.'
    for ($index=0; $index -lt $roundtrip.Count; $index++) { Assert-WorkspaceTest ($parsed[$index] -ceq $roundtrip[$index]) "Native argument roundtrip failed at $index." }
    Assert-WorkspaceRefusal { Get-UgaProcessProject 'Unity.exe "-projectPath" "D:\a" "-projectPath" "D:\b"' } '*Ambiguous*'
    Assert-WorkspaceRefusal { Get-UgaProcessProject 'Unity.exe "-projectPath"' } '*missing*'
    $parentEditor = [pscustomobject]@{ ProcessId=100; ParentProcessId=1; CommandLine=$quotedEditor; WorkingSetSize=5GB; PageFileUsage=5GB/1KB }
    $realWorker = [pscustomobject]@{ ProcessId=101; ParentProcessId=100; CommandLine=$realWorkerLine; WorkingSetSize=512MB; PageFileUsage=512MB/1KB }
    $otherWorker = [pscustomobject]@{ ProcessId=102; ParentProcessId=100; CommandLine=$realWorkerLine.Replace('RedoSchool','RedoSchool-other'); WorkingSetSize=512MB; PageFileUsage=512MB/1KB }
    $script:FixtureUnityProcesses = @($parentEditor,$realWorker,$otherWorker)
    $matching = @(Get-UgaEditorProcesses 'D:\Git\RedoSchool')
    Assert-WorkspaceTest ($matching.Count -eq 2 -and $matching.ProcessId -contains 100 -and $matching.ProcessId -contains 101) 'Quoted process routing missed the parent/worker or included a prefix neighbor.'
    Assert-WorkspaceTest (Test-UgaImportWorker $realWorkerLine $realWorker $script:FixtureUnityProcesses) 'Real Unity 6 worker signature missed.'
    Assert-WorkspaceTest (-not (Test-UgaImportWorker $otherWorker.CommandLine $otherWorker $script:FixtureUnityProcesses)) 'Foreign-project parent relationship accepted.'
    Assert-WorkspaceTest (Test-UgaImportWorker $realWorkerLine $realWorker @()) 'Orphan worker signature missed.'
    $reorderedWorker = $realWorkerLine.Replace('"-name" "AssetImportWorkerHW1"','"-name" "AssetImport"').Replace('"-force-d3d12" "-name" "AssetImport"','"-force-d3d12" "-name" "AssetImportWorkerHW1"')
    Assert-WorkspaceTest (Test-UgaImportWorker $reorderedWorker) 'Worker name matching depends on option order.'
    Assert-WorkspaceTest (-not (Test-UgaImportWorker $realWorkerLine.Replace('AssetImportWorkerHW1','AssetImport'))) 'Repeated non-worker names were classified as an import worker.'
    Assert-WorkspaceRefusal { Test-UgaImportWorker ($realWorkerLine + ' "-projectPath" "D:/Git/Other"') } '*Ambiguous*projectPath*'
    Assert-WorkspaceTest (-not (Test-UgaImportWorker 'Unity.exe "-batchMode" "-projectPath" "D:/Git/RedoSchool"' $realWorker @($parentEditor))) 'A headless test child was classified as an import worker.'
    Assert-WorkspaceTest (-not (Test-UgaImportWorker 'Unity.exe -logFile "-assetImportWorker.log"')) 'A flag inside a value was classified as a worker.'
    $realAdjusted = Get-UgaLaunchMemory 9.8 20 5 @($parentEditor,$realWorker)
    Assert-WorkspaceTest ($realAdjusted.PhysicalGB -eq 9.8) 'Real workers incorrectly consumed Editor reservations.'
    Assert-UgaMemory $realAdjusted.PhysicalGB $realAdjusted.CommitGB 4 5
    $script:FixtureUnityProcesses = @()
    Assert-WorkspaceRefusal { Invoke-UgaLaunch 'fake-Unity.exe' @('-projectPath','D:\fake') } '*TEST GUARD*'

    # File-backed volume ownership: no stale marker or PID can break a live lock;
    # a crashed owner's abandoned metadata is recovered after the OS releases it.
    $heldVolume = Enter-UgaVolumeLock 'fixture-volume' -TimeoutSeconds 0
    try {
        Assert-WorkspaceRefusal { Enter-UgaVolumeLock 'FIXTURE-VOLUME' -TimeoutSeconds 0 } '*Timed out*volume admission lock*'
        $differentVolume = Enter-UgaVolumeLock 'another-volume' -TimeoutSeconds 0
        Exit-UgaVolumeLock $differentVolume
    } finally { $heldVolume.Dispose() } # Simulate crash: deliberately leave owner metadata.
    $recoveredVolume = Enter-UgaVolumeLock 'fixture-volume' -TimeoutSeconds 0
    Assert-WorkspaceTest ($recoveredVolume.Length -gt 0) 'Stale volume lock was not recovered.'
    Exit-UgaVolumeLock $recoveredVolume

    # Documentation contract regression: HTTP path verification must be a pinned
    # read, and unroutable resources require separate sessions (no live MCP claim).
    foreach ($doc in @('tools/mcp-provider-neutral.md','tools/parallel-editors.md','mcp-commands.md')) {
        $text = Get-Content -LiteralPath (Join-Path $SkillRoot $doc) -Raw -Encoding UTF8
        foreach ($required in @('HTTP','set_active_instance','read-only','Application.dataPath','separate sessions')) {
            Assert-WorkspaceTest ($text.Contains($required)) "$doc lost pinned HTTP project-path verification guidance: $required"
        }
    }
    foreach ($good in @('a','feature-one','test-02',('a'*48))) { Assert-UgaName $good }
    foreach ($bad in @('','../outside','A','a/b','a\b','-option','con','lpt1',('a'*49))) {
        Assert-WorkspaceRefusal { Assert-UgaName $bad } '*Name must*'
    }
    Assert-WorkspaceTest ((Get-UgaDiskBudget 10GB 2GB 2) -eq [long][math]::Ceiling(16.4GB)) 'Full-copy disk margin math is wrong.'
    Assert-WorkspaceTest ((Get-UgaDiskBudget 10GB 2GB 2 $true) -eq [long][math]::Ceiling(6.4GB)) 'Block-clone changed-block reserve is wrong.'
    Assert-UgaDisk 100 100
    Assert-WorkspaceRefusal { Assert-UgaDisk 101 100 } '*Insufficient disk*'
    Assert-UgaMemory 9 9 4 5
    Assert-WorkspaceRefusal { Assert-UgaMemory 8.9 40 4 5 } '*Refusing Editor launch*'
    Assert-WorkspaceRefusal { Assert-UgaMemory 40 8.9 4 5 } '*commit headroom*'
    $startingEditor = [pscustomobject]@{ WorkingSetSize=1GB; PageFileUsage=1GB/1KB }
    $adjusted = Get-UgaLaunchMemory 13 13 5 @($startingEditor)
    Assert-WorkspaceTest ($adjusted.PhysicalGB -eq 9 -and $adjusted.CommitGB -eq 9) 'Pending launch reservation is wrong.'
    Assert-UgaMemory $adjusted.PhysicalGB $adjusted.CommitGB 4 5
    $twoStarting = Get-UgaLaunchMemory 13 13 5 @($startingEditor,$startingEditor)
    Assert-WorkspaceRefusal { Assert-UgaMemory $twoStarting.PhysicalGB $twoStarting.CommitGB 4 5 } '*Refusing Editor launch*'
    $worker = [pscustomobject]@{ CommandLine='Unity.exe -assetImportWorker -projectPath C:\fixture'; WorkingSetSize=1GB; PageFileUsage=1GB/1KB }
    $workerAdjusted = Get-UgaLaunchMemory 13 13 5 @($worker)
    Assert-WorkspaceTest ($workerAdjusted.PhysicalGB -eq 13 -and $workerAdjusted.CommitGB -eq 13) 'Import worker was budgeted as a full new Editor.'
    Assert-WorkspaceTest (Test-UgaBlockClone 'ReFS' 'same' 'same' 26100) 'Eligible ReFS rejected.'
    Assert-WorkspaceTest (-not (Test-UgaBlockClone 'ReFS' 'a' 'b' 26100)) 'Cross-volume clone accepted.'
    Assert-WorkspaceTest (-not (Test-UgaBlockClone 'NTFS' 'same' 'same' 26100)) 'NTFS clone accepted.'
    Assert-WorkspaceTest (-not (Test-UgaBlockClone 'ReFS' 'same' 'same' 22631)) 'Unsupported OS clone accepted.'
    Assert-WorkspaceTest ((Get-UgaFullPath 'C:\') -eq 'C:\') 'Drive root became a drive-relative path.'
    Assert-WorkspaceTest ((ConvertTo-UgaNativeArgument 'path with space\') -eq '"path with space\\"') 'Native trailing-backslash quoting is wrong.'

    foreach ($folder in @('Assets','Packages','ProjectSettings')) { New-Item -ItemType Directory -Path (Join-Path $fixture $folder) -Force | Out-Null }
    Set-Content -LiteralPath (Join-Path $fixture 'Assets/owned.txt') -Value 'committed source' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'Packages/manifest.json') -Value '{"dependencies":{}}' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'ProjectSettings/ProjectVersion.txt') -Value 'm_EditorVersion: 6000.0.1f1' -Encoding ASCII
    Invoke-UgaGit $fixture @('init','-b','main') | Out-Null
    Invoke-UgaGit $fixture @('config','user.name','Workspace Fixture') | Out-Null
    Invoke-UgaGit $fixture @('config','user.email','workspace-fixture@example.invalid') | Out-Null
    Invoke-UgaGit $fixture @('add','Assets','Packages','ProjectSettings') | Out-Null
    $tree = Invoke-UgaGit $fixture @('write-tree')
    # Fixture history only, via plumbing; never invokes git commit/push.
    $revision = Invoke-UgaGit $fixture @('commit-tree',$tree,'-m','fixture base')
    Invoke-UgaGit $fixture @('update-ref','refs/heads/main',$revision) | Out-Null
    $canonicalHash = (Get-FileHash -LiteralPath (Join-Path $fixture 'Assets/owned.txt')).Hash
    $editor = Get-UgaEditor $fixture $null
    Assert-WorkspaceTest ($editor.Version -eq '6000.0.1f1') 'Unity version discovery failed.'
    New-Item -ItemType Directory -Path (Join-Path $fixture 'Library/Temp') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture 'Library/cache') -Value 'cache' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'Library/Temp/lock') -Value 'lock' -Encoding ASCII
    Set-Content -LiteralPath (Join-Path $fixture 'Assets/uncommitted.txt') -Value 'invisible' -Encoding ASCII

    # Two real PowerShell creators, different workspace roots, one simulated
    # target volume. First holds the lock through its copy and consumes the free
    # budget; second must wait, remeasure, then refuse without a checkout.
    $creatorScript = Join-Path $fixtureRoot 'concurrent-creator.ps1'
    Set-Content -LiteralPath $creatorScript -Encoding UTF8 -Value @'
param($WorkspaceScript,$FixtureProject,$TaskName,$TestRoot,$TestFree,$TestLocks,$Attempt,$Ready,$Release,$Outcome)
. $WorkspaceScript
$script:RealVolumeEnter = ${function:Enter-UgaVolumeLock}
function Get-UgaVolumeLockRoot { return $TestLocks }
function Enter-UgaVolumeLock([string]$VolumeId,[int]$TimeoutSeconds=30,[string]$LockRoot=$TestLocks) {
    [IO.File]::WriteAllText($Attempt,'attempt')
    return & $script:RealVolumeEnter $VolumeId $TimeoutSeconds $LockRoot
}
function Get-UgaVolume([string]$Path) { return [pscustomobject]@{ FileSystemType='NTFS'; SizeRemaining=[long][IO.File]::ReadAllText($TestFree); UniqueId='concurrent-volume' } }
function Get-CimInstance { return [pscustomobject]@{ BuildNumber=26100 } }
function Get-UgaEditorProcesses { return @() }
function Copy-UgaLibrary {
    [IO.File]::WriteAllText($Ready,'copy entered under lock')
    $deadline=[DateTime]::UtcNow.AddSeconds(40)
    while (-not (Test-Path -LiteralPath $Release)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Creator fixture release timed out.' }
        Start-Sleep -Milliseconds 50
    }
    [IO.File]::WriteAllText($TestFree,'0')
}
$Command='new'; $ProjectRoot=$FixtureProject; $Name=$TaskName; $Root=$TestRoot; $NoLibrary=[switch]$true
try { Invoke-UgaWorkspace | Out-Null; [IO.File]::WriteAllText($Outcome,'success'); exit 0 }
catch { [IO.File]::WriteAllText($Outcome,$_.Exception.Message); exit 1 }
'@
    $freeFile = Join-Path $fixtureRoot 'concurrent-free.txt'
    [IO.File]::WriteAllText($freeFile,[string](3GB))
    $firstRoot = Join-Path $fixtureRoot 'first-root'; $secondRoot = Join-Path $fixtureRoot 'second-root'
    $release = Join-Path $fixtureRoot 'release-copy'
    $childParameters = @()
    foreach ($number in @(1,2)) {
        $attempt = Join-Path $fixtureRoot "attempt-$number"; $ready = Join-Path $fixtureRoot "ready-$number"; $outcome = Join-Path $fixtureRoot "outcome-$number"
        $testRoot = $firstRoot; if ($number -eq 2) { $testRoot = $secondRoot }
        $nativeArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$creatorScript,(Join-Path $SkillRoot 'tools/unity-workspace.ps1'),$fixture,"concurrent-$number",$testRoot,$freeFile,(Get-UgaVolumeLockRoot),$attempt,$ready,$release,$outcome)
        $child = Start-Process -FilePath (Get-Command powershell.exe).Source -ArgumentList (($nativeArgs | ForEach-Object { ConvertTo-UgaNativeArgument $_ }) -join ' ') -WindowStyle Hidden -PassThru
        $null=$child.Handle; $testChildren += $child
        Wait-FixtureSignal $attempt
        if ($number -eq 1) { Wait-FixtureSignal $ready }
    }
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $secondRoot 'concurrent-2'))) 'Second creator checked out while the first copy held the volume lock.'
    [IO.File]::WriteAllText($release,'release')
    foreach ($child in $testChildren) { if (-not $child.WaitForExit(30000)) { throw 'Concurrent creator did not exit.' } }
    Assert-WorkspaceTest ($testChildren[0].ExitCode -eq 0) ('First creator failed: ' + [IO.File]::ReadAllText((Join-Path $fixtureRoot 'outcome-1')))
    Assert-WorkspaceTest ($testChildren[1].ExitCode -eq 1 -and [IO.File]::ReadAllText((Join-Path $fixtureRoot 'outcome-2')) -like '*Insufficient disk*') 'Second creator did not remeasure disk after serialization.'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $secondRoot 'concurrent-2'))) 'Low disk concurrent creator left a checkout.'
    Invoke-FixtureWorkspace 'new' | Out-Null
    $ws = Join-Path $workspaces 'feature-one'
    $manifest = Get-UgaManifest $ws 'feature-one' $fixture
    Assert-WorkspaceTest ($manifest.kind -eq 'worktree' -and $manifest.branch -eq 'agent/feature-one' -and $manifest.baseCommit -eq $revision -and $manifest.base -eq 'main') 'Manifest/history mismatch.'
    Assert-WorkspaceTest ($manifest.instanceName -eq 'feature-one' -and [DateTime]::Parse($manifest.created).Kind -eq 'Local') 'Manifest timestamp or instance name invalid.'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Assets/uncommitted.txt'))) 'Worktree contains canonical uncommitted sources.'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Library'))) '-NoLibrary did not skip the cache.'
    Assert-WorkspaceTest (-not (Get-UgaDirty $ws)) 'Manifest must not count as source dirtiness.'
    # Worker-first and parent-first snapshots both close only the matching main
    # Editor. No real processes are touched; the foreign Editor must survive.
    $fixtureParent = [pscustomobject]@{ ProcessId=401; ParentProcessId=1; CommandLine=('Unity.exe "-projectPath" ' + (ConvertTo-UgaNativeArgument $ws)) }
    $fixtureWorker = [pscustomobject]@{ ProcessId=402; ParentProcessId=401; CommandLine=$realWorkerLine.Replace('D:/Git/RedoSchool',$ws) }
    $foreignEditor = [pscustomobject]@{ ProcessId=403; ParentProcessId=1; CommandLine=$quotedEditor }
    $script:FixtureMainProcess = New-Object PSObject
    $script:FixtureMainProcess | Add-Member ScriptMethod CloseMainWindow {
        $script:FixtureClosedIds += 401
        $script:FixtureUnityProcesses = @($script:FixtureUnityProcesses | Where-Object { $_.ProcessId -notin @(401,402) })
        return $true
    }
    $script:FixtureMainProcess | Add-Member ScriptMethod WaitForExit { param($Timeout); return $true }
    $script:FixtureLifecycleEnabled = $true
    try {
        foreach ($workerFirst in @($true,$false)) {
            $script:FixtureClosedIds = @()
            $script:FixtureUnityProcesses = @($fixtureParent,$fixtureWorker,$foreignEditor)
            if ($workerFirst) { $script:FixtureUnityProcesses = @($fixtureWorker,$foreignEditor,$fixtureParent) }
            $statusRow = @(Invoke-FixtureWorkspace 'status' | Where-Object { $_.Name -eq 'feature-one' })
            Assert-WorkspaceTest ($statusRow.Count -eq 1 -and $statusRow[0].EditorRunning) 'status missed a quoted running workspace Editor.'
            Invoke-FixtureWorkspace 'finish' -Explicit | Out-Null
            Assert-WorkspaceTest ($script:FixtureClosedIds.Count -eq 1 -and $script:FixtureClosedIds[0] -eq 401) 'finish did not close exactly its main Editor.'
            Assert-WorkspaceTest ($script:FixtureUnityProcesses.Count -eq 1 -and $script:FixtureUnityProcesses[0].ProcessId -eq 403) 'finish touched a foreign Editor.'
        }
    } finally { $script:FixtureLifecycleEnabled = $false; $script:FixtureUnityProcesses = @() }
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'new' } '*already exists*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'new' '../bad' } '*Name must*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'new' 'bad-base' -ChosenBase 'no-such-ref' } '*git rev-parse*failed*'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $workspaces 'bad-base'))) 'Invalid base created a workspace.'
    $script:FixtureFreeBytes = 0
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'new' 'disk-refusal' } '*Insufficient disk*'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $workspaces 'disk-refusal'))) 'Low disk created a workspace.'
    $script:FixtureFreeBytes = 1TB
    $script:FixtureEditorPath = $ws
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'open' } '*Editor is running*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'test' } '*Editor is running*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'finish' } '*explicit -Confirm*'
    $script:FixtureEditorPath = $null

    Set-Content -LiteralPath (Join-Path $ws 'Assets/owned.txt') -Value 'uncommitted workspace changes' -Encoding ASCII
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'finish' -Delete -Explicit } '*dirty*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'sync' } '*dirty*'
    Invoke-UgaGit $ws @('restore','Assets/owned.txt') | Out-Null
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'finish' -Delete } '*explicit -Confirm*'
    New-Item -ItemType Directory -Path (Join-Path $ws 'Temp') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $ws 'Temp/UnityLockfile') -Value 'stale' -Encoding ASCII
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'test' } '*Unity lock exists*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'sync' } '*Unity lock exists*'
    Remove-Item -LiteralPath (Join-Path $ws 'Temp/UnityLockfile')
    Invoke-FixtureWorkspace 'finish' | Out-Null
    Assert-WorkspaceTest (Test-Path -LiteralPath $ws) 'finish without Remove deleted a workspace.'
    # Cache copy integration (robocopy, not Unity); source remains closed by the mock.
    $canonicalEditorLine = 'Unity.exe "-projectPath" ' + (ConvertTo-UgaNativeArgument $fixture)
    $script:FixtureUnityProcesses = @([pscustomobject]@{ ProcessId=103; CommandLine=$canonicalEditorLine })
    Copy-UgaLibrary $fixture $ws $false | Out-Null
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Library'))) 'Quoted running canonical Editor was missed before Library copy.'
    $script:FixtureUnityProcesses = @()
    New-Item -ItemType Directory -Path (Join-Path $fixture 'Temp') -Force | Out-Null
    $canonicalLock = [IO.File]::Open((Join-Path $fixture 'Temp/UnityLockfile'),'Create','ReadWrite','None')
    try {
        Copy-UgaLibrary $fixture $ws $false | Out-Null
        Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Library'))) 'Held canonical Unity lock did not block Library copy.'
    } finally { $canonicalLock.Dispose() }
    # An unlocked old lock can be guarded read-only; canonical lock contents survive.
    $canonicalLockHash = (Get-FileHash -LiteralPath (Join-Path $fixture 'Temp/UnityLockfile')).Hash
    Copy-UgaLibrary $fixture $ws $false | Out-Null
    Assert-WorkspaceTest ((Get-FileHash -LiteralPath (Join-Path $fixture 'Temp/UnityLockfile')).Hash -eq $canonicalLockHash) 'Source lock check modified canonical files.'
    Remove-Item -LiteralPath (Join-Path $fixture 'Temp/UnityLockfile')
    Assert-WorkspaceTest (Test-Path -LiteralPath (Join-Path $ws 'Library/cache')) 'Library clone lost source content.'
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Library/Temp'))) 'Library clone copied Temp.'
    function robocopy { $global:LASTEXITCODE = 8 }
    try { Copy-UgaLibrary $fixture $ws $false | Out-Null }
    finally { Remove-Item -LiteralPath Function:\robocopy }
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath (Join-Path $ws 'Library'))) 'Failed cache was not moved aside for a fresh import.'
    Assert-WorkspaceTest (@(Get-ChildItem -LiteralPath $ws -Directory -Filter '.uga-failed-library-*').Count -eq 1) 'Failed cache was not preserved.'

    # Sync selected branch changes; no rebase and canonical source files stay unchanged.
    Set-Content -LiteralPath (Join-Path $fixture 'Assets/base-change.txt') -Value 'new base' -Encoding ASCII
    Invoke-UgaGit $fixture @('add','Assets/base-change.txt') | Out-Null
    $nextTree = Invoke-UgaGit $fixture @('write-tree')
    $nextRevision = Invoke-UgaGit $fixture @('commit-tree',$nextTree,'-p',$revision,'-m','fixture update')
    Invoke-UgaGit $fixture @('update-ref','refs/heads/main',$nextRevision) | Out-Null
    Invoke-FixtureWorkspace 'sync' | Out-Null
    Assert-WorkspaceTest (Test-Path -LiteralPath (Join-Path $ws 'Assets/base-change.txt')) 'sync did not merge base updates.'

    Invoke-FixtureWorkspace 'clone-tests' 'shared-tests' | Out-Null
    Assert-WorkspaceTest ((Get-UgaManifest $clone 'shared-tests' $fixture).kind -eq 'test-clone') 'Test clone marker missing.'
    foreach ($folder in @('Assets','Packages','ProjectSettings')) {
        Assert-WorkspaceTest ([bool]((Get-Item -LiteralPath (Join-Path $clone $folder)).Attributes -band [IO.FileAttributes]::ReparsePoint)) "Clone $folder is not a junction."
    }
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'finish' 'shared-tests' -Delete -Explicit } '*Test clone*forbidden*'
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'sync' 'shared-tests' } '*Test clone*forbidden*'
    Assert-WorkspaceRefusal { Assert-UgaPlainPath (Join-Path $clone 'Assets') } '*reparse point*'
    $assetsJunction = Join-Path $clone 'Assets'
    [IO.Directory]::Delete($assetsJunction)
    New-Item -ItemType Junction -Path $assetsJunction -Target (Join-Path $fixture 'Packages') | Out-Null
    Assert-WorkspaceRefusal { Get-UgaManifest $clone 'shared-tests' $fixture } '*junction target is foreign*'
    [IO.Directory]::Delete($assetsJunction)
    New-Item -ItemType Junction -Path $assetsJunction -Target (Join-Path $fixture 'Assets') | Out-Null
    $manifestFile = Join-Path $ws '.uga-workspace.json'
    $manifestText = Get-Content -LiteralPath $manifestFile -Raw -Encoding UTF8
    $foreign = $manifestText | ConvertFrom-Json; $foreign.canonical = 'C:\foreign'
    $foreign | ConvertTo-Json | Set-Content -LiteralPath $manifestFile -Encoding UTF8
    Assert-WorkspaceRefusal { Invoke-FixtureWorkspace 'finish' -Delete -Explicit } '*Foreign or invalid*'
    Set-Content -LiteralPath $manifestFile -Value $manifestText -Encoding UTF8

    # Make an unmerged committed branch: removal must retain it and its history.
    Invoke-UgaGit $ws @('add','Assets') | Out-Null
    $branchRevision = Invoke-UgaGit $ws @('commit-tree',$nextTree,'-p',$nextRevision,'-m','unmerged fixture branch')
    Invoke-UgaGit $ws @('update-ref','refs/heads/agent/feature-one',$branchRevision) | Out-Null
    Invoke-FixtureWorkspace 'finish' -Delete -Explicit | Out-Null
    Assert-WorkspaceTest (-not (Test-Path -LiteralPath $ws)) '-Remove -Confirm failed to remove workspace.'
    Assert-WorkspaceTest ((Invoke-UgaGit $fixture @('rev-parse','agent/feature-one')) -eq $branchRevision) 'finish removed unmerged branch history.'
    Assert-WorkspaceTest ((Get-FileHash -LiteralPath (Join-Path $fixture 'Assets/owned.txt')).Hash -eq $canonicalHash) 'Canonical source was modified.'

    $beforeLfsBytes = Get-UgaCheckoutBytes $fixture $nextRevision
    Set-Content -LiteralPath (Join-Path $fixture 'Assets/large.lfs-fixture') -Value "version https://git-lfs.github.com/spec/v1`noid sha256:$('0'*64)`nsize 10737418240" -Encoding ASCII
    Invoke-UgaGit $fixture @('add','Assets/large.lfs-fixture') | Out-Null
    $lfsTree = Invoke-UgaGit $fixture @('write-tree')
    $lfsRevision = Invoke-UgaGit $fixture @('commit-tree',$lfsTree,'-p',$nextRevision,'-m','LFS size fixture')
    Assert-WorkspaceTest ((Get-UgaCheckoutBytes $fixture $lfsRevision) -ge ($beforeLfsBytes + 10GB)) 'Disk estimate ignored LFS materialized payload.'

    $xml = Join-Path $fixtureRoot 'tests.xml'
    Set-Content -LiteralPath $xml -Value '<test-run result="Passed" total="3" passed="2" failed="0" skipped="1" />' -Encoding ASCII
    Assert-WorkspaceTest (Get-UgaTestResult $xml).Success 'Passed NUnit selection rejected.'
    Set-Content -LiteralPath $xml -Value '<test-run result="Failed" total="3" passed="2" failed="1" skipped="0" />' -Encoding ASCII
    Assert-WorkspaceTest (-not (Get-UgaTestResult $xml).Success) 'Failed NUnit selection accepted.'
    Set-Content -LiteralPath $xml -Value '<test-run result="Passed" total="0" passed="0" failed="0" skipped="0" />' -Encoding ASCII
    Assert-WorkspaceTest (-not (Get-UgaTestResult $xml).Success) 'Empty NUnit selection accepted.'
    Assert-WorkspaceRefusal { Get-UgaTestResult (Join-Path $fixtureRoot 'missing.xml') } '*no NUnit XML*'

    # Binding rejects unknown commands/platforms before any machine activity.
    $scriptPath = Join-Path $SkillRoot 'tools/unity-workspace.ps1'
    Assert-WorkspaceRefusal { & $scriptPath -Command 'destroy-everything' } '*ValidateSet*'
    Assert-WorkspaceRefusal { & $scriptPath -Command 'test' -Platform 'Invalid' } '*ValidateSet*'
    Write-Output 'Unity workspace tests passed (no real Unity launched).'
}
finally {
    foreach ($child in $testChildren) { if (-not $child.HasExited) { $child.Kill(); $child.WaitForExit() }; $child.Dispose() }
    $safeRoot = Get-UgaFullPath $fixtureRoot
    $tempBase = (Get-UgaFullPath ([IO.Path]::GetTempPath())).TrimEnd('\') + '\'
    if (-not $safeRoot.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $safeRoot) -notlike 'uga-workspace-test-*') { throw "Unsafe fixture cleanup path: $safeRoot" }
    # Unlink each known junction non-recursively before any recursive cleanup.
    foreach ($folder in @('Assets','Packages','ProjectSettings')) {
        $link = Join-Path $clone $folder
        if (Test-Path -LiteralPath $link) {
            if (-not $link.StartsWith($safeRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Junction cleanup escaped fixture.' }
            [IO.Directory]::Delete($link)
        }
    }
    if (Test-Path -LiteralPath $safeRoot) { $null = Get-UgaSize $safeRoot; Remove-Item -LiteralPath $safeRoot -Recurse -Force }
}
