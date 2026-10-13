param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [Parameter(Mandatory = $true)]
    [ValidatePattern("^[A-Za-z0-9][A-Za-z0-9_-]*$")]
    [string]$FeatureId,

    [Parameter(Mandatory = $true)]
    [string]$FeatureName,

    [string]$FeatureSlug = "",

    [string[]]$Tasks = @(),

    [string]$DocsRoot = "",

    # Explicit expanded records; independent QA normally writes in the compact brief.
    [switch]$DetailedTracking,

    # Backward compatible explicit request for separate QA_AGENT output.
    [switch]$CreateIndependentQa
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

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
if (-not [string]::IsNullOrWhiteSpace($DocsRoot)) {
    $docs = if ([System.IO.Path]::IsPathRooted($DocsRoot)) { $DocsRoot } else { Join-Path $project $DocsRoot }
} elseif ((Test-Path -LiteralPath (Join-Path $project "Assets/_source/Docs")) -and -not (Test-Path -LiteralPath (Join-Path $project "Docs"))) {
    $docs = Join-Path $project "Assets/_source/Docs"
} else {
    $docs = Join-Path $project "Docs"
}
$featuresDir = Join-Path $docs "Features"
$tasksDir = Join-Path $docs "Tasks"
$qaDir = Join-Path $docs "QA"
$qaAgentDir = Join-Path $docs "QA_AGENT"

$expandedTracking = $DetailedTracking -or $CreateIndependentQa
$requiredDirs = @($docs, $featuresDir)
if ($expandedTracking) { $requiredDirs += @($tasksDir, $qaDir) }
if ($CreateIndependentQa) { $requiredDirs += $qaAgentDir }
foreach ($dir in $requiredDirs) {
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
if ($Tasks.Count -eq 0) { $Tasks = @($FeatureName) }

$taskLinks = New-Object System.Collections.Generic.List[string]
$taskIndex = 1
foreach ($taskName in $Tasks) {
    $taskSlug = New-Slug $taskName
    $taskId = "TASK-$FeatureId-{0:D2}" -f $taskIndex
    $taskStem = "$taskId-$taskSlug"
    $taskFile = Join-Path $tasksDir "$taskStem.md"
    if ($expandedTracking) {
        $taskLinks.Add("- [ ] [$taskStem](../Tasks/$taskStem.md) - $taskName")
        Copy-TemplateIfMissing `
            -TemplatePath (Join-Path $templates "TASK.md") `
            -DestinationPath $taskFile `
            -Replacements @{
                "[TASK-NNN Name]" = "$taskId $taskName"
                "TASK-NNN-name.md" = "$taskStem.md"
                "FEAT-NNN-name.md" = "$featureStem.md"
            }
    } else {
        $taskLinks.Add("- [ ] $taskName")
    }

    $taskIndex++
}

$trackingLinks = "Compact brief: Developer and independent QA own the sections above."
if ($expandedTracking) {
    $trackingLinks = "- Expanded QA: [checklist](../QA/$featureStem-qa.md)"
    if ($CreateIndependentQa) {
        $trackingLinks += [Environment]::NewLine + "- Explicit legacy independent QA: [checklist](../QA_AGENT/$featureStem-qa.md)"
    }
}

Copy-TemplateIfMissing `
    -TemplatePath (Join-Path $templates "FEATURE.md") `
    -DestinationPath $featureFile `
    -Replacements @{
        "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
        "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
        "FEAT-NNN-name.md" = "$featureStem.md"
        "- [ ] [TASK-NNN-name](../Tasks/TASK-NNN-name.md) - [short purpose]" = ($taskLinks -join [Environment]::NewLine)
        "[TRACKING_LINKS]" = $trackingLinks
    }

if ($expandedTracking) {
    Copy-TemplateIfMissing `
        -TemplatePath (Join-Path $templates "QA_CHECKLIST.md") `
        -DestinationPath $qaFile `
        -Replacements @{
            "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
            "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
            "FEAT-NNN-name.md" = "$featureStem.md"
        }
}

if ($CreateIndependentQa) {
    Copy-TemplateIfMissing `
        -TemplatePath (Join-Path $templates "QA_AGENT_CHECKLIST.md") `
        -DestinationPath $qaAgentFile `
        -Replacements @{
            "[FEAT-NNN Name]" = "$FeatureId $FeatureName"
            "FEAT-NNN-name-qa.md" = "$featureStem-qa.md"
            "FEAT-NNN-name.md" = "$featureStem.md"
        }
}

Write-Output "[DONE] Feature docs created for $featureStem"
