param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Path {
    param([string]$Path)
    Assert-True -Condition (Test-Path -LiteralPath $Path) -Message "Missing expected path: $Path"
}

function Invoke-CheckedPowerShell {
    param([string]$ScriptPath, [string[]]$ScriptArgs = @())
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ScriptArgs
    $childExit = $LASTEXITCODE
    if ($childExit -ne 0) { throw "$ScriptPath failed with exit code $childExit" }
    Write-Output "SCRIPT_CHECK_EXIT=$childExit $ScriptPath"
}

function Assert-LocalLinks {
    param([string]$DocsPath)
    $generatedFiles = Get-ChildItem -LiteralPath $DocsPath -Recurse -File -Filter "*.md" |
        Where-Object { $_.Directory.Name -in @("Features", "Tasks", "QA", "QA_AGENT") }
    foreach ($file in $generatedFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        foreach ($link in [regex]::Matches($content, '\]\(([^)#\s]+)\)')) {
            $target = $link.Groups[1].Value
            if ($target -match '^(https?:|mailto:)') { continue }
            Assert-Path -Path (Join-Path $file.DirectoryName $target)
        }
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("unity-game-script-test-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $tempRoot "UnityProject"
$existingProjectRoot = Join-Path $tempRoot "ExistingUnityProject"
$compactProjectRoot = Join-Path $tempRoot "CompactUnityProject"
$nestedProjectRoot = Join-Path $tempRoot "NestedDocsUnityProject"
$memoryRoot = Join-Path $tempRoot "SkillMemoryRoot"
$cleanupDone = $false

try {
    foreach ($root in @($projectRoot, $existingProjectRoot, $compactProjectRoot, $nestedProjectRoot)) {
        New-Item -ItemType Directory -Path (Join-Path $root "Assets") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root "ProjectSettings") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root "Packages") -Force | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $existingProjectRoot "Assets/ExistingAsset.txt") -Value "existing" -Encoding ASCII
    New-Item -ItemType Directory -Path $memoryRoot -Force | Out-Null

    & (Join-Path $SkillRoot "setup_project.bat") $projectRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "setup_project.bat failed with exit code $LASTEXITCODE"
    & (Join-Path $SkillRoot "setup_project.bat") $projectRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "setup_project.bat idempotency run failed with exit code $LASTEXITCODE"
    & (Join-Path $SkillRoot "setup_project.bat") $existingProjectRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "setup_project.bat existing project run failed with exit code $LASTEXITCODE"
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $existingProjectRoot "Assets/_source"))) -Message "Assets/_source should not be created for non-empty Assets"

    $generatorPath = Join-Path $SkillRoot "tools/new-feature-docs.ps1"
    $legacyArgs = @("-ProjectRoot", $projectRoot, "-FeatureId", "001", "-FeatureName", "Player Movement", "-Tasks", "Input Adapter, Move Controller", "-CreateIndependentQa")
    Invoke-CheckedPowerShell -ScriptPath $generatorPath -ScriptArgs $legacyArgs
    $legacyFeature = Join-Path $projectRoot "Docs/Features/FEAT-001-player-movement.md"
    Add-Content -LiteralPath $legacyFeature -Value "Owner note must survive regeneration." -Encoding UTF8
    $legacyHash = (Get-FileHash -LiteralPath $legacyFeature -Algorithm SHA256).Hash
    Invoke-CheckedPowerShell -ScriptPath $generatorPath -ScriptArgs $legacyArgs
    Assert-True -Condition ((Get-FileHash -LiteralPath $legacyFeature -Algorithm SHA256).Hash -eq $legacyHash) -Message "Legacy regeneration overwrote owner content"
    & $generatorPath -ProjectRoot $projectRoot -FeatureId "002" -FeatureName "Combat Loop" -Tasks @("Aim", "Shoot", "Reload") -DetailedTracking
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $projectRoot "Docs/QA_AGENT/FEAT-002-combat-loop-qa.md"))) -Message "Detailed tracking alone must not create a QA duplicate"

    $legacyProfilePath = Join-Path $compactProjectRoot "Docs/DEV_PROFILE.json"
    New-Item -ItemType Directory -Path (Split-Path -Parent $legacyProfilePath) -Force | Out-Null
    Set-Content -LiteralPath $legacyProfilePath -Value '{"task_pages_standard_pro":true,"qa_agent_duplicate_checklist":"when_independent_qa_runs"}' -Encoding ASCII
    $legacyProfileHash = (Get-FileHash -LiteralPath $legacyProfilePath -Algorithm SHA256).Hash
    Invoke-CheckedPowerShell -ScriptPath $generatorPath -ScriptArgs @("-ProjectRoot", $compactProjectRoot, "-FeatureId", "003", "-FeatureName", "Existing GDD Task", "-Tasks", "Adapt Ready Controller, Verify Outcome")
    Assert-True -Condition ((Get-FileHash -LiteralPath $legacyProfilePath -Algorithm SHA256).Hash -eq $legacyProfileHash) -Message "Generator migrated a legacy profile"
    $compactDocs = Join-Path $compactProjectRoot "Docs"
    $compactFiles = @(Get-ChildItem -LiteralPath $compactDocs -Recurse -File -Filter "*.md")
    Assert-True -Condition ($compactFiles.Count -eq 1) -Message "Default workflow must create one brief, not duplicate task/QA records"
    foreach ($extraDir in @("Tasks", "QA", "QA_AGENT", "DEV_LOG")) {
        Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $compactDocs $extraDir))) -Message "Default workflow created duplicate tracking directory: $extraDir"
    }
    $compactText = Get-Content -LiteralPath $compactFiles[0].FullName -Raw -Encoding UTF8
    foreach ($taskName in @("Adapt Ready Controller", "Verify Outcome")) {
        Assert-True -Condition $compactText.Contains($taskName) -Message "Compact brief lost requested task: $taskName"
    }
    Add-Content -LiteralPath $compactFiles[0].FullName -Value "Existing QA evidence and owner wording." -Encoding UTF8
    $compactHash = (Get-FileHash -LiteralPath $compactFiles[0].FullName -Algorithm SHA256).Hash
    & $generatorPath -ProjectRoot $compactProjectRoot -FeatureId "003" -FeatureName "Existing GDD Task" -Tasks "Adapt Ready Controller, Verify Outcome"
    Assert-True -Condition ((Get-FileHash -LiteralPath $compactFiles[0].FullName -Algorithm SHA256).Hash -eq $compactHash) -Message "Compact regeneration overwrote existing evidence"

    New-Item -ItemType Directory -Path (Join-Path $nestedProjectRoot "Assets/_source/Docs") -Force | Out-Null
    & $generatorPath -ProjectRoot $nestedProjectRoot -FeatureId "004" -FeatureName "No Tasks Supplied" -DetailedTracking
    Assert-True -Condition (-not (Test-Path -LiteralPath (Join-Path $nestedProjectRoot "Docs"))) -Message "Generator created a competing docs root"
    Assert-Path -Path (Join-Path $nestedProjectRoot "Assets/_source/Docs/Tasks/TASK-004-01-no-tasks-supplied.md")
    foreach ($docsPath in @((Join-Path $projectRoot "Docs"), $compactDocs, (Join-Path $nestedProjectRoot "Assets/_source/Docs"))) {
        Assert-LocalLinks -DocsPath $docsPath
    }

    # A failing child check must fail the suite, even if it prints success-looking text.
    $failureScript = Join-Path $tempRoot "failing-check.ps1"
    Set-Content -LiteralPath $failureScript -Value 'Write-Output "success-looking text"; exit 7' -Encoding ASCII
    $failureCaught = $false
    try { Invoke-CheckedPowerShell -ScriptPath $failureScript }
    catch { $failureCaught = $_.Exception.Message -like "*exit code 7*" }
    Assert-True -Condition $failureCaught -Message "Child process failure was silently accepted"

    Invoke-CheckedPowerShell -ScriptPath (Join-Path $SkillRoot "tools/append-skill-memory.ps1") -ScriptArgs @(
        "-SkillRoot", $memoryRoot, "-Category", "qa", "-Trigger", "Temp script test",
        "-Learning", "Bounded QA test entry", "-ApplyWhen", "Testing append script",
        "-Evidence", "Script created and appended markdown", "-SkillImpact", "tools"
    )

    Invoke-CheckedPowerShell -ScriptPath (Join-Path $SkillRoot "tools/test-unity-workspace.ps1") -ScriptArgs @($SkillRoot)
    Invoke-CheckedPowerShell -ScriptPath (Join-Path $SkillRoot "tools/validate-skill.ps1") -ScriptArgs @($SkillRoot)
    $fixtureDir = Join-Path $projectRoot "Assets/_source/Scripts/Sample/EditModeSafe"
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fixtureDir "SampleRuntime.cs") -Value "internal sealed class SampleRuntime {}" -Encoding UTF8
    & (Join-Path $SkillRoot "tools/audit-project-structure.ps1") -ProjectRoot $projectRoot
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message "audit-project-structure.ps1 failed on the bootstrapped project"

    foreach ($relativePath in @(
        "Docs/DEV_CONFIG.md",
        "Docs/DEV_PROFILE.json",
        "Docs/DEV_STATE.md",
        "Docs/DEV_LOG",
        "Docs/Screenshots/iter-01",
        "Docs/Features/FEAT-001-player-movement.md",
        "Docs/Tasks/TASK-001-01-input-adapter.md",
        "Docs/Tasks/TASK-001-02-move-controller.md",
        "Docs/QA/FEAT-001-player-movement-qa.md",
        "Docs/QA_AGENT/FEAT-001-player-movement-qa.md",
        "Docs/Features/FEAT-002-combat-loop.md",
        "Docs/Tasks/TASK-002-01-aim.md",
        "Docs/Tasks/TASK-002-02-shoot.md",
        "Docs/Tasks/TASK-002-03-reload.md",
        "Assets/_source/Scripts",
        "Assets/_source/Scripts/Tests",
        "Assets/_source/Editor",
        "Assets/_source/Prefabs",
        "Assets/_source/Settings",
        "Assets/_source/Sprites"
    )) {
        Assert-Path -Path (Join-Path $projectRoot $relativePath)
    }

    $featureText = Get-Content -LiteralPath (Join-Path $projectRoot "Docs/Features/FEAT-001-player-movement.md") -Raw -Encoding UTF8
    foreach ($needle in @("TASK-001-01-input-adapter.md", "TASK-001-02-move-controller.md", "Max QA Attempts")) {
        Assert-True -Condition $featureText.Contains($needle) -Message "Feature output missing: $needle"
    }

    $taskText = Get-Content -LiteralPath (Join-Path $projectRoot "Docs/Tasks/TASK-001-01-input-adapter.md") -Raw -Encoding UTF8
    foreach ($needle in @("TASK-001-01 Input Adapter", "FEAT-001-player-movement.md", "Max QA Attempts")) {
        Assert-True -Condition $taskText.Contains($needle) -Message "Task output missing: $needle"
    }

    $logCount = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "Docs/DEV_LOG") -Filter "iteration-*.md").Count
    Assert-True -Condition ($logCount -eq 1) -Message "Expected one iteration log after idempotency test; got $logCount"

    $memoryText = Get-Content -LiteralPath (Join-Path $memoryRoot "SKILL_MEMORY.md") -Raw -Encoding UTF8
    foreach ($needle in @("###", "Temp script test", "Bounded QA test entry")) {
        Assert-True -Condition $memoryText.Contains($needle) -Message "Memory output missing: $needle"
    }

    Write-Output "unity-game script smoke tests passed"
}
finally {
    $resolvedTemp = Resolve-Path -LiteralPath $tempRoot -ErrorAction SilentlyContinue
    if ($resolvedTemp) {
        $resolvedText = $resolvedTemp.Path
        $tempBase = [System.IO.Path]::GetTempPath().TrimEnd("\")
        if ($resolvedText.StartsWith($tempBase, [System.StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolvedText).StartsWith("unity-game-script-test-")) {
            Remove-Item -LiteralPath $resolvedText -Recurse -Force
            $cleanupDone = $true
        } else {
            throw "Refusing to clean unexpected temp path: $resolvedText"
        }
    }
    Write-Output "TEMP_CLEANUP=$cleanupDone"
}
