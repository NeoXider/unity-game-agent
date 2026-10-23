#requires -Version 5.1
<#
Writes one prompt file per role for a run: brief.md with the placeholders filled in and that run's
"How to work" text from README.md.

  powershell -File benchmarks/clicker/render-prompts.ps1 -Run A|B -Project <dir> -Out <dir>
#>
param(
    [Parameter(Mandatory)][ValidateSet('A', 'B')][string]$Run,
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Out,
    [string]$UnityExe = 'C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe'
)
$ErrorActionPreference = 'Stop'
$skill = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$brief = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'brief.md'))
$readme = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'README.md'))
# The run texts are the quoted blocks after "Run A:" and "Run B:" in README.md.
$match = [regex]::Match($readme, "(?ms)^Run ${Run}:\s*\r?\n\r?\n((?:>.*?\r?\n)+)")
if (-not $match.Success) { throw "No 'Run ${Run}:' text in README.md" }
$howTo = (($match.Groups[1].Value -split '\r?\n') | ForEach-Object { $_ -replace '^>\s?', '' }) -join "`n"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
foreach ($role in 'core', 'ui', 'scene') {
    $text = $brief.Replace('{HOW_TO_WORK}', $howTo.Trim()).Replace('{PROJECT}', $Project).Replace('{ROLE}', $role).Replace('{SKILL}', $skill).Replace('{UNITY_EXE}', $UnityExe)
    # The header line is for people reading the benchmark, not for the agents.
    $text = $text -replace '(?s)^# Coin Clicker: task brief\s*\r?\n\r?\nThis brief is given.*?\r?\n\r?\n', "# Coin Clicker`n`n"
    $path = Join-Path $Out "$role.md"
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))
    Write-Output $path
}
