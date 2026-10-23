#requires -Version 5.1
<#
Takes two pictures of a finished run for the write-up (the clicker, then the upgrades) with the
capture/ PlayMode test, then removes that test again. Needs a GPU, so no -nographics; every Unity
process of the project must be closed.

  powershell -File benchmarks/clicker/capture.ps1 -Project <dir> -Out <dir>
#>
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Out,
    [string]$EditorPath = 'C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe'
)
$ErrorActionPreference = 'Stop'
$Project = [IO.Path]::GetFullPath($Project)
$Out = [IO.Path]::GetFullPath($Out)
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$target = Join-Path $Project 'Assets/ClickerCapture'
if (Test-Path -LiteralPath $target) { throw "$target already exists" }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'capture') -Destination $target -Recurse
$env:CLICKER_SHOTS = $Out
try {
    $p = Start-Process -FilePath $EditorPath -PassThru -WindowStyle Hidden -ArgumentList @(
        '-batchmode', '-projectPath', "`"$Project`"", '-runTests', '-testPlatform', 'PlayMode',
        '-assemblyNames', 'Clicker.Capture.PlayMode', '-testResults', "`"$Out\capture-results.xml`"",
        '-logFile', "`"$Out\capture.log`"")
    [void]$p.Handle
    $p.WaitForExit()
} finally {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$target.meta" -Force -ErrorAction SilentlyContinue
}
foreach ($name in 'clicker.png', 'upgrades.png') {
    $file = Join-Path $Out $name
    if (Test-Path -LiteralPath $file) { '{0}: {1:N0} KB' -f $file, ((Get-Item -LiteralPath $file).Length / 1KB) } else { "missing: $file (see capture.log)" }
}
