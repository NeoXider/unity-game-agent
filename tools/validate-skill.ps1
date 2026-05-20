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
    "ask_about_neoxider_tools",
    "neoxider_tools",
    "qa_per_feature",
    "qa_final",
    "screenshot_policy",
    "reuse_first",
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
$profilePath = Join-Path $SkillRoot "templates/DEV_PROFILE.json"
$referencePath = Join-Path $SkillRoot "reference.md"

Assert-True -Condition (Test-Path $skillPath) -Message "Missing SKILL.md"
Assert-True -Condition (Test-Path $profilePath) -Message "Missing templates/DEV_PROFILE.json"

$skill = Get-Content -Path $skillPath -Raw -Encoding UTF8
$frontmatterOk = $skill -match "(?s)^---\r?\nname:\s*unity-game-agent\r?\ndescription:\s*.+?\r?\n---"
Assert-True -Condition $frontmatterOk -Message "SKILL.md frontmatter must contain only name and description"

$profileRaw = Get-Content -Path $profilePath -Raw -Encoding UTF8
$profile = $profileRaw | ConvertFrom-Json
foreach ($field in $requiredProfileFields) {
    $hasField = $profile.PSObject.Properties.Name -contains $field
    Assert-True -Condition $hasField -Message "DEV_PROFILE.json missing required field: $field"
}

$allTextFiles = Get-ChildItem -Path $SkillRoot -Recurse -File -Include *.md,*.json
$mojibakePatterns = @(
    ([string]([char]0x0432) + [string]([char]0x0402)),
    ([string]([char]0x0432) + [string]([char]0x2020)),
    ([string]([char]0x0432) + [string]([char]0x045A)),
    ([string]([char]0x0432) + [string]([char]0x045C)),
    ([string]([char]0x0420))
)
foreach ($file in $allTextFiles) {
    $text = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    $fenceCount = ([regex]::Matches($text, '```')).Count
    $fencesBalanced = ($fenceCount % 2) -eq 0
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
$hasPlayModeGate = $skill.Contains("final_playmode_tests_standard_pro")
$hasManifestPolicy = $skill.Contains("auto_install_mcp_in_manifest")
Assert-True -Condition $linksProviderNeutral -Message "SKILL.md must link provider-neutral MCP reference"
Assert-True -Condition $linksNeoxider -Message "SKILL.md must link NeoxiderTools reuse reference"
Assert-True -Condition $hasPlayModeGate -Message "SKILL.md must include standard/pro Play Mode close gate"
Assert-True -Condition $hasManifestPolicy -Message "SKILL.md must include MCP manifest auto-install policy"

Write-Output "unity-game skill validation passed"
