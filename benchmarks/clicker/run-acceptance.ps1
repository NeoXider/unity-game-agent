#requires -Version 5.1
<#
Runs the hidden acceptance tests (acceptance/) together with the agents' own tests on a finished
run, then removes the acceptance tests again. Every Unity process of the project must be closed.

  powershell -File benchmarks/clicker/run-acceptance.ps1 -Project <dir> -Out <dir>

Writes <Out>/acceptance.json: compile result, acceptance passed/total, agents' tests passed/total,
and every failure with its message.
#>
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Out,
    [string]$EditorPath = 'C:\Program Files\Unity\Hub\Editor\6000.6.0f1\Editor\Unity.exe'
)
$ErrorActionPreference = 'Stop'
$Project = [IO.Path]::GetFullPath($Project)
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$needle = $Project.Replace('\', '/').TrimEnd('/').ToLowerInvariant()
$open = @(Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and $_.CommandLine.Replace('\', '/').ToLowerInvariant().Contains($needle) })
if ($open.Count -gt 0) { throw "Close the project's Unity processes first: $(($open | ForEach-Object ProcessId) -join ', ')" }

$target = Join-Path $Project 'Assets/ClickerAcceptance'
if (Test-Path -LiteralPath $target) { throw "$target already exists" }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'acceptance') -Destination $target -Recurse

function Invoke-Tests([string]$Platform) {
    $xml = Join-Path $Out "results-$Platform.xml"
    $log = Join-Path $Out "unity-$Platform.log"
    Remove-Item -LiteralPath $xml -ErrorAction SilentlyContinue
    # -runTests exits on its own; -quit would end the run before the tests start.
    $p = Start-Process -FilePath $EditorPath -PassThru -WindowStyle Hidden -ArgumentList @(
        '-batchmode', '-nographics', '-projectPath', "`"$Project`"", '-runTests', '-testPlatform', $Platform,
        '-testResults', "`"$xml`"", '-logFile', "`"$log`"")
    [void]$p.Handle
    $p.WaitForExit()
    $cases = @()
    if (Test-Path -LiteralPath $xml) {
        [xml]$doc = Get-Content -LiteralPath $xml -Raw
        foreach ($case in $doc.SelectNodes('//test-case')) {
            $assembly = $case.SelectSingleNode('ancestor::test-suite[@type="Assembly"]')
            $cases += [pscustomobject]@{
                platform = $Platform
                assembly = if ($assembly) { [IO.Path]::GetFileNameWithoutExtension($assembly.name) } else { '' }
                name = $case.fullname
                result = $case.result
                message = if ($case.failure) { $m = $case.failure.message; ("$(if ($m -is [Xml.XmlNode]) { $m.InnerText } else { $m })" -replace '\s+', ' ').Trim() } else { '' }
            }
        }
    }
    $errors = @(Select-String -LiteralPath $log -Pattern 'error CS\d+' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Select-Object -Unique -First 20)
    return [pscustomobject]@{ exit = $p.ExitCode; ran = (Test-Path -LiteralPath $xml); cases = $cases; compileErrors = $errors }
}

try {
    $edit = Invoke-Tests 'EditMode'
    $play = Invoke-Tests 'PlayMode'
} finally {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$target.meta" -Force -ErrorAction SilentlyContinue
}

$all = @($edit.cases) + @($play.cases)
$acceptance = @($all | Where-Object { $_.assembly -like 'Clicker.Acceptance*' })
$own = @($all | Where-Object { $_.assembly -notlike 'Clicker.Acceptance*' })
$expected = 13 + 4  # EditMode economy + project checks, PlayMode gameplay checks
$summary = [ordered]@{
    project = $Project
    compiled = $edit.ran -and $play.ran -and $edit.compileErrors.Count -eq 0
    compile_errors = @($edit.compileErrors + $play.compileErrors | Select-Object -Unique)
    acceptance_passed = @($acceptance | Where-Object { $_.result -eq 'Passed' }).Count
    acceptance_total = [Math]::Max($expected, $acceptance.Count)
    own_tests_passed = @($own | Where-Object { $_.result -eq 'Passed' }).Count
    own_tests_total = $own.Count
    own_editmode_tests = @($own | Where-Object { $_.platform -eq 'EditMode' }).Count
    own_playmode_tests = @($own | Where-Object { $_.platform -eq 'PlayMode' }).Count
    failures = @($all | Where-Object { $_.result -ne 'Passed' } | ForEach-Object { [ordered]@{ test = $_.name; result = $_.result; message = $_.message } })
}
[IO.File]::WriteAllText((Join-Path $Out 'acceptance.json'), ($summary | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
$summary | ConvertTo-Json -Depth 5
