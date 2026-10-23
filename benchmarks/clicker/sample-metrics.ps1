#requires -Version 5.1
<#
Samples the Unity processes that work on one project until a stop file appears, then writes a
summary. Start it right before a run and create the stop file right after the last agent replies.

  powershell -File benchmarks/clicker/sample-metrics.ps1 -Project <dir> -Out <dir>
  New-Item <Out>/stop   # ends sampling

Writes <Out>/samples.csv and <Out>/metrics.json: Unity Editor launches (distinct non-worker
processes), peak concurrent Editors, peak private memory of the project's Unity processes, lowest
free commit memory.
#>
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Out,
    [int]$IntervalSec = 2
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$stop = Join-Path $Out 'stop'
Remove-Item -LiteralPath $stop -ErrorAction SilentlyContinue
$needle = [IO.Path]::GetFullPath($Project).Replace('\', '/').TrimEnd('/').ToLowerInvariant()
$csv = Join-Path $Out 'samples.csv'
Set-Content -LiteralPath $csv -Value 'time,editors,workers,private_gb,free_commit_gb' -Encoding ASCII

$editorsSeen = @{}
$cliSeen = @{}
$peakEditors = 0; $peakPrivate = 0.0; $minCommit = [double]::MaxValue
$started = Get-Date
while (-not (Test-Path -LiteralPath $stop)) {
    $mine = @(Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine.Replace('\', '/').ToLowerInvariant().Contains($needle) })
    # The Unity CLI is also called unity.exe (it lives under AppData\Local\Unity\bin): count it apart.
    $cli = @($mine | Where-Object { $_.ExecutablePath -and $_.ExecutablePath -match '\\Unity\\bin\\unity\.exe$' })
    $workers = @($mine | Where-Object { $_.CommandLine -like '*AssetImportWorker*' })
    $editors = @($mine | Where-Object { $_.CommandLine -notlike '*AssetImportWorker*' -and $cli -notcontains $_ })
    foreach ($e in $editors) { $editorsSeen["$($e.ProcessId)/$($e.CreationDate)"] = $e.CommandLine }
    foreach ($c in $cli) { $cliSeen["$($c.ProcessId)/$($c.CreationDate)"] = $c.CommandLine }
    $private = 0.0
    foreach ($p in $mine) {
        $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
        if ($proc) { $private += $proc.PrivateMemorySize64 / 1GB }
    }
    $commit = (Get-CimInstance Win32_OperatingSystem).FreeVirtualMemory / 1MB
    $peakEditors = [Math]::Max($peakEditors, $editors.Count)
    $peakPrivate = [Math]::Max($peakPrivate, $private)
    $minCommit = [Math]::Min($minCommit, $commit)
    $row = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:HH:mm:ss},{1},{2},{3:0.00},{4:0.00}', (Get-Date), $editors.Count, $workers.Count, $private, $commit)
    Add-Content -LiteralPath $csv -Value $row -Encoding ASCII
    Start-Sleep -Seconds $IntervalSec
}
$summary = [ordered]@{
    project = $Project
    sampled_minutes = [Math]::Round(((Get-Date) - $started).TotalMinutes, 1)
    unity_editor_launches = $editorsSeen.Count
    unity_cli_calls = $cliSeen.Count
    peak_concurrent_editors = $peakEditors
    peak_private_gb = [Math]::Round($peakPrivate, 2)
    min_free_commit_gb = [Math]::Round($minCommit, 2)
    editor_command_lines = @($editorsSeen.Values | ForEach-Object { $_.Substring(0, [Math]::Min(300, $_.Length)) })
}
[IO.File]::WriteAllText((Join-Path $Out 'metrics.json'), ($summary | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding $false))
$summary | ConvertTo-Json -Depth 4
