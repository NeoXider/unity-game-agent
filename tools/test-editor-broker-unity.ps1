#requires -Version 5.1
<#
Live end-to-end test of the shared-editor broker with a real Unity 6 Editor (no MCP needed: the
broker is driven through tools/editor-broker.ps1 exactly as agents drive it).

It creates throwaway projects under -WorkRoot, runs every lane (cold leases, focus, sync with
compile-error attribution, hot test batching and Play Mode sessions, exclusive), checks that two
projects on one machine stay independent and share Editor preferences safely, and prints timings.
Editor preferences touched by a session are snapshotted first and restored at the end.

  powershell -File tools/test-editor-broker-unity.ps1 [-EditorPath <Unity.exe>] [-WithAdapters] [-KeepProjects]

-WithAdapters also installs CoplayDev MCP for Unity and the Unity Pipeline package and checks the
uga_broker command through the Unity CLI. Expect 10-20 minutes and about 6 GB of RAM per Editor.
#>
param(
    [string]$EditorPath,
    [string]$WorkRoot = (Join-Path ([IO.Path]::GetTempPath()) ('uga-broker-e2e-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch]$WithAdapters,
    [switch]$KeepProjects,
    [int]$StepTimeoutSec = 420
)
$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$cli = Join-Path $PSScriptRoot 'editor-broker.ps1'
. $cli

# ------------------------------------------------------------------ helpers
$script:Results = New-Object System.Collections.ArrayList
$script:Editors = @{}
$script:PrefSnapshot = $null

function Step([string]$Name, [scriptblock]$Body) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "== $Name" -ForegroundColor Cyan
    try {
        $note = & $Body
        [void]$script:Results.Add([ordered]@{ step = $Name; ok = $true; seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 1); note = ($note -join ' ') })
        Write-Host "   ok ($([Math]::Round($timer.Elapsed.TotalSeconds, 1)) s) $($note -join ' ')" -ForegroundColor Green
    } catch {
        [void]$script:Results.Add([ordered]@{ step = $Name; ok = $false; seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 1); note = $_.Exception.Message })
        Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Assert-E2E([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Invoke-E2ECli([string[]]$CliArgs, [int]$Expect = 0, [string]$Project = $script:ProjectA) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $cli @CliArgs -ProjectRoot $Project 2>&1 | ForEach-Object { "$_" } }
    finally { $ErrorActionPreference = $previous }
    $code = $LASTEXITCODE
    Assert-E2E ($code -eq $Expect) ("editor-broker " + ($CliArgs -join ' ') + " exited $code, expected $Expect`n" + ($output -join "`n"))
    return ($output -join "`n")
}

function Invoke-E2EJob([string[]]$CliArgs, [string]$Project = $script:ProjectA) {
    $text = Invoke-E2ECli ($CliArgs + '-Json') 0 $Project
    $line = $text.Split("`n") | Where-Object { $_.TrimStart().StartsWith('{') } | Select-Object -First 1
    return ($line | ConvertFrom-Json).jobId
}

function Wait-Until([scriptblock]$Condition, [string]$What, [int]$TimeoutSec = $StepTimeoutSec) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 500
    }
    throw "Timed out after $TimeoutSec s waiting for: $What"
}

function Get-State([string]$Project = $script:ProjectA) { return Invoke-BrokerUpdate $Project { param($s, $ctx) } }
function Get-Job([string]$Id, [string]$Project = $script:ProjectA) { return @((Get-State $Project).jobs | Where-Object { $_.id -eq $Id }) | Select-Object -First 1 }
function Get-PlayCount([string]$Project = $script:ProjectA) {
    $file = Join-Path $Project 'Library/e2e-playmode.log'
    if (-not (Test-Path -LiteralPath $file)) { return 0 }
    return @(Get-Content -LiteralPath $file | Where-Object { $_ }).Count
}

function Get-WorkerSettings([string]$Project) {
    $settings = (Read-BrokerEditor $Project).settings
    $standby = ($settings | Where-Object { $_.name -eq 'standbyImportWorkerCount' }).current
    $idle = ($settings | Where-Object { $_.name -eq 'idleImportWorkerShutdownDelayMilliseconds' }).current
    return "$standby/$idle"
}
# Workers get the project path with forward slashes, closed by a quote.
function Get-WorkerProcesses([string]$Project) {
    if (-not $isWindows) { return @() }
    $path = $Project.Replace('\', '/').TrimEnd('/')
    return @(Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*AssetImportWorker*' -and $_.CommandLine.Replace('\', '/') -like "*$path`"*" })
}

function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Text.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
}

function Staged([string]$Project, [string]$Agent, [string]$AssetPath) {
    return Join-Path (Join-Path (Join-Path (Get-BrokerDir $Project) 'staging') $Agent) ($AssetPath.Replace('/', [IO.Path]::DirectorySeparatorChar))
}

function Invoke-Unity([string[]]$UnityArgs, [string]$Log) {
    $p = Start-Process -FilePath $EditorPath -ArgumentList ($UnityArgs + @('-logFile', "`"$Log`"")) -PassThru -WindowStyle Hidden
    [void]$p.Handle
    $p.WaitForExit()
    return $p.ExitCode
}

# An Editor that dies during startup is reported at once with the end of its log. Running out of
# commit memory (RAM + page file) makes Package Manager fail with "Array buffer allocation failed";
# that gets one retry, because other processes on a busy machine release memory all the time.
function Start-BrokerEditor([string]$Project, [string]$Name) {
    $log = Join-Path $WorkRoot "$Name-editor.log"
    for ($attempt = 1; $attempt -le 2; $attempt++) {
        $p = Start-Process -FilePath $EditorPath -ArgumentList @('-batchmode', '-nographics', '-projectPath', "`"$Project`"", '-logFile', "`"$log`"") -PassThru -WindowStyle Hidden
        [void]$p.Handle
        $script:Editors[$Name] = $p
        Wait-Until { $p.HasExited -or $(
            $e = Read-BrokerEditor $Project; $null -ne $e -and (Get-BrokerEditorAgeMs $e) -lt 5000 -and -not $e.isCompiling -and -not $e.isUpdating) } "$Name Editor heartbeat"
        if (-not $p.HasExited) { return $p }
        $tail = if (Test-Path -LiteralPath $log) { @(Get-Content -LiteralPath $log -Tail 6) -join "`n" } else { '(no log)' }
        $outOfMemory = $tail -match 'Array buffer allocation failed|out of memory|Could not allocate'
        if ($attempt -eq 1 -and $outOfMemory) {
            Write-Host "   $Name Editor ran out of memory at startup; retrying once in 15 s" -ForegroundColor Yellow
            Start-Sleep -Seconds 15
            continue
        }
        $os = if ($isWindows) { Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } else { $null }
        $memory = if ($os) { ' Free commit memory: {0:N1} GB.' -f ($os.FreeVirtualMemory / 1MB) } else { '' }
        throw "$Name Editor exited with code $($p.ExitCode) before its heartbeat.$memory Log tail:`n$tail"
    }
}

$prefNames = @('kAutoRefreshMode', 'kAutoRefresh', 'DirectoryMonitoring', 'ScriptCompilationDuringPlay', 'InteractionMode', 'ApplicationIdleTime')
$isWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
function Get-PrefSnapshot {
    if (-not $isWindows) { return $null }
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Unity Technologies\Unity Editor 5.x')
    $snapshot = @{}
    if ($null -eq $key) { return $snapshot }
    foreach ($name in $key.GetValueNames()) {
        foreach ($pref in $prefNames) { if ($name -like "$($pref)_h*") { $snapshot[$name] = @{ value = $key.GetValue($name); kind = $key.GetValueKind($name) } } }
    }
    $key.Close()
    return $snapshot
}
function Get-PrefValue([string]$Pref) {
    $snapshot = Get-PrefSnapshot
    $match = $snapshot.Keys | Where-Object { $_ -like "$($Pref)_h*" } | Select-Object -First 1
    if ($match) { return $snapshot[$match].value }
    return $null
}
function Restore-PrefSnapshot {
    if ($null -eq $script:PrefSnapshot) { return 'not needed' }
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Unity Technologies\Unity Editor 5.x')
    $changed = 0
    $current = Get-PrefSnapshot
    foreach ($name in $current.Keys) {
        if (-not $script:PrefSnapshot.ContainsKey($name)) { $key.DeleteValue($name, $false); $changed++ }
    }
    foreach ($name in $script:PrefSnapshot.Keys) {
        $saved = $script:PrefSnapshot[$name]
        if (-not $current.ContainsKey($name) -or "$($current[$name].value)" -ne "$($saved.value)") { $key.SetValue($name, $saved.value, $saved.kind); $changed++ }
    }
    $key.Close()
    return "$changed value(s) restored"
}

# ------------------------------------------------------------------ setup
if (-not $EditorPath) {
    $hub = Join-Path $env:ProgramFiles 'Unity\Hub\Editor'
    $candidate = Get-ChildItem -LiteralPath $hub -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '6000.*' } |
        Sort-Object { [version](($_.Name -replace '[a-z].*$', '')) } -Descending | Select-Object -First 1
    if ($candidate) { $EditorPath = Join-Path $candidate.FullName 'Editor\Unity.exe' }
}
if (-not $EditorPath -or -not (Test-Path -LiteralPath $EditorPath)) { throw 'Unity 6 Editor not found; pass -EditorPath <Unity executable>.' }
$editorDir = Split-Path -Parent $EditorPath
$builtInTests = Join-Path $editorDir 'Data/Resources/PackageManager/BuiltInPackages/com.unity.test-framework/package.json'
$testFrameworkVersion = if (Test-Path -LiteralPath $builtInTests) { [string]((Get-Content -LiteralPath $builtInTests -Raw | ConvertFrom-Json).version) } else { '1.6.0' }

New-Item -ItemType Directory -Path $WorkRoot -Force | Out-Null
$env:UGA_MACHINE_DIR = Join-Path $WorkRoot 'machine'
$script:ProjectA = Join-Path $WorkRoot 'Project A'
$script:ProjectB = Join-Path $WorkRoot 'Project B'
$script:PrefSnapshot = Get-PrefSnapshot
$failed = $false

try {
    Step "Create a Unity $(Split-Path -Leaf (Split-Path -Parent $editorDir)) project with the broker" {
        $code = Invoke-Unity @('-batchmode', '-nographics', '-createProject', "`"$script:ProjectA`"", '-quit') (Join-Path $WorkRoot 'create.log')
        Assert-E2E ($code -eq 0) "createProject exited $code"
        $manifestPath = Join-Path $script:ProjectA 'Packages/manifest.json'
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        $manifest.dependencies | Add-Member -NotePropertyName 'com.unity.test-framework' -NotePropertyValue $testFrameworkVersion -Force
        if ($WithAdapters) {
            $manifest.dependencies | Add-Member -NotePropertyName 'com.unity.pipeline' -NotePropertyValue '0.9.0-exp.1' -Force
            $manifest.dependencies | Add-Member -NotePropertyName 'com.coplaydev.unity-mcp' -NotePropertyValue 'https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#v10.3.0' -Force
        }
        $manifest | Add-Member -NotePropertyName testables -NotePropertyValue @('com.neoxider.uga-editor-broker') -Force
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
        [void](Invoke-E2ECli @('install'))

        Write-Text (Join-Path $script:ProjectA 'Assets/Tests/E2E.Tests.asmdef') '{ "name": "E2E.Tests", "references": [ "UnityEngine.TestRunner", "UnityEditor.TestRunner" ], "includePlatforms": [], "overrideReferences": true, "precompiledReferences": [ "nunit.framework.dll" ], "autoReferenced": false, "defineConstraints": [ "UNITY_INCLUDE_TESTS" ] }'
        Write-Text (Join-Path $script:ProjectA 'Assets/Tests/E2EPlayTests.cs') @'
using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace E2E.Tests
{
    public class E2EPlayTests
    {
        [UnityTest, Category("Smoke")]
        public IEnumerator FramesAdvance()
        {
            var frame = Time.frameCount;
            yield return null;
            yield return null;
            Assert.Greater(Time.frameCount, frame);
        }

        [UnityTest]
        public IEnumerator AlsoPasses()
        {
            yield return null;
            Assert.Pass();
        }
    }
}
'@
        Write-Text (Join-Path $script:ProjectA 'Assets/Tests/Editor/E2E.EditTests.asmdef') '{ "name": "E2E.EditTests", "references": [ "UnityEngine.TestRunner", "UnityEditor.TestRunner" ], "includePlatforms": [ "Editor" ], "overrideReferences": true, "precompiledReferences": [ "nunit.framework.dll" ], "autoReferenced": false, "defineConstraints": [ "UNITY_INCLUDE_TESTS" ] }'
        Write-Text (Join-Path $script:ProjectA 'Assets/Tests/Editor/E2EEditTests.cs') @'
using NUnit.Framework;

namespace E2E.EditTests
{
    public class E2EEditTests
    {
        [Test, Category("Edit")]
        public void Adds() { Assert.AreEqual(4, 2 + 2); }
    }
}
'@
        Write-Text (Join-Path $script:ProjectA 'Assets/Editor/E2EHelpers.cs') @'
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;

// Test-only helpers: count real Play Mode entries and create the scenes the test uses.
[InitializeOnLoad]
static class E2EHelpers
{
    static E2EHelpers()
    {
        if (AssetDatabase.IsAssetImportWorkerProcess()) return;
        EditorApplication.playModeStateChanged += change =>
        {
            if (change == PlayModeStateChange.EnteredPlayMode) File.AppendAllText("Library/e2e-playmode.log", "entered\n");
        };
    }

    public static void CreateScenes()
    {
        Directory.CreateDirectory("Assets/Scenes");
        foreach (var name in new[] { "Arena", "Lobby" })
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
            EditorSceneManager.SaveScene(scene, "Assets/Scenes/" + name + ".unity");
        }
    }
}
'@
        $code = Invoke-Unity @('-batchmode', '-nographics', '-projectPath', "`"$script:ProjectA`"", '-executeMethod', 'E2EHelpers.CreateScenes', '-quit') (Join-Path $WorkRoot 'setup.log')
        Assert-E2E ($code -eq 0) "setup import exited $code; see setup.log"
        Assert-E2E (Test-Path -LiteralPath (Join-Path $script:ProjectA 'Assets/Scenes/Arena.unity')) 'scenes were not created'
        Copy-Item -LiteralPath $script:ProjectA -Destination $script:ProjectB -Recurse
        "test-framework $testFrameworkVersion$(if ($WithAdapters) { ', CoplayDev v10.3.0, Pipeline 0.9.0-exp.1' })"
    }

    Step 'Editor hosts the broker (heartbeat, version, Unity Test Framework bridge)' {
        [void](Start-BrokerEditor $script:ProjectA 'A')
        $editor = Read-BrokerEditor $script:ProjectA
        Assert-E2E ($editor.packageVersion -eq [string]((Get-Content (Join-Path $skillRoot 'unity-package/package.json') -Raw | ConvertFrom-Json).version)) "package version $($editor.packageVersion)"
        Assert-E2E (@($editor.adapters | Where-Object { $_.name -eq 'test-framework' -and $_.ok }).Count -eq 1) 'test runner bridge missing'
        "pid $($editor.pid), $($editor.unityVersion)"
    }

    Step 'doctor flags project settings; doctor -Fix applies them and passes a smoke Play Mode run' {
        $doctor = Invoke-E2ECli @('doctor') 9
        Assert-E2E ($doctor -like '*EnterPlayModeOptions*') "doctor did not flag Enter Play Mode Options:`n$doctor"
        $before = Get-PlayCount
        [void](Invoke-E2ECli @('doctor', '-Fix'))
        Wait-Until { @((Get-State).jobs | Where-Object { $_.kind -eq 'smoke' }).Count -gt 0 } 'smoke job'
        $smoke = @((Get-State).jobs | Where-Object { $_.kind -eq 'smoke' })[0]
        [void](Invoke-E2ECli @('wait', '-Job', $smoke.id, '-TimeoutSec', $StepTimeoutSec))
        $settings = Get-Content (Join-Path $script:ProjectA 'ProjectSettings/EditorSettings.asset') -Raw
        Assert-E2E ($settings -match 'm_EnterPlayModeOptionsEnabled: 1') 'EditorSettings.asset: Enter Play Mode Options not saved'
        Assert-E2E ($settings -match 'm_EnterPlayModeOptions: 1') 'EditorSettings.asset: DisableDomainReload not saved'
        Assert-E2E ((Get-PlayCount) -eq $before + 1) "smoke run should enter Play Mode once, count $((Get-PlayCount) - $before)"
        [void](Invoke-E2ECli @('doctor'))
        'project settings saved to ProjectSettings/EditorSettings.asset'
    }

    Step 'session start applies shared Editor preferences' {
        $script:WorkersBefore = Get-WorkerSettings $script:ProjectA
        [void](Invoke-E2ECli @('session', 'start', '-Agent', 'lead'))
        Wait-Until { $e = Read-BrokerEditor $script:ProjectA; $e.sessionId -eq (Get-State).sessionId } 'session settings applied'
        $editor = Read-BrokerEditor $script:ProjectA
        $bad = @($editor.settings | Where-Object { $_.scope -eq 'session' -and -not $_.ok })
        Assert-E2E ($bad.Count -eq 0) ('session settings not applied: ' + (($bad | ForEach-Object { $_.name }) -join ', '))
        if ($isWindows) { Assert-E2E ((Get-PrefValue 'kAutoRefreshMode') -eq 0) 'kAutoRefreshMode should be 0 in the registry' }
        $workers = Get-WorkerSettings $script:ProjectA
        Assert-E2E ($workers -eq '1/10000') "import workers should be 1 standby / 10000 ms idle, got $workers (before: $($script:WorkersBefore))"
        "auto refresh off, recompile after play, no throttling, import workers $($script:WorkersBefore) -> $workers"
    }

    Step 'focus token: one scene-graph owner at a time, its scene becomes active' {
        [void](Invoke-E2ECli @('take', '-Agent', 'a', '-Resource', 'scene:Assets/Scenes/Arena.unity'))
        [void](Invoke-E2ECli @('take', '-Agent', 'a', '-Kind', 'focus', '-Resource', 'scene:Assets/Scenes/Arena.unity'))
        Wait-Until { (Read-BrokerEditor $script:ProjectA).activeScene -eq 'Assets/Scenes/Arena.unity' } 'Arena active' 30
        [void](Invoke-E2ECli @('take', '-Agent', 'b', '-Resource', 'scene:Assets/Scenes/Lobby.unity'))
        [void](Invoke-E2ECli @('take', '-Agent', 'b', '-Kind', 'focus', '-Resource', 'scene:Assets/Scenes/Lobby.unity') 3)
        [void](Invoke-E2ECli @('release', '-Agent', 'a'))
        [void](Invoke-E2ECli @('take', '-Agent', 'b', '-Kind', 'focus', '-Resource', 'scene:Assets/Scenes/Lobby.unity', '-Wait', '-TimeoutSec', '30'))
        Wait-Until { (Read-BrokerEditor $script:ProjectA).activeScene -eq 'Assets/Scenes/Lobby.unity' } 'Lobby active' 30
        [void](Invoke-E2ECli @('release', '-Agent', 'b'))
        'Arena then Lobby became the active scene'
    }

    Step 'sync: two agents stage a script and a texture; one window imports and compiles both' {
        [void](Invoke-E2ECli @('take', '-Agent', 'a', '-Resource', 'folder:Assets/Game/'))
        [void](Invoke-E2ECli @('take', '-Agent', 'b', '-Resource', 'folder:Assets/Art/'))
        [void](Invoke-E2ECli @('stage', '-Agent', 'a', '-Path', 'Assets/Game/Score.cs', '-New'))
        Write-Text (Staged $script:ProjectA 'a' 'Assets/Game/Score.cs') "public static class Score { public static int Add(int a, int b) { return a + b; } }`n"
        [void](Invoke-E2ECli @('stage', '-Agent', 'b', '-Path', 'Assets/Art/icon.png', '-New'))
        $png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==')
        [IO.File]::WriteAllBytes((Staged $script:ProjectA 'b' 'Assets/Art/icon.png'), $png)
        $jobA = Invoke-E2EJob @('request', '-Agent', 'a', '-Lane', 'sync')
        $jobB = Invoke-E2EJob @('request', '-Agent', 'b', '-Lane', 'sync')
        [void](Invoke-E2ECli @('yield', '-Agent', 'a'))
        [void](Invoke-E2ECli @('yield', '-Agent', 'b'))
        [void](Invoke-E2ECli @('wait', '-Job', $jobA, '-TimeoutSec', $StepTimeoutSec))
        [void](Invoke-E2ECli @('wait', '-Job', $jobB, '-TimeoutSec', $StepTimeoutSec))
        Assert-E2E ((Get-Job $jobA).windowId -eq (Get-Job $jobB).windowId) 'both requests should share one sync window'
        Assert-E2E (Test-Path -LiteralPath (Join-Path $script:ProjectA 'Assets/Game/Score.cs')) 'Score.cs not published'
        Assert-E2E (Test-Path -LiteralPath (Join-Path $script:ProjectA 'Assets/Art/icon.png.meta')) 'icon.png not imported'
        Assert-E2E (-not (Test-Path -LiteralPath (Staged $script:ProjectA 'a' 'Assets/Game/Score.cs'))) 'staging not emptied'
        "one window $((Get-Job $jobA).windowId) for $jobA and $jobB"
    }

    Step 'compile errors go to their owner; the other agent is told it is blocked, not failed' {
        [void](Invoke-E2ECli @('stage', '-Agent', 'a', '-Path', 'Assets/Game/Broken.cs', '-New'))
        Write-Text (Staged $script:ProjectA 'a' 'Assets/Game/Broken.cs') "public static class Broken { public static int Value() { return missingSymbol; } }`n"
        [void](Invoke-E2ECli @('stage', '-Agent', 'b', '-Path', 'Assets/Art/notes.txt', '-New'))
        Write-Text (Staged $script:ProjectA 'b' 'Assets/Art/notes.txt') "art notes`n"
        $jobA = Invoke-E2EJob @('request', '-Agent', 'a', '-Lane', 'sync')
        $jobB = Invoke-E2EJob @('request', '-Agent', 'b', '-Lane', 'sync')
        [void](Invoke-E2ECli @('yield', '-Agent', 'a'))
        [void](Invoke-E2ECli @('yield', '-Agent', 'b'))
        $failedText = Invoke-E2ECli @('wait', '-Job', $jobA, '-TimeoutSec', $StepTimeoutSec) 8
        Assert-E2E ($failedText -like '*Broken.cs*missingSymbol*') "owner should get the compile error:`n$failedText"
        $blockedText = Invoke-E2ECli @('wait', '-Job', $jobB, '-TimeoutSec', $StepTimeoutSec) 9
        Assert-E2E ($blockedText -like '*compilation failed in a*') "other agent should be blocked by a:`n$blockedText"
        Assert-E2E ((Read-BrokerEditor $script:ProjectA).compileFailed) 'editor should report compile errors'
        'a: failed with its error; b: blocked by a'
    }

    Step 'hot work waits while scripts do not compile, then runs after the fix' {
        $hot = Invoke-E2EJob @('request', '-Agent', 'qa0', '-Lane', 'hot', '-Tests', 'category:Smoke')
        Start-Sleep -Seconds 8
        Assert-E2E ((Get-Job $hot).status -eq 'queued') "hot job should wait, is $((Get-Job $hot).status)"
        [void](Invoke-E2ECli @('stage', '-Agent', 'a', '-Path', 'Assets/Game/Broken.cs'))
        Write-Text (Staged $script:ProjectA 'a' 'Assets/Game/Broken.cs') "public static class Broken { public static int Value() { return 1; } }`n"
        $fix = Invoke-E2EJob @('request', '-Agent', 'a', '-Lane', 'sync')
        [void](Invoke-E2ECli @('yield', '-Agent', 'a'))
        [void](Invoke-E2ECli @('wait', '-Job', $fix, '-TimeoutSec', $StepTimeoutSec))
        [void](Invoke-E2ECli @('wait', '-Job', $hot, '-TimeoutSec', $StepTimeoutSec))
        Assert-E2E (-not (Read-BrokerEditor $script:ProjectA).compileFailed) 'compile errors should be gone'
        "fix $fix passed, then hot $hot passed"
    }

    Step 'cold work wins: hot batch waits for a busy agent, then runs tests together and the session after' {
        [void](Invoke-E2ECli @('take', '-Agent', 'c', '-Resource', 'folder:Assets/Levels/'))
        $before = Get-PlayCount
        $t1 = Invoke-E2EJob @('request', '-Agent', 'qa1', '-Lane', 'hot', '-Tests', 'category:Smoke')
        $t2 = Invoke-E2EJob @('request', '-Agent', 'qa2', '-Lane', 'hot', '-Tests', 'name:E2E.Tests.E2EPlayTests.AlsoPasses')
        Start-Sleep -Seconds 10
        Assert-E2E (-not (Test-BrokerWindow (Get-State)) -and (Get-Job $t1).status -eq 'queued') 'two hot jobs must wait while agent c works'
        $s1 = Invoke-E2EJob @('request', '-Agent', 'qa3', '-Lane', 'hot', '-JobKind', 'session', '-Scene', 'Assets/Scenes/Arena.unity', '-Minutes', '0.1')
        Wait-Until { $w = (Get-State).window; $w.lane -eq 'hot' -and $w.phase -eq 'draining' } 'hot window draining' 30
        Start-Sleep -Seconds 4
        $board = Invoke-E2ECli @('status')
        Assert-E2E ($board -like '*waiting for: c*') "board should name the agent that blocks the window:`n$board"
        [void](Invoke-E2ECli @('yield', '-Agent', 'c'))
        foreach ($id in @($t1, $t2, $s1)) { [void](Invoke-E2ECli @('wait', '-Job', $id, '-TimeoutSec', $StepTimeoutSec)) }
        Assert-E2E ((Get-Job $t1).windowId -eq (Get-Job $t2).windowId -and (Get-Job $t2).windowId -eq (Get-Job $s1).windowId) 'one hot window should carry all three jobs'
        $entries = (Get-PlayCount) - $before
        Assert-E2E ($entries -eq 2) "expected 2 Play Mode entries (one test batch + one session), got $entries"
        "2 test requests in 1 Play Mode run + 1 session; Play Mode entered $entries times"
    }

    Step 'guards stayed quiet: no false protocol violations during legitimate windows' {
        $bad = @((Get-State).violations | Where-Object { $_.kind -in @('script-outside-sync', 'unleased-save', 'play-mode-blocked') })
        Assert-E2E ($bad.Count -eq 0) ('unexpected violations: ' + (($bad | ForEach-Object { "$($_.kind): $($_.detail)" }) -join ' | '))
        "$(@((Get-State).violations).Count) note(s), none false"
    }

    Step 'EditMode selection runs; an empty selection is not a pass' {
        $edit = Invoke-E2EJob @('request', '-Agent', 'qa4', '-Lane', 'hot', '-Tests', 'category:Edit', '-TestMode', 'EditMode')
        [void](Invoke-E2ECli @('wait', '-Job', $edit, '-TimeoutSec', $StepTimeoutSec))
        $none = Invoke-E2EJob @('request', '-Agent', 'qa5', '-Lane', 'hot', '-Tests', 'category:DoesNotExist')
        $text = Invoke-E2ECli @('wait', '-Job', $none, '-TimeoutSec', $StepTimeoutSec) 8
        Assert-E2E ($text -like '*empty selection is not a pass*') "empty selection message missing:`n$text"
        'EditMode passed; empty PlayMode selection failed as it should'
    }

    Step 'exclusive window: only the holder may use the Editor until it is done' {
        $ex = Invoke-E2EJob @('request', '-Agent', 'lead', '-Lane', 'exclusive', '-Reason', 'e2e package change', '-Minutes', '2')
        Wait-Until { $w = (Get-State).window; $w.lane -eq 'exclusive' -and $w.phase -eq 'exclusive' } 'exclusive window running' 120
        [void](Invoke-E2ECli @('gate', '-Agent', 'lead'))
        [void](Invoke-E2ECli @('gate', '-Agent', 'a') 4)
        [void](Invoke-E2ECli @('done', '-Agent', 'lead', '-Job', $ex))
        [void](Invoke-E2ECli @('wait', '-Job', $ex, '-TimeoutSec', $StepTimeoutSec))
        $board = Invoke-E2ECli @('status')
        Assert-E2E ($board -like '*Leases:*' -and $board -like '*Jobs:*') 'board sections missing'
        'holder go, others wait, closed by the holder'
    }

    Step 'idle import workers shut down to one standby during a session' {
        $before = @(Get-WorkerProcesses $script:ProjectA).Count
        Wait-Until { @(Get-WorkerProcesses $script:ProjectA).Count -le 1 } 'project A import workers to drop to one' 90
        "$before worker process(es) a moment ago, $(@(Get-WorkerProcesses $script:ProjectA).Count) now"
    }

    Step 'two projects on one machine: independent leases, shared preferences released by the last session' {
        [void](Start-BrokerEditor $script:ProjectB 'B')
        $projects = Invoke-E2ECli @('projects')
        Assert-E2E (([regex]::Matches($projects, 'live')).Count -ge 2) "projects should list both live brokers:`n$projects"
        [void](Invoke-E2ECli @('take', '-Agent', 'x', '-Resource', 'folder:Assets/Levels/') 0 $script:ProjectB)
        [void](Invoke-E2ECli @('session', 'start', '-Agent', 'lead-b') 0 $script:ProjectB)
        Wait-Until { (Read-BrokerEditor $script:ProjectB).sessionId -eq (Get-State $script:ProjectB).sessionId } 'project B session'
        [void](Invoke-E2ECli @('release', '-Agent', 'c'))
        [void](Invoke-E2ECli @('release', '-Agent', 'a'))
        [void](Invoke-E2ECli @('release', '-Agent', 'b'))
        [void](Invoke-E2ECli @('session', 'stop', '-Force'))
        Wait-Until { (Read-BrokerEditor $script:ProjectA).sessionId -eq '' } 'project A session closed'
        if ($isWindows) { Assert-E2E ((Get-PrefValue 'kAutoRefreshMode') -eq 0) 'project B still needs auto refresh off' }
        Wait-Until { (Get-WorkerSettings $script:ProjectA) -eq $script:WorkersBefore } "project A import workers restored to $($script:WorkersBefore)" 30
        [void](Invoke-E2ECli @('release', '-Agent', 'x') 0 $script:ProjectB)
        [void](Invoke-E2ECli @('session', 'stop', '-Force') 0 $script:ProjectB)
        Wait-Until { (Read-BrokerEditor $script:ProjectB).sessionId -eq '' } 'project B session closed'
        if ($isWindows) {
            $after = Get-PrefSnapshot
            $mismatch = @($script:PrefSnapshot.Keys | Where-Object { -not $after.ContainsKey($_) -or "$($after[$_].value)" -ne "$($script:PrefSnapshot[$_].value)" })
            Assert-E2E ($mismatch.Count -eq 0) ('preferences not restored: ' + ($mismatch -join ', '))
        }
        'B kept the shared preferences after A stopped; the last stop restored the originals'
    }

    if ($WithAdapters) {
        Step 'Unity CLI reaches the uga_broker command through the Pipeline package' {
            $env:UNITY_NO_PAGER = '1'; $env:UNITY_NO_BANNER = '1'
            $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $list = & unity list --project-path $script:ProjectA 2>&1 | Out-String
            $status = & unity command uga_broker --action status --project-path $script:ProjectA 2>&1 | Out-String
            $ErrorActionPreference = $previous
            Assert-E2E ($list -like '*uga_broker*') "unity list does not show uga_broker:`n$list"
            Assert-E2E ($status -like '*Session:*') "unity command uga_broker status failed:`n$status"
            'unity list + unity command uga_broker status'
        }
    }
}
catch { $failed = $true }
finally {
    foreach ($name in @($script:Editors.Keys)) {
        $p = $script:Editors[$name]
        if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    }
    Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*$WorkRoot*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 2
    $restored = Restore-PrefSnapshot
    Write-Host "Editor preferences: $restored"
    if (-not $KeepProjects -and -not $failed) { Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue }
    elseif ($failed) { Write-Host "Kept $WorkRoot for inspection (Editor logs: *-editor.log)." }
    Write-Host ''
    Write-Host 'Step                                                                                          Result   Seconds'
    foreach ($r in $script:Results) { Write-Host ('{0,-94} {1,-8} {2,7}' -f $r.step, $(if ($r.ok) { 'pass' } else { 'FAIL' }), $r.seconds) }
    $total = 0.0
    foreach ($r in $script:Results) { $total += $r.seconds }
    Write-Host ('{0,-94} {1,-8} {2,7}' -f 'Total', '', $total)
}
if ($failed) { exit 1 }
Write-Output 'editor-broker live Unity e2e passed'
