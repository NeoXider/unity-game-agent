param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,
    [string]$AuthoringRoot = "Assets/_source"
)

$ErrorActionPreference = "Stop"

function Add-Finding {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Severity,
        [string]$Rule,
        [string]$Path,
        [string]$Message
    )
    $List.Add([pscustomobject]@{ Severity = $Severity; Rule = $Rule; Path = $Path; Message = $Message })
}

function Get-RelativeProjectPath {
    param([string]$FullPath, [string]$Root)
    $rootPrefix = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside expected root: $full"
    }
    return $full.Substring($rootPrefix.Length).Replace('\', '/')
}

function Get-CodeWithoutComments {
    param([string]$Text)
    $withoutBlocks = [regex]::Replace($Text, '/\*.*?\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    return [regex]::Replace($withoutBlocks, '(?m)//.*$', '')
}

$resolvedProject = (Resolve-Path -LiteralPath $ProjectRoot).Path
foreach ($required in @('Assets', 'Packages', 'ProjectSettings')) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedProject $required))) {
        throw "Not a Unity project root; missing $required at $resolvedProject"
    }
}

$sourceRoot = Join-Path $resolvedProject $AuthoringRoot
$findings = [System.Collections.Generic.List[object]]::new()
if (-not (Test-Path -LiteralPath $sourceRoot)) {
    Add-Finding $findings 'ERROR' 'STRUCTURE_ROOT' $AuthoringRoot 'Canonical authoring root is missing.'
} else {
    foreach ($requiredRoot in @('Scripts', 'Editor', 'Prefabs', 'Settings', 'Sprites')) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $requiredRoot))) {
            Add-Finding $findings 'ERROR' 'TYPED_ROOT' "$AuthoringRoot/$requiredRoot" 'Required typed root is missing.'
        }
    }
}

$editorRoot = Join-Path $sourceRoot 'Editor'
if (Test-Path -LiteralPath $editorRoot) {
    foreach ($file in Get-ChildItem -LiteralPath $editorRoot -Recurse -File -Filter '*.cs') {
        $relative = Get-RelativeProjectPath $file.FullName $resolvedProject
        $code = Get-CodeWithoutComments (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
        if ($file.BaseName -match '(?i)(?:Setup)?Builder$' -or $code -match '(?m)\bclass\s+\w*(?:Setup)?Builder\b') {
            Add-Finding $findings 'ERROR' 'EDITOR_BUILDER' $relative 'Tracked Editor Builder is forbidden; author assets directly or use a read-only validator.'
        }
    }
}

$scriptsRoot = Join-Path $sourceRoot 'Scripts'
if (Test-Path -LiteralPath $scriptsRoot) {
    $allowedScriptExtensions = @('.cs', '.asmdef', '.asmref', '.rsp', '.meta')
    foreach ($file in Get-ChildItem -LiteralPath $scriptsRoot -Recurse -File) {
        $relative = Get-RelativeProjectPath $file.FullName $resolvedProject
        if ($allowedScriptExtensions -notcontains $file.Extension.ToLowerInvariant()) {
            Add-Finding $findings 'ERROR' 'NON_CODE_IN_SCRIPTS' $relative 'Move non-code content to its typed asset root.'
        }
    }

    $testsRoot = Join-Path $scriptsRoot 'Tests'
    if (Test-Path -LiteralPath $testsRoot) {
        foreach ($file in Get-ChildItem -LiteralPath $testsRoot -Recurse -File -Filter '*.cs') {
            $relative = Get-RelativeProjectPath $file.FullName $resolvedProject
            $relativeToTests = Get-RelativeProjectPath $file.FullName $testsRoot
            if ($relativeToTests -notmatch '^[^/]+/(EditMode|PlayMode)/.+\.cs$') {
                Add-Finding $findings 'ERROR' 'TEST_LOCATION' $relative 'Tests must be under Scripts/Tests/<Feature>/EditMode or PlayMode.'
            }

            $code = Get-CodeWithoutComments (Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8)
            $mutationPattern = '\b(?:AssetDatabase\.(?:CreateAsset|DeleteAsset|MoveAsset|CopyAsset|SaveAssets)|PrefabUtility\.Save|EditorSceneManager\.(?:SaveScene|MarkSceneDirty)|Undo\.(?:AddComponent|RegisterCreatedObjectUndo))\b'
            if ($code -match $mutationPattern) {
                Add-Finding $findings 'ERROR' 'TEST_MUTATION' $relative 'Tests must not author or persist project assets/scenes.'
            }
            if ($code -match '\b(?:BindingFlags\.NonPublic|GetField\s*\(|GetMethod\s*\()' -or $code -match '\bFile\.(?:ReadAllText|ReadAllLines)\s*\(') {
                Add-Finding $findings 'WARN' 'TEST_VALUE_REVIEW' $relative 'Reflection/private-member or source-text assertion detected; keep only for a named regression that cannot be tested through behavior/public contract.'
            }
        }
    }
}

foreach ($typedRootName in @('Prefabs', 'Settings', 'Sprites', 'Animations', 'Audio', 'Materials', 'Models', 'Textures')) {
    $typedRoot = Join-Path $sourceRoot $typedRootName
    if (-not (Test-Path -LiteralPath $typedRoot)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $typedRoot -File | Where-Object Extension -ne '.meta') {
        $relative = Get-RelativeProjectPath $file.FullName $resolvedProject
        Add-Finding $findings 'ERROR' 'UNTYPED_ASSET_OWNERSHIP' $relative 'Place authored assets in a feature/screen subfolder, not directly in a global typed root.'
    }
}

if ($findings.Count -eq 0) {
    Write-Output "Project structure audit passed: $resolvedProject"
    exit 0
}

$findings | Sort-Object Severity, Rule, Path | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
$errorCount = @($findings | Where-Object Severity -eq 'ERROR').Count
$warningCount = @($findings | Where-Object Severity -eq 'WARN').Count
Write-Output "Project structure audit: errors=$errorCount warnings=$warningCount root=$resolvedProject"
if ($errorCount -gt 0) { exit 1 }
exit 0
