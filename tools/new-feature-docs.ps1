param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9][A-Za-z0-9_-]*$")]
    [string]$FeatureId,

    [Parameter(Mandatory = $true)]
    [string]$FeatureName,

    [string]$FeatureSlug = "",

    [string[]]$Tasks = @()
)

$ErrorActionPreference = "Stop"

function New-Slug {
    param([string]$Value)
    $slug = $Value.ToLowerInvariant()
    $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-")
    $slug = $slug.Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "feature"
    }
    return $slug
}

function Copy-TemplateIfMissing {
    param(
        [string]$TemplatePath,
        [string]$DestinationPath,
        [hashtable]$Replacements
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Write-Output "[SKIP] $DestinationPath already exists"
        return
    }

    $content = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
    foreach ($key in $Replacements.Keys) {
        $content = $content.Replace($key, [string]$Replacements[$key])
    }
    Set-Content -LiteralPath $DestinationPath -Value $content -Encoding UTF8
    Write-Output "[OK] $DestinationPath"
}

function Normalize-TaskList {
    param([string[]]$Values)

    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($value in $Values) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }
        foreach ($part in ([string]$value -split ",")) {
            $task = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($task)) {
                $normalized.Add($task)
            }
        }
    }
    return $normalized.ToArray()
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillRoot = Split-Path -Parent $scriptRoot
$templates = Join-Path $skillRoot "templates"

$project = Resolve-Path -LiteralPath $ProjectRoot
$docs = Join-Path $project "Docs"
$featuresDir = Join-Path $docs "Features"
$tasksDir = Join-Path $docs "Tasks"
$qaDir = Join-Path $docs "QA"
$qaAgentDir = Join-Path $docs "QA_AGENT"

foreach ($dir in @($docs, $featuresDir, $tasksDir, $qaDir, $qaAgentDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

if ([string]::IsNullOrWhiteSpace($FeatureSlug)) {
    $FeatureSlug = New-Slug $FeatureName
} else {
    $FeatureSlug = New-Slug $FeatureSlug
}

$featureStem = "FEAT-$FeatureId-$FeatureSlug"
$featureFile = Join-Path $featuresDir "$featureStem.md"
$qaFile = Join-Path $qaDir "$featureStem-qa.md"
$qaAgentFile = Join-Path $qaAgentDir "$featureStem-qa.md"
$Tasks = Normalize-TaskList $Tasks

$taskLinks = New-Object System.Collections.Generic.List[string]
$taskIndex = 1
foreach ($taskName in $Tasks) {
    $taskSlug = New-Slug $taskName
    $taskId = "TASK-$FeatureId-{0:D2}" -f $taskIndex
    $taskStem = "$taskId-$taskSlug"
    $taskFile = Join-Path $tasksDir "$taskStem.md"
    $taskLinks.Add("- [ ] [$taskStem](../Tasks/$taskStem.md) - $taskName")

    Copy-TemplateIfMissing `
        -TemplatePath (Join-Path $templates "TASK.md") `
        -DestinationPath $taskFile `
        -Replacements @{
            "[TASK-NNN Name]" = "$taskId $taskName"
            "TASK-NNN-name.md" = "$taskStem.md"
            "FEAT-NNN-name.md" = "$featureStem.md"
        }

    $taskIndex++
}

if ($taskLinks.Count -eq 0) {
    $taskLinks.Add("- [ ] [TASK-$FeatureId-01-task](../Tasks/TASK-$FeatureId-01-task.md) - [short purpose]")
}

Copy-TemplateIfMissing `
    -TemplatePath (Join-Path $templates "FEATURE.md") `
    -DestinationPath $featureFile `
    -Replacements @{
        "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
        "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
        "FEAT-NNN-name.md" = "$featureStem.md"
        "- [ ] [TASK-NNN-name](../Tasks/TASK-NNN-name.md) - [short purpose]" = ($taskLinks -join [Environment]::NewLine)
    }

Copy-TemplateIfMissing `
    -TemplatePath (Join-Path $templates "QA_CHECKLIST.md") `
    -DestinationPath $qaFile `
    -Replacements @{
        "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
        "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
        "FEAT-NNN-name.md" = "$featureStem.md"
    }

Copy-TemplateIfMissing `
    -TemplatePath (Join-Path $templates "QA_AGENT_CHECKLIST.md") `
    -DestinationPath $qaAgentFile `
    -Replacements @{
        "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
        "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
        "FEAT-NNN-name.md" = "$featureStem.md"
    }

Write-Output "[DONE] Feature docs created for $featureStem"
