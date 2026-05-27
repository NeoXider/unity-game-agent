param(
    [string]$SkillRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,

    [Parameter(Mandatory = $true)]
    [ValidateSet("workflow", "verification", "reuse", "unity-mcp", "docs", "qa", "architecture", "tools", "anti-pattern")]
    [string]$Category,

    [Parameter(Mandatory = $true)]
    [string]$Trigger,

    [Parameter(Mandatory = $true)]
    [string]$Learning,

    [Parameter(Mandatory = $true)]
    [string]$ApplyWhen,

    [Parameter(Mandatory = $true)]
    [string]$Evidence,

    [Parameter(Mandatory = $true)]
    [string]$SkillImpact
)

$ErrorActionPreference = "Stop"

function Normalize-Line {
    param([string]$Value)
    return (($Value -replace "\r?\n", " ") -replace "\s+", " ").Trim()
}

$memoryPath = Join-Path $SkillRoot "SKILL_MEMORY.md"
if (-not (Test-Path -LiteralPath $memoryPath)) {
    @'
# Skill Memory

Persistent memory for universal improvements to the `unity-game` skill itself.

Use this file for repeatable lessons that should improve future Unity game-agent work across projects. Do not store project-specific decisions here; put those in the project's `Docs/AGENT_MEMORY.md`.

## Active Learnings

'@ | Set-Content -LiteralPath $memoryPath -Encoding UTF8
}

$date = Get-Date -Format "yyyy-MM-dd"
$entry = @"

### $date - $Category
- Trigger: $(Normalize-Line $Trigger)
- Learning: $(Normalize-Line $Learning)
- Apply when: $(Normalize-Line $ApplyWhen)
- Evidence: $(Normalize-Line $Evidence)
- Skill impact: $(Normalize-Line $SkillImpact)
"@

Add-Content -LiteralPath $memoryPath -Value $entry -Encoding UTF8
Write-Output "Appended skill memory entry to $memoryPath"
