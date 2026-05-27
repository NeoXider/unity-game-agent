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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("unity-game-script-test-" + [guid]::NewGuid().ToString("N"))
$projectRoot = Join-Path $tempRoot "UnityProject"
$existingProjectRoot = Join-Path $tempRoot "ExistingUnityProject"
$memoryRoot = Join-Path $tempRoot "SkillMemoryRoot"
$cleanupDone = $false

try {
    foreach ($root in @($projectRoot, $existingProjectRoot)) {
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

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillRoot "tools/new-feature-docs.ps1") -ProjectRoot $projectRoot -FeatureId "001" -FeatureName "Player Movement" -Tasks "Input Adapter, Move Controller"
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillRoot "tools/new-feature-docs.ps1") -ProjectRoot $projectRoot -FeatureId "001" -FeatureName "Player Movement" -Tasks "Input Adapter, Move Controller"
    & (Join-Path $SkillRoot "tools/new-feature-docs.ps1") -ProjectRoot $projectRoot -FeatureId "002" -FeatureName "Combat Loop" -Tasks @("Aim", "Shoot", "Reload")

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillRoot "tools/append-skill-memory.ps1") `
        -SkillRoot $memoryRoot `
        -Category "qa" `
        -Trigger "Temp script test" `
        -Learning "Bounded QA test entry" `
        -ApplyWhen "Testing append script" `
        -Evidence "Script created and appended markdown" `
        -SkillImpact "tools"

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SkillRoot "tools/validate-skill.ps1") $SkillRoot

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
        "Assets/_source/UI"
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
