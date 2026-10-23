#requires -Version 5.1
# Creates missing Unity .meta files for unity-package/ with GUIDs derived from the package-relative
# path, so they are stable across machines. Existing .meta files are never changed. Git installs
# need every file to ship its .meta: the package cache is read-only and Unity cannot add them.
param([string]$PackageRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'unity-package'))
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $PackageRoot).Path.TrimEnd('\', '/')
$encoding = New-Object System.Text.UTF8Encoding $false
$md5 = [Security.Cryptography.MD5]::Create()
$tail = "  userData: `n  assetBundleName: `n  assetBundleVariant: `n"
$created = 0
try {
    foreach ($item in Get-ChildItem -LiteralPath $root -Recurse -Force | Where-Object { $_.Name -notlike '*.meta' }) {
        $meta = $item.FullName + '.meta'
        if (Test-Path -LiteralPath $meta) { continue }
        $relative = $item.FullName.Substring($root.Length + 1).Replace('\', '/')
        $guid = ([BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes('com.neoxider.uga-editor-broker/' + $relative))) -replace '-', '').ToLowerInvariant()
        if ($item.PSIsContainer) { $importer = "folderAsset: yes`nDefaultImporter:`n  externalObjects: {}`n" }
        elseif ($item.Extension -eq '.cs') { $importer = "MonoImporter:`n  externalObjects: {}`n  serializedVersion: 2`n  defaultReferences: []`n  executionOrder: 0`n  icon: {instanceID: 0}`n" }
        elseif ($item.Extension -eq '.asmdef') { $importer = "AssemblyDefinitionImporter:`n  externalObjects: {}`n" }
        elseif ($relative -eq 'package.json') { $importer = "PackageManifestImporter:`n  externalObjects: {}`n" }
        else { $importer = "TextScriptImporter:`n  externalObjects: {}`n" }
        [IO.File]::WriteAllText($meta, "fileFormatVersion: 2`nguid: $guid`n$importer$tail", $encoding)
        $created++
    }
} finally { $md5.Dispose() }
Write-Output "Created $created .meta file(s) under $root."
