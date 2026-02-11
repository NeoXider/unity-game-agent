#Requires -Version 5.1
<#
.SYNOPSIS
  On task complete: append block to current DEV_LOG and update DEV_STATE (with emoji).

.PARAMETER TaskTitle
  Completed task name.
.PARAMETER Description
  What was done.
.PARAMETER Files
  Affected files (comma-separated).
.PARAMETER Result
  Outcome summary.
.PARAMETER Screenshot
  Path, e.g. Docs/Screenshots/iter-01/screen.png.
.PARAMETER Stage
  Plan stage, e.g. "Stage 1".
.PARAMETER NextTask
  Next task for "In progress" in DEV_STATE.
.PARAMETER NextTaskDesc
  Short description for next task.
.PARAMETER ProgressProject
  M/T, e.g. "3/12".
.PARAMETER DocsPath
  Path to Docs. Default: 3 levels above script dir (repo root).
#>
param(
  [Parameter(Mandatory = $true)]
  [string] $TaskTitle,
  [string] $Description = "",
  [string] $Files = "",
  [string] $Result = "",
  [string] $Screenshot = "",
  [string] $Stage = "",
  [string] $NextTask = "",
  [string] $NextTaskDesc = "",
  [string] $ProgressProject = "",
  [string] $DocsPath = ""
)

$ErrorActionPreference = "Stop"

if (-not $DocsPath) {
  $scriptDir = Split-Path -Parent $PSCommandPath
  $skillRoot = Split-Path -Parent $scriptDir
  $DocsPath = [System.IO.Path]::GetFullPath((Join-Path $skillRoot "..\..\..\Docs"))
}

$devLogDir = Join-Path $DocsPath "DEV_LOG"
$devStatePath = Join-Path $DocsPath "DEV_STATE.md"

if (-not (Test-Path $devLogDir)) { Write-Error "DEV_LOG not found: $devLogDir. Run setup_project.bat first." }

$dateStr = Get-Date -Format "yyyy-MM-dd HH:mm"

$iterFiles = Get-ChildItem -Path $devLogDir -Filter "iteration-*.md" -File | Sort-Object Name -Descending
if (-not $iterFiles) { Write-Error "No iteration file in DEV_LOG. Run setup_project.bat or create iteration-01-YYYYMMDD-HHMM.md." }
$currentIterFile = $iterFiles[0].FullName
if ($iterFiles[0].BaseName -match "iteration-(\d+)") { $iterNum = $Matches[1] } else { $iterNum = "01" }

$logBlock = @"

### ✅ $TaskTitle$(if ($Stage) { " ($Stage)" })

- **Description:** $Description
- **Files:** $Files
- **Result:** $Result
$(if ($Screenshot) { "- **Screenshot:** ``$Screenshot```n" })- *Completed: $dateStr*

---
"@

$content = Get-Content -Path $currentIterFile -Raw -Encoding UTF8
$insertPoint = $content.IndexOf("## Completed tasks")
if ($insertPoint -lt 0) { $insertPoint = 0 }
$nl = $content.IndexOf("`n", $insertPoint)
$afterHeader = if ($nl -ge 0) { $nl + 1 } else { $content.Length }
$newContent = $content.Insert($afterHeader, $logBlock)
Set-Content -Path $currentIterFile -Value $newContent -Encoding UTF8 -NoNewline
Write-Host "[OK] Appended to $($iterFiles[0].Name)"

if (-not (Test-Path $devStatePath)) { Write-Host "[WARN] DEV_STATE.md not found."; return }

$stateContent = Get-Content -Path $devStatePath -Raw -Encoding UTF8

$stateContent = $stateContent -replace "(\*\*Updated:\*\*)\s*[^\n]+", "`${1} $dateStr"
$stateContent = $stateContent -replace "(\*\*Iteration:\*\*)\s*N\b", "`${1} $iterNum"

if ($ProgressProject -match "^\s*(\d+)\s*/\s*(\d+)\s*$") {
  $m = [int]$Matches[1]; $t = [int]$Matches[2]
  $pct = if ($t -gt 0) { [math]::Round(100 * $m / $t) } else { 0 }
  $barLen = 10
  $filled = [math]::Min($barLen, [math]::Floor($barLen * $m / [math]::Max(1, $t)))
  $bar = "|" + ("█" * $filled) + ("░" * ($barLen - $filled)) + "|"
  $stateContent = $stateContent -replace "(\*\*Project \(overall\):\*\*)\s*[^\n]+", "`${1} ${pct}% ``$bar`` ($m / $t tasks) · **Status:** 🟦"
}

$inProgressStart = $stateContent.IndexOf("## ⚙️ In progress")
$nextStart = $stateContent.IndexOf("## ⏭️ Next tasks")
if ($inProgressStart -ge 0 -and $nextStart -gt $inProgressStart) {
  $newInProgress = if ($NextTask) {
@"
## ⚙️ In progress

- 🟦 **Feature:** [Name] · **Task:** $NextTask  
  $NextTaskDesc  
  *Started: $dateStr*

  **Micro-plan:**
  1. [ ] ← [Current step]
  2. [ ] [Next step]

"@
  } else { @"
## ⚙️ In progress

- *(No active task. Pick next from DEV_PLAN.)*

"@ }
  $stateContent = $stateContent.Substring(0, $inProgressStart) + $newInProgress + "---`n`n" + $stateContent.Substring($nextStart)
}

Set-Content -Path $devStatePath -Value $stateContent -Encoding UTF8 -NoNewline
Write-Host "[OK] Updated DEV_STATE.md (emoji sections)."
