param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$requiredProfileFields = @(
    "dev_mode",
    "skill_mode",
    "ui_mode",
    "ui_stack",
    "mcp_mode",
    "mcp_adapter",
    "auto_install_mcp_in_manifest",
    "provider_neutral_tool_mapping",
    "strict_preflight",
    "visual_verification",
    "visual_verification_max_resolution",
    "final_console_check",
    "final_playmode_tests_standard_pro",
    "final_tests_when_relevant",
    "final_build_validation_when_relevant",
    "qa_verification_driver_required",
    "qa_tests_required_standard_pro",
    "qa_screenshot_evidence_required",
    "interactive_qa_requires_runtime_driver",
    "qa_max_attempts_before_degraded_report",
    "qa_continue_after_degraded_report",
    "qa_degraded_report_required",
    "ask_about_neoxider_tools",
    "neoxider_tools",
    "qa_per_feature",
    "qa_final",
    "screenshot_policy",
    "reuse_first",
    "external_reference_discovery",
    "no_reinventing_without_reason",
    "lead_dev_qa_workflow_standard_pro",
    "task_pages_standard_pro",
    "qa_agent_duplicate_checklist",
    "auto_advance_after_self_qa",
    "skill_memory_enabled",
    "skill_memory_write_policy",
    "skill_memory_scope",
    "role_subskills_enabled",
    "mandatory_subagents_standard_pro",
    "subagent_fallback_policy",
    "gd_before_lead",
    "designer_before_lead_when_visual",
    "library_policy",
    "project_frameworks"
)

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$skillPath = Join-Path $SkillRoot "SKILL.md"
$readmePath = Join-Path $SkillRoot "README.md"
$skillMemoryPath = Join-Path $SkillRoot "SKILL_MEMORY.md"
$headerImagePath = Join-Path $SkillRoot "assets/unity-game-agent-header.png"
$profilePath = Join-Path $SkillRoot "templates/DEV_PROFILE.json"
$referencePath = Join-Path $SkillRoot "reference.md"
$requiredTemplates = @(
    "templates/FEATURE.md",
    "templates/TASK.md",
    "templates/QA_CHECKLIST.md",
    "templates/QA_AGENT_CHECKLIST.md",
    "tools/playmode-qa-automation.md"
)
$requiredScripts = @(
    "setup_project.bat",
    "tools/append-skill-memory.ps1",
    "tools/new-feature-docs.ps1",
    "tools/test-scripts.ps1",
    "tools/validate-skill.ps1"
)
$requiredRoles = @(
    "roles/game-designer.md",
    "roles/designer.md",
    "roles/lead.md",
    "roles/developer.md",
    "roles/qa.md"
)
$verificationTemplates = @(
    "templates/FEATURE.md",
    "templates/TASK.md",
    "templates/QA_CHECKLIST.md",
    "templates/QA_AGENT_CHECKLIST.md"
)

Assert-True -Condition (Test-Path $skillPath) -Message "Missing SKILL.md"
Assert-True -Condition (Test-Path $readmePath) -Message "Missing README.md"
Assert-True -Condition (Test-Path $skillMemoryPath) -Message "Missing SKILL_MEMORY.md"
Assert-True -Condition (Test-Path $headerImagePath) -Message "Missing assets/unity-game-agent-header.png"
Assert-True -Condition (Test-Path $profilePath) -Message "Missing templates/DEV_PROFILE.json"
foreach ($template in $requiredTemplates) {
    $templatePath = Join-Path $SkillRoot $template
    Assert-True -Condition (Test-Path $templatePath) -Message "Missing $template"
}
foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $SkillRoot $script
    Assert-True -Condition (Test-Path $scriptPath) -Message "Missing $script"
}
foreach ($role in $requiredRoles) {
    $rolePath = Join-Path $SkillRoot $role
    Assert-True -Condition (Test-Path $rolePath) -Message "Missing $role"
    $roleText = Get-Content -Path $rolePath -Raw -Encoding UTF8
    foreach ($requiredSection in @("## Purpose", "## Goals", "## Use When", "## Inputs", "## Outputs", "## Allowed Writes", "## Forbidden Actions", "## Workflow", "## Done Gate")) {
        Assert-True -Condition $roleText.Contains($requiredSection) -Message "$role missing section: $requiredSection"
    }
}
foreach ($template in $verificationTemplates) {
    $templatePath = Join-Path $SkillRoot $template
    $templateText = Get-Content -Path $templatePath -Raw -Encoding UTF8
    foreach ($requiredText in @("Verification Driver", "Tests Required", "Screenshot Required", "Automation Gap", "Max QA Attempts")) {
        Assert-True -Condition $templateText.Contains($requiredText) -Message "$template missing verification field: $requiredText"
    }
}
foreach ($template in @("templates/QA_CHECKLIST.md", "templates/QA_AGENT_CHECKLIST.md")) {
    $templatePath = Join-Path $SkillRoot $template
    $templateText = Get-Content -Path $templatePath -Raw -Encoding UTF8
    foreach ($requiredText in @("Degraded Report", "Skipped Checks", "Follow-up task")) {
        Assert-True -Condition $templateText.Contains($requiredText) -Message "$template missing degraded QA field: $requiredText"
    }
}

$skill = Get-Content -Path $skillPath -Raw -Encoding UTF8
$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$frontmatterOk = $skill -match "(?s)^---\r?\nname:\s*unity-game-agent\r?\ndescription:\s*.+?\r?\n---"
Assert-True -Condition $frontmatterOk -Message "SKILL.md frontmatter must contain only name and description"
Assert-True -Condition $readme.Contains("assets/unity-game-agent-header.png") -Message "README.md must link the header image"

$headerBytes = [System.IO.File]::ReadAllBytes($headerImagePath)
$pngSignature = [byte[]](137, 80, 78, 71, 13, 10, 26, 10)
$hasPngSignature = $headerBytes.Length -gt $pngSignature.Length
for ($i = 0; $i -lt $pngSignature.Length; $i++) {
    if ($headerBytes[$i] -ne $pngSignature[$i]) {
        $hasPngSignature = $false
        break
    }
}
Assert-True -Condition $hasPngSignature -Message "assets/unity-game-agent-header.png must be a valid PNG"

$profileRaw = Get-Content -Path $profilePath -Raw -Encoding UTF8
$profile = $profileRaw | ConvertFrom-Json
foreach ($field in $requiredProfileFields) {
    $hasField = $profile.PSObject.Properties.Name -contains $field
    Assert-True -Condition $hasField -Message "DEV_PROFILE.json missing required field: $field"
}

$batchPath = Join-Path $SkillRoot "setup_project.bat"
$batchBytes = [System.IO.File]::ReadAllBytes($batchPath)
$lineFeedCount = 0
$crlfCount = 0
for ($i = 0; $i -lt $batchBytes.Length; $i++) {
    if ($batchBytes[$i] -eq 10) {
        $lineFeedCount++
        if ($i -gt 0 -and $batchBytes[$i - 1] -eq 13) {
            $crlfCount++
        }
    }
}
Assert-True -Condition ($lineFeedCount -eq $crlfCount) -Message "setup_project.bat must use CRLF line endings for cmd.exe"

$allTextFiles = Get-ChildItem -Path $SkillRoot -Recurse -File -Include *.md,*.json,*.ps1,*.bat
$mojibakePatterns = @(
    ([string]([char]0x0432) + [string]([char]0x0402)),
    ([string]([char]0x0432) + [string]([char]0x2020)),
    ([string]([char]0x0432) + [string]([char]0x045A)),
    ([string]([char]0x0432) + [string]([char]0x045C)),
    ([string]([char]0x0420))
)
foreach ($file in $allTextFiles) {
    $text = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $isMarkdown = $file.Extension -eq ".md"
    $fenceCount = 0
    $fencesBalanced = $true
    if ($isMarkdown) {
        $fenceCount = ([regex]::Matches($text, '```')).Count
        $fencesBalanced = ($fenceCount % 2) -eq 0
    }
    $hasNoMojibake = $true
    foreach ($pattern in $mojibakePatterns) {
        if ($text.Contains($pattern)) {
            $hasNoMojibake = $false
            break
        }
    }
    $fenceMessage = "Unbalanced markdown code fences in {0}: {1}" -f $file.FullName, $fenceCount
    $mojibakeMessage = "Mojibake pattern found in {0}" -f $file.FullName
    Assert-True -Condition $fencesBalanced -Message $fenceMessage
    Assert-True -Condition $hasNoMojibake -Message $mojibakeMessage
}

$reference = Get-Content -Path $referencePath -Raw -Encoding UTF8
foreach ($field in $requiredProfileFields) {
    $skillHasField = $skill.Contains("`"$field`"")
    $referenceHasField = $reference.Contains("`"$field`"")
    Assert-True -Condition $skillHasField -Message "SKILL.md runtime policy missing field: $field"
    Assert-True -Condition $referenceHasField -Message "reference.md schema missing field: $field"
}

$linksProviderNeutral = $skill.Contains("tools/mcp-provider-neutral.md")
$linksNeoxider = $skill.Contains("tools/neoxider-tools-reuse.md")
$linksSkillMemory = $skill.Contains("SKILL_MEMORY.md") -and $skill.Contains("tools/append-skill-memory.ps1")
$linksRoles = $skill.Contains("roles/game-designer.md") -and $skill.Contains("roles/designer.md") -and $skill.Contains("roles/lead.md") -and $skill.Contains("roles/developer.md") -and $skill.Contains("roles/qa.md")
$linksPlayModeQa = $skill.Contains("tools/playmode-qa-automation.md")
$linksScriptTests = $skill.Contains("tools/test-scripts.ps1")
$playModeQa = Get-Content -Path (Join-Path $SkillRoot "tools/playmode-qa-automation.md") -Raw -Encoding UTF8
$hasPlayModeGate = $skill.Contains("final_playmode_tests_standard_pro")
$hasManifestPolicy = $skill.Contains("auto_install_mcp_in_manifest")
$hasDegradedQaPolicy = $skill.Contains("qa_max_attempts_before_degraded_report") -and $skill.Contains("degraded QA report")
$hasBoundedQaReference = $playModeQa.Contains("Bounded QA Attempts") -and $playModeQa.Contains("Max QA Attempts")
Assert-True -Condition $linksProviderNeutral -Message "SKILL.md must link provider-neutral MCP reference"
Assert-True -Condition $linksNeoxider -Message "SKILL.md must link NeoxiderTools reuse reference"
Assert-True -Condition $linksSkillMemory -Message "SKILL.md must link skill memory and append tool"
Assert-True -Condition $linksRoles -Message "SKILL.md must link all role subskills"
Assert-True -Condition $linksPlayModeQa -Message "SKILL.md must link Play Mode QA automation reference"
Assert-True -Condition $linksScriptTests -Message "SKILL.md must link script smoke tests"
Assert-True -Condition $hasPlayModeGate -Message "SKILL.md must include standard/pro Play Mode close gate"
Assert-True -Condition $hasManifestPolicy -Message "SKILL.md must include MCP manifest auto-install policy"
Assert-True -Condition $hasDegradedQaPolicy -Message "SKILL.md must include bounded degraded QA policy"
Assert-True -Condition $hasBoundedQaReference -Message "tools/playmode-qa-automation.md must include bounded QA attempts"

Write-Output "unity-game skill validation passed"
