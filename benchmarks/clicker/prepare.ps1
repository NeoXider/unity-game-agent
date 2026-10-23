#requires -Version 5.1
<#
Creates the benchmark's template project once and copies it to run-a/ and run-b/, so both runs
start from the same imported Library and the same first commit.

  powershell -File benchmarks/clicker/prepare.ps1 [-WorkRoot <dir>] [-EditorPath <Unity.exe>] [-CheckCli]

-CheckCli opens the template in a batch-mode Editor and checks that `unity command` reaches it
through the Pipeline package (both runs rely on that).
#>
param(
    [string]$WorkRoot = (Join-Path ([IO.Path]::GetTempPath()) 'uga-clicker-bench'),
    [string]$EditorPath = 'C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe',
    [string]$PipelineVersion = '0.9.0-exp.1',
    [switch]$CheckCli
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $EditorPath)) { throw "Unity Editor not found: $EditorPath" }
$template = Join-Path $WorkRoot 'template'
if (Test-Path -LiteralPath $template) { throw "$template already exists; remove the work folder to prepare again." }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

function Invoke-Unity([string[]]$UnityArgs, [string]$Log) {
    $p = Start-Process -FilePath $EditorPath -ArgumentList ($UnityArgs + @('-logFile', "`"$Log`"")) -PassThru -WindowStyle Hidden
    [void]$p.Handle
    $p.WaitForExit()
    return $p.ExitCode
}

function Get-BuiltInVersion([string]$Name) {
    $file = Join-Path (Split-Path -Parent $EditorPath) "Data\Resources\PackageManager\BuiltInPackages\$Name\package.json"
    return ([IO.File]::ReadAllText($file) | ConvertFrom-Json).version
}

$timer = [Diagnostics.Stopwatch]::StartNew()
$code = Invoke-Unity @('-batchmode', '-nographics', '-createProject', "`"$template`"", '-quit') (Join-Path $WorkRoot 'create.log')
if ($code -ne 0) { throw "createProject exited $code (see create.log)" }

$manifestPath = Join-Path $template 'Packages/manifest.json'
$manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
$manifest.dependencies | Add-Member -NotePropertyName 'com.unity.ugui' -NotePropertyValue (Get-BuiltInVersion 'com.unity.ugui') -Force
$manifest.dependencies | Add-Member -NotePropertyName 'com.unity.test-framework' -NotePropertyValue (Get-BuiltInVersion 'com.unity.test-framework') -Force
$manifest.dependencies | Add-Member -NotePropertyName 'com.unity.pipeline' -NotePropertyValue $PipelineVersion -Force
# Package Manager rejects a manifest with a byte order mark.
[IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

$code = Invoke-Unity @('-batchmode', '-nographics', '-projectPath', "`"$template`"", '-quit') (Join-Path $WorkRoot 'import.log')
if ($code -ne 0) { throw "first import exited $code (see import.log)" }

if ($CheckCli) {
    $log = Join-Path $WorkRoot 'cli-check.log'
    $editor = Start-Process -FilePath $EditorPath -ArgumentList @('-batchmode', '-nographics', '-projectPath', "`"$template`"", '-logFile', "`"$log`"") -PassThru -WindowStyle Hidden
    try {
        $portFile = Join-Path $template 'Library/Pipeline/.unity-pipeline-port'
        $deadline = (Get-Date).AddMinutes(4)
        while (-not (Test-Path -LiteralPath $portFile) -and (Get-Date) -lt $deadline -and -not $editor.HasExited) { Start-Sleep -Seconds 2 }
        if (-not (Test-Path -LiteralPath $portFile)) { throw 'The Pipeline package never wrote its port file; unity command cannot reach the Editor.' }
        $env:UNITY_NO_PAGER = '1'; $env:UNITY_NO_BANNER = '1'
        $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $answer = & unity command scene list_open --project-path $template 2>&1 | Out-String
        $ErrorActionPreference = $previous
        Write-Output "unity command scene list_open:`n$answer"
    } finally {
        Stop-Process -Id $editor.Id -Force -ErrorAction SilentlyContinue
        Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -and $_.CommandLine.Replace('\', '/') -like "*$($template.Replace('\', '/'))*" } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
    }
}

[IO.File]::WriteAllText((Join-Path $template '.gitignore'), "/Library/`n/Temp/`n/Logs/`n/UserSettings/`n/obj/`n*.csproj`n*.sln`n*.slnx`n", (New-Object Text.UTF8Encoding $false))
$previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
& git -C $template init -q 2>&1 | Out-Null
& git -C $template add -A 2>&1 | Out-Null
& git -C $template -c user.name=bench -c user.email=bench@example.invalid commit -q -m 'Benchmark template' 2>&1 | Out-Null
$ErrorActionPreference = $previous

foreach ($run in 'run-a', 'run-b') {
    $target = Join-Path $WorkRoot $run
    & robocopy $template $target /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy to $target failed ($LASTEXITCODE)" }
}
$size = (Get-ChildItem -LiteralPath $template -Recurse -Force -File | Measure-Object Length -Sum).Sum
Write-Output ("Template ready in {0:N0} s, {1:N0} MB, copied to run-a and run-b under {2}" -f $timer.Elapsed.TotalSeconds, ($size / 1MB), $WorkRoot)
