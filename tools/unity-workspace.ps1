#requires -Version 5.1
param(
    [Parameter(Position=0)][ValidateSet('doctor','new','clone-tests','open','test','status','sync','finish')][string]$Command = 'status',
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$Name,
    [string]$Base,
    [string]$Root,
    [string]$EditorPath,
    [switch]$NoLibrary,
    [ValidateSet('EditMode','PlayMode')][string]$Platform = 'EditMode',
    [string]$Filter,
    [string]$Category,
    [ValidateRange(0,1024)][double]$ReserveGB = 4,
    [ValidateRange(0.1,1024)][double]$EditorGB = 5,
    [ValidateRange(0,1024)][double]$DiskMarginGB = 2,
    [switch]$Remove,
    [switch]$Confirm
)

$ErrorActionPreference = 'Stop'

function Get-UgaFullPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($full -eq [IO.Path]::GetPathRoot($full)) { return $full }
    return $full.TrimEnd('\','/')
}

function Assert-UgaName([string]$Value) {
    if ($Value -cnotmatch '^[a-z0-9][a-z0-9-]{0,47}$' -or $Value -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])$') {
        throw 'Name must be 1-48 lowercase letters/digits/hyphens, starting with a letter/digit; no Windows device names.'
    }
}

function Assert-UgaPlainPath([string]$Path) {
    $cursor = Get-UgaFullPath $Path
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing reparse point in workspace path: $cursor"
            }
        }
        $parent = Split-Path -Parent $cursor
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Invoke-UgaGit([string]$At, [string[]]$Arguments) {
    # Windows PowerShell wraps even successful git progress on stderr as ErrorRecord.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -c core.quotepath=false -C $At @Arguments 2>&1)
        $gitExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($gitExit -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join ' ')" }
    return ($output -join "`n").Trim()
}

function Get-UgaSize([string]$Path) {
    [long]$bytes = 0
    if (Test-Path -LiteralPath $Path) {
        foreach ($item in Get-ChildItem -LiteralPath $Path -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Unexpected junction/symlink: $($item.FullName)" }
            if ($item.PSIsContainer) { $bytes += Get-UgaSize $item.FullName }
            else { $bytes += $item.Length }
        }
    }
    return $bytes
}

function Get-UgaDiskBudget([long]$LibraryBytes, [long]$SourceBytes, [double]$MarginGB, [bool]$BlockClone = $false) {
    $libraryFactor = 1.2
    if ($BlockClone) { $libraryFactor = 0.2 } # Reserve changed blocks; initial clone shares extents.
    return [long][math]::Ceiling($LibraryBytes * $libraryFactor + $SourceBytes * 1.2 + $MarginGB * 1GB)
}

function Test-UgaBlockClone([string]$FileSystem, [string]$SourceVolume, [string]$TargetVolume, [int]$Build) {
    return ($FileSystem -eq 'ReFS' -and $SourceVolume -and $SourceVolume -eq $TargetVolume -and $Build -ge 26100)
}

function Get-UgaCheckoutBytes([string]$At, [string]$Commit) {
    [long]$bytes = 0
    foreach ($line in ((Invoke-UgaGit $At @('ls-tree','-rl',$Commit)) -split "`n")) {
        if ($line -match '^\d+ blob [0-9a-f]+\s+(\d+)\t') { $bytes += [long]$Matches[1] }
    }
    # LFS pointer blobs are tiny but the checkout filter materializes the recorded payload size.
    # grep exit 1 means no matching pointers, not a git failure.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $pointers = @(& git -c core.quotepath=false -C $At grep -I -l -F -e 'version https://git-lfs.github.com/spec/v1' $Commit -- 2>&1)
        $grepExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($grepExit -gt 1) { throw "Cannot inspect checkout LFS sizes: $($pointers -join ' ')" }
    if ($grepExit -eq 0) {
        foreach ($pointer in $pointers) {
            $content = Invoke-UgaGit $At @('show',[string]$pointer)
            if ($content -match '(?m)^version https://git-lfs.github.com/spec/v1\r?$' -and $content -match '(?m)^size (\d+)\r?$') {
                $bytes += [long]$Matches[1]
            }
        }
    }
    return $bytes
}

function Assert-UgaDisk([long]$Required, [long]$Available) {
    if ($Available -lt $Required) { throw ('Insufficient disk: need {0:N2} GB including margin; free {1:N2} GB.' -f ($Required/1GB),($Available/1GB)) }
}

function Assert-UgaMemory([double]$PhysicalGB, [double]$CommitGB, [double]$Reserve, [double]$NewEditor) {
    $required = $Reserve + $NewEditor
    if ($PhysicalGB -lt $required -or $CommitGB -lt $required) {
        throw ('Refusing Editor launch: physical free {0:N2} GB, commit headroom {1:N2} GB; need {2:N2} GB ({3} reserve + {4} per Editor). Close an Editor or adjust -ReserveGB/-EditorGB.' -f $PhysicalGB,$CommitGB,$required,$Reserve,$NewEditor)
    }
}

function Get-UgaMemory {
    $os = Get-CimInstance Win32_OperatingSystem
    $performance = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
    if ($null -eq $performance.CommitLimit -or $null -eq $os.FreePhysicalMemory) { throw 'Cannot measure memory; refusing to guess.' }
    return [pscustomobject]@{ PhysicalGB = ([double]$os.FreePhysicalMemory * 1KB / 1GB); CommitGB = (([double]$performance.CommitLimit - [double]$performance.CommittedBytes) / 1GB) }
}

function Get-UgaLaunchMemory([double]$PhysicalGB, [double]$CommitGB, [double]$BudgetGB, [object[]]$Editors) {
    # Reserve unallocated portions too: a just-started Editor has not consumed its budget yet.
    # This also conservatively budgets idle Editors that may grow again during an import.
    foreach ($editor in $Editors) {
        if (Test-UgaImportWorker $editor.CommandLine $editor $Editors) { continue } # Actual worker allocations are already included in free memory.
        if ($null -eq $editor.WorkingSetSize -or $null -eq $editor.PageFileUsage) { throw 'Cannot budget an existing Unity process; refusing launch.' }
        $PhysicalGB -= [math]::Max(0, $BudgetGB - [double]$editor.WorkingSetSize / 1GB)
        $CommitGB -= [math]::Max(0, $BudgetGB - [double]$editor.PageFileUsage / 1MB)
    }
    return [pscustomobject]@{ PhysicalGB=$PhysicalGB; CommitGB=$CommitGB }
}

function Split-UgaCommandLine([string]$CommandLine) {
    if ([string]::IsNullOrWhiteSpace($CommandLine)) { return @() }
    if (-not ('Uga.NativeCommandLine' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace Uga {
    public static class NativeCommandLine {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr CommandLineToArgvW(string commandLine, out int count);
        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr memory);
        public static string[] Split(string commandLine) {
            int count;
            IntPtr memory = CommandLineToArgvW(commandLine, out count);
            if (memory == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
            try {
                string[] result = new string[count];
                for (int index = 0; index < count; index++)
                    result[index] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(memory, index * IntPtr.Size));
                return result;
            } finally { LocalFree(memory); }
        }
    }
}
'@
    }
    return [Uga.NativeCommandLine]::Split($CommandLine)
}

function Get-UgaOption([string[]]$Tokens, [string]$Option, [switch]$Multiple) {
    $values = @()
    for ($index = 1; $index -lt $Tokens.Count; $index++) {
        if ($Tokens[$index] -ieq $Option) {
            if ((-not $Multiple -and $values.Count -gt 0) -or $index + 1 -ge $Tokens.Count -or -not $Tokens[$index + 1]) { throw "Ambiguous or missing command-line value for $Option." }
            $values += $Tokens[$index + 1]
        }
    }
    return $values
}

function Get-UgaProcessProject([string]$CommandLine) {
    $tokens = @(Split-UgaCommandLine $CommandLine)
    $project = Get-UgaOption $tokens '-projectPath'
    if (-not $project) { return $null }
    if ($project -notmatch '^(?:[a-zA-Z]:[\\/]|\\\\)') { throw "Cannot resolve a non-absolute Unity project path: $project" }
    return Get-UgaFullPath $project
}

function Test-UgaImportWorker([string]$CommandLine, [object]$Process = $null, [object[]]$Processes = @()) {
    $tokens = @(Split-UgaCommandLine $CommandLine)
    if ($tokens -icontains '-assetImportWorker') { return $true }
    # Unity 6 appends -name AssetImport after -name AssetImportWorkerHW<n>.
    # Any worker-name value identifies the role; -projectPath stays single-valued.
    $workerNames = @(Get-UgaOption $tokens '-name' -Multiple)
    if (@($workerNames -imatch '^AssetImportWorker').Count -eq 0 -or $tokens -inotcontains '-batchMode' -or $tokens -inotcontains '-adb2' -or $tokens -inotcontains '-noUpm') { return $false }
    # Real Unity 6 workers carry a name, not -assetImportWorker. Corroborate the
    # parent when present; never infer a worker from parent PID or batchmode alone.
    $project = Get-UgaProcessProject $CommandLine
    if (-not $project) { return $false }
    if ($Process -and $Process.ParentProcessId) {
        $parents = @($Processes | Where-Object { $_.ProcessId -eq $Process.ParentProcessId })
        if ($parents.Count -gt 0) {
            if ($parents.Count -ne 1 -or -not $parents[0].CommandLine) { return $false }
            $parentProject = Get-UgaProcessProject $parents[0].CommandLine
            if ($parentProject -ne $project) { return $false }
        }
    }
    return $true # An orphan with the complete worker signature is still not a new Editor.
}

function Get-UgaVolume([string]$Path) {
    $probe = Get-UgaFullPath $Path
    while (-not (Test-Path -LiteralPath $probe)) { $probe = Split-Path -Parent $probe; if (-not $probe) { throw 'No existing target volume.' } }
    $volume = Get-Volume -FilePath $probe
    if (-not $volume -or $null -eq $volume.SizeRemaining) { throw 'Cannot measure target volume/free disk.' }
    return $volume
}

function Get-UgaEditorProcesses([string]$Path) {
    $expected = Get-UgaFullPath $Path
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'")) {
        if (-not $process.CommandLine) { throw "Cannot inspect Unity PID $($process.ProcessId); refusing unresolved process routing." }
        $candidate = Get-UgaProcessProject $process.CommandLine
        if ($candidate -and $candidate -eq $expected) { $process }
    }
}

function Get-UgaVolumeLockRoot {
    # Shared across repositories, workspace roots and Windows sessions. Fail closed
    # if this machine-wide directory is not writable; never request elevation.
    return Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'UnityGameAgent/VolumeLocks'
}

function Enter-UgaVolumeLock([string]$VolumeId, [int]$TimeoutSeconds = 600, [string]$LockRoot = (Get-UgaVolumeLockRoot)) {
    if (-not $VolumeId) { throw 'Cannot identify target volume for disk admission locking.' }
    Assert-UgaPlainPath $LockRoot
    New-Item -ItemType Directory -Path $LockRoot -Force | Out-Null
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $key = [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($VolumeId.ToUpperInvariant()))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    $file = Join-Path $LockRoot ($key + '.lock')
    Assert-UgaPlainPath $file
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $reported = $false
    while ($true) {
        $stream = $null
        try { $stream = [IO.File]::Open($file, 'OpenOrCreate', 'ReadWrite', 'Read') }
        catch [IO.IOException] {
            $reason = $_.Exception
            while ($reason.InnerException) { $reason = $reason.InnerException }
            $code = $reason.HResult -band 0xffff
            if ($code -notin @(32,33)) { throw }
            if (-not $reported) { Write-Host "Waiting for workspace disk admission/copy on volume $VolumeId."; $reported = $true }
            if ([DateTime]::UtcNow -ge $deadline) { throw "Timed out waiting for volume admission lock: $file. Never delete a held lock." }
            Start-Sleep -Milliseconds 200
            continue
        }
        try {
            # Acquiring the OS write handle proves the prior owner released it or
            # died. File existence, age and PID reuse cannot steal a held lock.
            if ($stream.Length -gt 0) { Write-Warning "Recovered stale/released volume lock metadata: $file" }
            $record = [ordered]@{ volume=$VolumeId; pid=$PID; processStartUtc=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o'); acquiredUtc=[DateTime]::UtcNow.ToString('o') } | ConvertTo-Json -Compress
            $bytes = [Text.Encoding]::UTF8.GetBytes($record)
            $stream.SetLength(0); $stream.Write($bytes,0,$bytes.Length); $stream.Flush()
            return $stream
        } catch { $stream.Dispose(); throw }
    }
}

function Exit-UgaVolumeLock([IO.FileStream]$Lock) {
    if ($Lock) { try { $Lock.SetLength(0); $Lock.Flush() } finally { $Lock.Dispose() } }
}

function Assert-UgaClosed([string]$Path) {
    if (@(Get-UgaEditorProcesses $Path).Count -gt 0) { throw "Workspace Editor is running: $Path. Close it gracefully before this command." }
    if (Test-Path -LiteralPath (Join-Path $Path 'Temp/UnityLockfile')) { throw "Unity lock exists at $Path. Verify no Editor uses it before manually clearing a stale lock." }
}

function New-UgaManifest([string]$Task, [string]$Branch, [string]$BaseRef, [string]$Commit, [string]$Canonical, [string]$Kind) {
    return [pscustomobject][ordered]@{
        name = $Task; branch = $Branch; base = $BaseRef; baseCommit = $Commit
        created = [DateTime]::UtcNow.ToString('o'); instanceName = $Task
        canonical = $Canonical; kind = $Kind
    }
}

function Get-UgaManifest([string]$Path, [string]$Task, [string]$Canonical) {
    Assert-UgaPlainPath $Path
    $file = Join-Path $Path '.uga-workspace.json'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "No workspace manifest: $Path" }
    Assert-UgaPlainPath $file
    $manifest = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.name -cne $Task -or $manifest.instanceName -cne $Task -or $manifest.canonical -ne $Canonical -or $manifest.kind -notin @('worktree','test-clone')) { throw 'Foreign or invalid workspace manifest.' }
    if ($manifest.kind -eq 'worktree') {
        if ($manifest.branch -cne "agent/$Task") { throw 'Unexpected workspace branch in manifest.' }
        $actual = Invoke-UgaGit $Path @('symbolic-ref','--short','HEAD')
        $top = Get-UgaFullPath (Invoke-UgaGit $Path @('rev-parse','--show-toplevel'))
        $common = Get-UgaFullPath (Invoke-UgaGit $Path @('rev-parse','--path-format=absolute','--git-common-dir'))
        $canonicalCommon = Get-UgaFullPath (Invoke-UgaGit $Canonical @('rev-parse','--path-format=absolute','--git-common-dir'))
        if ($actual -cne $manifest.branch -or $top -ne $Path -or $common -ne $canonicalCommon) { throw 'Workspace git identity does not match its manifest.' }
    } else {
        foreach ($folder in @('Assets','Packages','ProjectSettings')) {
            $entry = Get-Item -LiteralPath (Join-Path $Path $folder) -Force
            $expected = Get-UgaFullPath (Join-Path $Canonical $folder)
            if ($entry.LinkType -ne 'Junction' -or @($entry.Target).Count -ne 1 -or (Get-UgaFullPath @($entry.Target)[0]) -ne $expected) { throw "Test clone junction target is foreign or invalid: $folder" }
        }
    }
    return $manifest
}

function Get-UgaDirty([string]$Path) {
    # Generated state is local only. Never stage the marker or Unity caches.
    return Invoke-UgaGit $Path @('status','--porcelain','--untracked-files=all','--','.',':(exclude).uga-workspace.json',':(exclude)Library',':(exclude)Temp',':(exclude)Logs',':(exclude)UserSettings',':(exclude).uga-results',':(exclude).uga-failed-library-*')
}

function Get-UgaEditor([string]$Path, [string]$Override) {
    $versionText = Get-Content -LiteralPath (Join-Path $Path 'ProjectSettings/ProjectVersion.txt') -Raw
    $match = [regex]::Match($versionText, '(?m)^m_EditorVersion:\s*(\S+)')
    if (-not $match.Success) { throw 'Cannot read Unity version from ProjectVersion.txt.' }
    $version = $match.Groups[1].Value
    $candidates = @()
    if ($Override) { $candidates += $Override }
    else {
        foreach ($prefix in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)) {
            if ($prefix) { $candidates += (Join-Path $prefix "Unity/Hub/Editor/$version/Editor/Unity.exe") }
        }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return [pscustomobject]@{ Version=$version; Path=(Get-UgaFullPath $candidate) } }
    }
    return [pscustomobject]@{ Version=$version; Path=$null }
}

function Copy-UgaLibrary([string]$Canonical, [string]$Workspace, [bool]$Skip) {
    $source = Join-Path $Canonical 'Library'
    if ($Skip -or -not (Test-Path -LiteralPath $source)) { Write-Warning 'No Library copied; next open/test performs a normal import.'; return }
    if (@(Get-UgaEditorProcesses $Canonical).Count -gt 0) { Write-Warning 'Source Editor is running; cannot snapshot a changing Library safely. Falling back to normal import (close it before new to reuse the cache).'; return }
    $sourceGuard = $null
    try {
        $sourceLock = Join-Path $Canonical 'Temp/UnityLockfile'
        if (Test-Path -LiteralPath $sourceLock) {
            try {
                Assert-UgaPlainPath $sourceLock
                # Read-only access: do not create/change canonical files. Holding
                # this handle also prevents an unlocked stale file being reused.
                $sourceGuard = [IO.File]::Open($sourceLock, 'Open', 'Read', 'Read')
            } catch { Write-Warning 'Canonical Unity lock is held or cannot be verified; Library copy skipped. Falling back to normal import.'; return }
        }
        Assert-UgaPlainPath $source
        $destination = Join-Path $Workspace 'Library'
        $copyFailed = $false
        try {
            & robocopy $source $destination /E /XJ /R:0 /W:0 /COPY:DAT /DCOPY:DAT /XD (Join-Path $source 'Temp') /XF '*.lock' 'UnityLockfile' 'lock' /NFL /NDL /NJH /NJS /NP | Out-Host
            $copyFailed = $LASTEXITCODE -ge 8
        } catch { $copyFailed = $true; Write-Warning "Library copy error: $_" }
        if ($copyFailed) {
            # Keep failed data for inspection rather than deleting anything implicitly.
            if (Test-Path -LiteralPath $destination) { Move-Item -LiteralPath $destination -Destination (Join-Path $Workspace ('.uga-failed-library-' + [guid]::NewGuid().ToString('N'))) }
            Write-Warning 'Library copy failed; partial copy retained as .uga-failed-library-*. Next open/test performs a normal import.'
        } else { Write-Output 'Library copied (ScriptAssemblies included; Temp/locks excluded). ReFS may block clone; NTFS uses a full copy.' }
    } finally { if ($sourceGuard) { $sourceGuard.Dispose() } }
}

function Get-UgaTestResult([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw 'Unity produced no NUnit XML; inspect the log.' }
    $xml = New-Object System.Xml.XmlDocument
    $xml.XmlResolver = $null
    $xml.Load($Path)
    $run = $xml.DocumentElement
    if ($run.Name -notin @('test-run','test-results')) { throw 'Unrecognized NUnit XML root.' }
    if ($run.Name -eq 'test-run') {
        $total = [int]$run.GetAttribute('total'); $passed = [int]$run.GetAttribute('passed')
        $failed = [int]$run.GetAttribute('failed'); $skipped = [int]$run.GetAttribute('skipped')
        $ok = $run.GetAttribute('result') -in @('Passed','Success')
    } else {
        $total = [int]$run.GetAttribute('total'); $failed = [int]$run.GetAttribute('failures') + [int]$run.GetAttribute('errors')
        $skipped = [int]$run.GetAttribute('not-run'); $passed = $total - $failed - $skipped; $ok = $failed -eq 0
    }
    return [pscustomobject]@{ Passed=$passed; Failed=$failed; Skipped=$skipped; Total=$total; Success=($ok -and $failed -eq 0 -and $passed -gt 0) }
}

function ConvertTo-UgaNativeArgument([string]$Value) {
    # Windows CommandLineToArgvW escaping (including trailing backslashes).
    if ($Value -match "[\r\n\x00]") { throw 'Control characters are not valid command arguments.' }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Start-UgaUnity([string]$Executable, [string[]]$Arguments, [switch]$Interactive) {
    $argumentLine = ($Arguments | ForEach-Object { ConvertTo-UgaNativeArgument $_ }) -join ' '
    $windowStyle = 'Hidden'
    if ($Interactive) { $windowStyle = 'Normal' }
    $process = Start-Process -FilePath $Executable -ArgumentList $argumentLine -WindowStyle $windowStyle -PassThru
    $null = $process.Handle # Retain the exit-code handle even if the child exits immediately.
    return $process
}

function Invoke-UgaLaunch([string]$Executable, [string[]]$Arguments, [switch]$Interactive) {
    $mutex = New-Object Threading.Mutex($false, 'Global\UnityGameAgentEditorLaunch')
    $held = $false
    try {
        try { $held = $mutex.WaitOne(30000) } catch [Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'Another Editor launch is pending.' }
        $memory = Get-UgaMemory
        $editors = @(Get-CimInstance Win32_Process -Filter "Name = 'Unity.exe'")
        $available = Get-UgaLaunchMemory $memory.PhysicalGB $memory.CommitGB $EditorGB $editors
        Assert-UgaMemory $available.PhysicalGB $available.CommitGB $ReserveGB $EditorGB
        return Start-UgaUnity $Executable $Arguments -Interactive:$Interactive
    } finally { if ($held) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
}

function Invoke-UgaWorkspace {
    $canonical = Get-UgaFullPath $ProjectRoot
    Assert-UgaPlainPath $canonical
    $top = Get-UgaFullPath (Invoke-UgaGit $canonical @('rev-parse','--show-toplevel'))
    $worktreeList = Invoke-UgaGit $canonical @('worktree','list','--porcelain')
    $main = Get-UgaFullPath (($worktreeList -split "`n")[0].Substring(9))
    if ($top -ne $canonical -or $main -ne $canonical) { throw '-ProjectRoot must be the canonical/main git worktree and Unity project root.' }
    foreach ($required in @('Assets','Packages','ProjectSettings/ProjectVersion.txt')) {
        if (-not (Test-Path -LiteralPath (Join-Path $canonical $required))) { throw "Not a Unity project: missing $required" }
    }
    $container = $canonical + '.ws'
    if ($Root) { $container = Get-UgaFullPath $Root }
    if ($container -eq $canonical -or $container.StartsWith($canonical + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Workspace root must be outside the canonical worktree.' }
    Assert-UgaPlainPath $container
    $workspace = $null
    if ($Command -notin @('doctor','status')) { Assert-UgaName $Name; $workspace = Join-Path $container $Name; Assert-UgaPlainPath $workspace }
    if ($Remove -and $Command -ne 'finish') { throw '-Remove is valid only with finish.' }
    $lock = $null; $volumeLock = $null
    try {
        if ($workspace) {
            New-Item -ItemType Directory -Path $container -Force | Out-Null
            try { $lock = [IO.File]::Open((Join-Path $container ('.' + $Name + '.lock')), 'OpenOrCreate', 'ReadWrite', 'None') }
            catch { throw "Another operator holds workspace '$Name'." }
        }
        if ($Command -in @('doctor','status')) {
            $volume = Get-UgaVolume $container; $memory = Get-UgaMemory
            Write-Output ('Target {0}: filesystem={1}, disk free={2:N2} GB; RAM free={3:N2} GB, commit headroom={4:N2} GB.' -f $container,$volume.FileSystemType,($volume.SizeRemaining/1GB),$memory.PhysicalGB,$memory.CommitGB)
            Write-Output 'ReFS/Dev Drive: automatic block cloning eligible on Windows 11 24H2+, same volume, supported files. NTFS/cross-volume/unsupported copies: full copy. See parallel-editors.md for budgets.'
            if ($Command -eq 'doctor') {
                $editor = Get-UgaEditor $canonical $EditorPath
                Write-Output "Unity version: $($editor.Version); Editor: $($editor.Path)"
                if (-not $editor.Path) { Write-Warning 'Editor not found in Hub default paths; supply -EditorPath <Unity.exe>.' }
                Write-Output "Git worktrees supported: $main"
                $libraryBytes = Get-UgaSize (Join-Path $canonical 'Library')
                Write-Output ('Source Library logical size: {0:N2} GB; minimum Library-only budget + margin: {1:N2} GB.' -f ($libraryBytes/1GB),((Get-UgaDiskBudget $libraryBytes 0 $DiskMarginGB)/1GB))
                foreach ($key in @('merge.tool','mergetool.unityyamlmerge.cmd','mergetool.unityyamlmerge.trustExitCode','merge.unityyamlmerge.driver')) {
                    $value = & git -C $canonical config --get $key
                    if ($LASTEXITCODE -ne 0) { Write-Warning "Smart Merge missing: $key (see tools/parallel-editors.md)" }
                    else {
                        Write-Output "$key = $value"
                        if (($key -eq 'merge.tool' -and $value -cne 'unityyamlmerge') -or
                            ($key -eq 'mergetool.unityyamlmerge.trustExitCode' -and $value -cne 'false') -or
                            ($key -eq 'mergetool.unityyamlmerge.cmd' -and ($value -notmatch 'UnityYAMLMerge' -or $value -notmatch '\$BASE' -or $value -notmatch '\$MERGED')) -or
                            ($key -eq 'merge.unityyamlmerge.driver' -and ($value -notmatch 'UnityYAMLMerge' -or $value -notmatch '%O' -or $value -notmatch '%A' -or $value -notmatch '%B'))) {
                            Write-Warning "Smart Merge unexpected configuration: $key; compare parallel-editors.md."
                        }
                    }
                }
                if ($editor.Path -and -not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $editor.Path) 'Data/Tools/UnityYAMLMerge.exe'))) { Write-Warning 'UnityYAMLMerge.exe missing beside the selected Editor.' }
                $attributes = & git -C $canonical check-attr merge -- Assets/__uga_probe.unity Assets/__uga_probe.prefab Assets/__uga_probe.asset
                $attributes | Write-Output
                if (@($attributes | Where-Object { $_ -notmatch ': merge: unityyamlmerge$' }).Count) { Write-Warning 'Smart Merge .gitattributes incomplete; configure .unity/.prefab/.asset.' }
                Write-Output 'Unity 6 idle workers (local EditorUserSettings): Project Settings > Editor > Asset Pipeline > Standby Import Worker Count = 0; Idle Import Worker Shutdown Delay = 5 seconds. Preferences > Asset Pipeline > Import Worker Count % is a default for new projects. This script never changes settings; see parallel-editors.md.'
                return
            }
            if (Test-Path -LiteralPath $container) {
                foreach ($directory in Get-ChildItem -LiteralPath $container -Directory) {
                    if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName '.uga-workspace.json'))) { continue }
                    try {
                        Assert-UgaName $directory.Name
                        $manifest = Get-UgaManifest $directory.FullName $directory.Name $canonical
                        $dirty = 'shared-source; NEVER EDIT'; $ahead = '-'; $branch = '(test clone)'
                        if ($manifest.kind -eq 'worktree') {
                            $branch = $manifest.branch
                            $dirtyText = Get-UgaDirty $directory.FullName
                            $dirty = 0; if ($dirtyText) { $dirty = @($dirtyText -split "`n").Count }
                            $ahead = Invoke-UgaGit $directory.FullName @('rev-list','--left-right','--count',"HEAD...$($manifest.base)")
                        }
                        [pscustomobject]@{ Name=$directory.Name; Branch=$branch; AheadBehind=$ahead; DirtyFiles=$dirty; EditorRunning=(@(Get-UgaEditorProcesses $directory.FullName).Count -gt 0); LibraryGB=[math]::Round((Get-UgaSize (Join-Path $directory.FullName 'Library'))/1GB,2) }
                    } catch { Write-Warning "$($directory.Name): $_" }
                }
            }
            return
        }
        if ($Command -in @('new','clone-tests')) {
            if (Test-Path -LiteralPath $workspace) { throw "Workspace already exists: $workspace" }
            $baseRef = $Base
                if (-not $baseRef) { $baseRef = Invoke-UgaGit $canonical @('branch','--show-current') }
            $commitRef = 'HEAD'; if ($Base) { $commitRef = $Base }
            $commit = Invoke-UgaGit $canonical @('rev-parse','--verify','--end-of-options',"$commitRef^{commit}")
            if (-not $baseRef) { $baseRef = $commit }
            if (Get-UgaDirty $canonical) { Write-Warning 'Canonical uncommitted changes are NOT visible in a worktree. Commit first or choose a committed -Base. Test clones instead share current on-disk sources.' }
            $libraryBytes = 0
            if (-not $NoLibrary) { $libraryBytes = Get-UgaSize (Join-Path $canonical 'Library') }
            [long]$sourceBytes = 0
            if ($Command -eq 'new') {
                # Estimate selected commit, including a full tracked source checkout.
                $sourceBytes = Get-UgaCheckoutBytes $canonical $commit
                $tracked = Invoke-UgaGit $canonical @('ls-tree','--name-only',$commit)
                if (($tracked -split "`n") -contains 'Library' -or ($tracked -split "`n") -contains '.uga-workspace.json') { throw 'Base tracks Library or workspace metadata; refusing unsafe checkout.' }
            }
            $volume = Get-UgaVolume $container
            $volumeLock = Enter-UgaVolumeLock $volume.UniqueId
            # Re-measure only after the previous creator has finished its checkout
            # and cache copy. Hold the volume lock through all disk allocation.
            $volume = Get-UgaVolume $container
            $sourceVolume = Get-UgaVolume $canonical
            $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
            $blockClone = Test-UgaBlockClone ([string]$volume.FileSystemType) $sourceVolume.UniqueId $volume.UniqueId $build
            if (@(Get-UgaEditorProcesses $canonical).Count -gt 0 -or (Test-Path -LiteralPath (Join-Path $canonical 'Temp/UnityLockfile'))) { $blockClone = $false }
            $budget = Get-UgaDiskBudget $libraryBytes $sourceBytes $DiskMarginGB $blockClone
            Write-Output ('Library={0:N2} GB logical; disk budget={1:N2} GB; filesystem={2}; block clone eligible={3}.' -f ($libraryBytes/1GB),($budget/1GB),$volume.FileSystemType,$blockClone)
            if (-not $blockClone) { Write-Warning 'Full Library copy/import budget required (NTFS, cross-volume, unsupported OS, or source Editor running).' }
            Assert-UgaDisk $budget $volume.SizeRemaining
            $branch = "agent/$Name"; $kind = 'worktree'
            if ($Command -eq 'new') { Invoke-UgaGit $canonical @('worktree','add','-b',$branch,$workspace,$commit) | Write-Output }
            else {
                $branch = $null; $kind = 'test-clone'
                New-Item -ItemType Directory -Path $workspace | Out-Null
            }
            $manifest = New-UgaManifest $Name $branch $baseRef $commit $canonical $kind
            $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $workspace '.uga-workspace.json') -Encoding UTF8
            if ($kind -eq 'test-clone') {
                foreach ($folder in @('Assets','Packages','ProjectSettings')) {
                    New-Item -ItemType Junction -Path (Join-Path $workspace $folder) -Target (Join-Path $canonical $folder) | Out-Null
                }
                Write-Warning 'TEST CLONE: Assets/Packages/ProjectSettings are canonical junctions. NEVER EDIT OR SAVE ASSETS. finish/merge refused. Freeze source writers during tests.'
            }
            Copy-UgaLibrary $canonical $workspace $NoLibrary.IsPresent
            Write-Output "Workspace: $workspace; kind=$kind; MCP instance project name=$Name. Resolve exact path/instance ID before mutation."
            return
        }
        $manifest = Get-UgaManifest $workspace $Name $canonical
        if ($Command -eq 'finish' -and $manifest.kind -eq 'test-clone') { throw 'Test clone: finish/merge is forbidden. Remove junctions manually without traversing their targets; see parallel-editors.md.' }
        switch ($Command) {
            'sync' {
                if ($manifest.kind -ne 'worktree') { throw 'Test clone: sync/merge is forbidden.' }
                Assert-UgaClosed $workspace
                if (Get-UgaDirty $workspace) { throw 'Workspace is dirty; commit before sync.' }
                Invoke-UgaGit $workspace @('merge','--no-edit','--',$manifest.base) | Write-Output
            }
            'finish' {
                if (Get-UgaDirty $workspace) { throw 'Workspace is dirty; commit before finish.' }
                $editors = @(Get-UgaEditorProcesses $workspace)
                if (($Remove -or $editors.Count -gt 0) -and -not $Confirm) { throw 'Closing an Editor/removing a worktree requires explicit -Confirm; deletion also requires -Remove.' }
                foreach ($editor in $editors) {
                    if (Test-UgaImportWorker $editor.CommandLine $editor $editors) { continue } # Parent Editor owns worker shutdown.
                    $process = Get-Process -Id $editor.ProcessId
                    if (-not $process.CloseMainWindow() -or -not $process.WaitForExit(30000)) { throw 'Editor did not close gracefully (possibly unsaved state). Save/close it manually; no force kill performed.' }
                }
                if ($editors.Count -gt 0) {
                    $deadline = [DateTime]::UtcNow.AddSeconds(10)
                    while (@(Get-UgaEditorProcesses $workspace).Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 200 }
                }
                Assert-UgaClosed $workspace
                if (Get-UgaDirty $workspace) { throw 'Editor closure changed files; commit before finish.' }
                if ($Remove) {
                    Assert-UgaPlainPath $workspace
                    # Validate the complete deletion tree before git removes ignored caches.
                    $null = Get-UgaSize $workspace
                    Invoke-UgaGit $canonical @('worktree','remove','--force',$workspace) | Write-Output
                }
                Write-Output "Finished $Name. Branch $($manifest.branch) retained; orchestrator merges after QA. No branch is ever deleted."
            }
            'open' {
                if ($manifest.kind -eq 'test-clone') { Write-Warning 'TEST CLONE: multiplayer/test use only. NEVER EDIT OR SAVE ASSETS, PACKAGES OR PROJECT SETTINGS.' }
                Assert-UgaClosed $workspace
                $editor = Get-UgaEditor $workspace $EditorPath
                if (-not $editor.Path) { throw 'Matching Unity Editor not found; pass -EditorPath.' }
                $process = Invoke-UgaLaunch $editor.Path @('-projectPath',$workspace) -Interactive
                Write-Output "Editor PID=$($process.Id); pin MCP to $($manifest.instanceName) at $workspace."
            }
            'test' {
                Assert-UgaClosed $workspace
                $editor = Get-UgaEditor $workspace $EditorPath
                if (-not $editor.Path) { throw 'Matching Unity Editor not found; pass -EditorPath.' }
                $resultsRoot = Join-Path $workspace '.uga-results'
                Assert-UgaPlainPath $resultsRoot
                New-Item -ItemType Directory -Path $resultsRoot -Force | Out-Null
                $stamp = [guid]::NewGuid().ToString('N')
                $xml = Join-Path $resultsRoot "$stamp.xml"; $log = Join-Path $resultsRoot "$stamp.log"
                $arguments = @('-batchmode','-nographics','-projectPath',$workspace,'-runTests','-testPlatform',$Platform,'-testResults',$xml,'-logFile',$log)
                if ($Filter) { $arguments += @('-testFilter',$Filter) }
                if ($Category) { $arguments += @('-testCategory',$Category) }
                $process = Invoke-UgaLaunch $editor.Path $arguments
                $process.WaitForExit()
                $exitCode = $process.ExitCode
                Write-Output "NUnit XML: $xml; Editor log: $log; Unity exit=$exitCode"
                $result = Get-UgaTestResult $xml
                Write-Output "Passed=$($result.Passed) Failed=$($result.Failed) Skipped=$($result.Skipped) Total=$($result.Total)"
                if ($exitCode -ne 0 -or -not $result.Success) { throw 'Unity tests failed or selection was empty/all skipped; inspect XML and full log.' }
            }
        }
    } finally { try { Exit-UgaVolumeLock $volumeLock } finally { if ($lock) { $lock.Dispose() } } }
}

# Dot-source for the Pester-free pure/refusal tests; no Unity/process/filesystem activity on import.
if ($MyInvocation.InvocationName -ne '.') {
    try { Invoke-UgaWorkspace }
    catch { Write-Error $_ -ErrorAction Continue; exit 1 }
}
