# Parallel Unity Editors

Use isolated workspaces for concurrent features, scene/prefab authoring, tests and multiplayer checks.
They are **ON by default in `pro` when 2+ Unity-bound tasks run concurrently**, opt-in in `standard`,
and off in `fast`. A docs-only or file-only task does not need an Editor workspace.

## Ownership and isolation

One canonical project is the main git worktree. Each authoring task gets `<repo>.ws/<task>`, branch
`agent/<task>` from a chosen commit (default: the canonical worktree's current HEAD), its own Library,
Editor and registered MCP instance. One writer/operator owns each workspace; imports, assets, Play
Mode and tests serialize **inside it**. Other workspaces can operate concurrently.

**Uncommitted canonical changes do not appear in a worktree. Commit needed changes first, or select
an existing commit with `-Base`.** A copied Library is only a cache; Unity reconciles it with that
commit's files. Agents commit on their workspace branch; the orchestrator integrates after QA. The
helper never commits, merges into the canonical worktree, or deletes branches.

Before delegation, record workspace, branch/base, assigned agent, MCP identity, scene/prefab file
ownership and acceptance/QA evidence in the work brief. Two workspaces must not edit the same
scene/prefab. Give a shared asset one owner and integrate it before dependent authoring.

## Windows setup

1. Install the exact Editor in `ProjectSettings/ProjectVersion.txt`, Git for Windows, and the project's
   MCP adapter. Run the PowerShell commands below without elevation.
2. The **owner** creates storage, not the agent: Windows 11 **Settings → System → Storage → Advanced
   storage settings → Disks & volumes → Create Dev Drive**. Choose a new VHD or suitable unused space,
   and follow Windows' prompts. Creation can require owner/admin approval and at least 50 GB;
   the workspace helper does not create, format or resize volumes.
3. Close the canonical Editor and wait for its workers to exit. Copy the entire repository, including
   hidden `.git` and its existing Library, onto that Dev Drive. Keep the original until `git status`,
   remotes and an Editor launch at the destination are verified. Move before creating worktrees;
   moving an existing worktree tree needs git path repair. Set the new location in Unity Hub.
4. Put the default sibling `<repo>.ws` on the **same ReFS volume** as the source Library. A custom
   `-Root` on another volume cannot share the source's blocks.
5. Run `doctor`, configure Smart Merge below, and choose the local import-worker settings below.

Microsoft documents automatic Dev Drive block cloning from **Windows 11 24H2**. An older Moment 5
installation is not a documented guarantee. On supported same-volume ReFS copies, normal Windows
copy APIs (`Copy-Item`/`robocopy`) can share blocks until either copy changes them. The helper treats
same-volume ReFS on Windows build 26100+ as eligible when the source Editor is closed. This is a
capability hint, not proof of saved space; allow growth and verify the machine's actual behavior.
NTFS and cross-volume copies need full space. See [Microsoft Dev Drive setup and block cloning](https://learn.microsoft.com/en-us/windows/dev-drive/).

## Command reference (PowerShell 5.1)

Invoke the installed skill's `tools/unity-workspace.ps1` from the canonical Unity project, or supply
`-ProjectRoot <canonical-project>`. Below, `$wsTool` is the absolute path to that script, and
`$project` is the canonical project's absolute path. Names use lowercase letters/digits/hyphens,
start with a letter/digit, exclude Windows device names, and are at most 48 characters.
`-Root <dir>` overrides the default `<canonical>.ws` container; use the
same root on every command for those workspaces. Commands never modify canonical source files.

```powershell
& $wsTool doctor -ProjectRoot $project [-Root <dir>] [-EditorPath <Unity.exe>]
& $wsTool new -ProjectRoot $project -Name <task> [-Base <ref>] [-Root <dir>] [-NoLibrary] [-DiskMarginGB 2]
& $wsTool clone-tests -ProjectRoot $project -Name <n> [-Root <dir>] [-NoLibrary] [-DiskMarginGB 2]
& $wsTool open -ProjectRoot $project -Name <task> [-Root <dir>] [-EditorPath <Unity.exe>] [-ReserveGB 4] [-EditorGB 5]
& $wsTool test -ProjectRoot $project -Name <task> -Platform EditMode|PlayMode [-Filter <regex>] [-Category <c>] [-Root <dir>] [-EditorPath <Unity.exe>] [-ReserveGB 4] [-EditorGB 5]
& $wsTool status -ProjectRoot $project [-Root <dir>]
& $wsTool sync -ProjectRoot $project -Name <task> [-Root <dir>]
& $wsTool finish -ProjectRoot $project -Name <task> [-Root <dir>] -Confirm [-Remove]
```

Square brackets and `<...>` above are reference notation; replace values and omit unused options.
`-DiskMarginGB` defaults to 2 and controls the fixed disk reserve on creation. Eligible block clones
reserve 20% of logical Library size for changed blocks plus 120% of tracked checkout source bytes;
full-copy/import admission reserves 120% of Library and source bytes. Creation prints the measured
Library size, budget and cloning eligibility. `doctor` reports a Library-only **full-copy** estimate,
excluding checkout source size; it is not the creation command's eligible-clone budget.
`-ReserveGB` and `-EditorGB` configure memory. Import workers are not charged a full Editor
reservation each; their actual allocation is already included in measured free memory. Graceful
`finish` lets the parent Editor shut its workers down and waits for their exit.
The launch mutex uses the Windows global namespace to serialize RAM admission across sessions too.

Creation serializes disk admission, git checkout and Library copying per target volume, across
workspace roots/repositories. A machine-wide lock file keyed by volume identity lives under
`%ProgramData%/UnityGameAgent/VolumeLocks`; lack of write permission fails closed without elevation.
Waiting creators remeasure free disk after acquiring it (timeout: 10 minutes). OS handle ownership
decides whether a lock is held: stale metadata after a crash is recovered only after obtaining the
write handle. Never delete a held lock or use its age/PID alone to override it. Unrelated disk writers
and later imports/builds still need their own resource budget.

| Command | Behavior |
|---|---|
| `doctor` | Reports project Unity version, matching Hub Editor path or override, git worktree support, target filesystem/free disk, physical RAM/commit, Smart Merge and worker-setting hint |
| `new` | Creates branch/worktree, copies a quiescent Library and writes `.uga-workspace.json` with name, branch, base, created time, instance name and `kind=worktree` |
| `clone-tests` | Creates TEST-ONLY shared-source junctions and separate Library; manifest is `kind=test-clone` |
| `open` | Checks available physical memory and commit, then opens only the named workspace interactively |
| `test` | Refuses an open workspace Editor and checks memory; runs selected tests headlessly, reports NUnit pass/fail counts and exits nonzero for failed/invalid/empty runs |
| `status` | Lists branch, ahead/behind against base, dirty files, matching Editor process and Library logical size, plus disk/RAM totals |
| `sync` | Requires clean source and closed Editor; merges the recorded base ref's current changes into the workspace; never rebases published work |
| `finish` | Requires clean source; closing the matching Editor or removing files requires explicit `-Confirm`. Requests graceful close, refuses a still-open/unsaved/hung session; `-Remove` additionally removes that worktree/Library |

The helper's dirty checks filter its manifest and generated run artifacts. Keep them out of commits:
stage named source paths, not an unchecked `git add -A`; the helper does not modify git ignore files.
Branches always remain,
including branches with unmerged commits. A fixed commit used for `-Base` stays fixed during `sync`;
choose a branch ref when the workspace needs future base updates. Resolve any merge conflict in that
workspace, then repeat affected QA. `finish` does not merge: review and integration belong to the
orchestrator. `finish` **always refuses test clones**, even with confirmation flags.

Example for two feature tasks (PowerShell; no automatic commit/integration):

```powershell
& $wsTool doctor -ProjectRoot $project
& $wsTool new -ProjectRoot $project -Name inventory -Base main
& $wsTool new -ProjectRoot $project -Name arena -Base main
& $wsTool open -ProjectRoot $project -Name inventory
& $wsTool open -ProjectRoot $project -Name arena
# After inventory authoring is saved and its Editor is closed:
& $wsTool test -ProjectRoot $project -Name inventory -Platform EditMode -Category Inventory
& $wsTool status -ProjectRoot $project
# After agent commit, independent QA and orchestrator merge/review:
& $wsTool finish -ProjectRoot $project -Name inventory -Confirm -Remove
```

## Library, disk and RAM budgets

Close the canonical Editor before copying its Library; never copy a changing Asset Database. A running
source Editor makes the helper warn and select a fresh import instead of attempting a cache snapshot. Each
copy also checks the canonical `Temp/UnityLockfile`: a held/unverifiable lock skips copying with a
warning; an unlocked existing lock is held read-only during the copy. Canonical files are never created
or modified for this check. Process matching parses Windows arguments, including quoted option names;
Unity 6 `-adb2 -batchMode -noUpm -name AssetImportWorkerHW0` workers are recognized separately and
corroborated against their parent project's path when the parent is available. Each
workspace owns a real separate Library directory. The helper excludes `Library/Temp` and lock files;
`Library/ScriptAssemblies` may be copied. If no source exists or copying fails, it reports a normal
import fallback; a failed partial copy is retained as `.uga-failed-library-*` for inspection and later
explicit cleanup, while the workspace uses a fresh Library. First launch will cost time, RAM and disk.
`-NoLibrary` deliberately selects this
path. Keep enough disk for a new import as well as ongoing cache growth.

Let `L` be measured source Library bytes, `S` the tracked checkout source bytes (zero for junction
clones), `R` the free-memory reserve (4 GiB by default), and `E` the
estimated incremental memory of a new interactive Editor (5 GiB). These are scheduling estimates:
large projects and builds can consume more. `status` Library size is logical, not physical ReFS usage.

Both `open` and `test` hold a shared launch mutex while checking memory and starting Unity. For every
existing `Unity.exe`, admission subtracts any unrealized portion of its `EditorGB` budget from actual
free physical memory/commit, independently for each measure. A newly launched process therefore
reserves its future growth before its working set appears. Idle Editors also retain this conservative
reservation; actual free memory may need to exceed 9 GiB. `doctor`/`status` report actual available
memory, while launch admission uses these adjusted values.

Checkout admission counts selected-commit Git blob sizes **and** payload sizes recorded in Git LFS
pointers. Custom checkout/smudge filters can expand other files beyond this estimate; budget their
materialized size separately. No-cache imports and build outputs also need measured extra capacity.

| Resource | Default admission/budget | Example |
|---|---|---|
| Physical RAM before one more Editor/test process | Adjusted free physical RAM >= `R + E` | At least 9 GiB after existing-process growth reservations |
| Commit headroom before one more Editor/test process | Adjusted available commit >= `R + E` | At least 9 GiB after reservations; pagefile does not replace physical RAM |
| Two additional interactive Editors | Plan `R + 2E` free before launching either; recheck each launch | At least 14 GiB free initially |
| NTFS / cross-volume / unsupported OS / source Editor running | Free disk >= `1.2(L + S) + DiskMarginGB` | 20 GiB Library plus 5 GiB checkout requires 32 GiB |
| Eligible same-volume ReFS clone (Windows build 26100+, source Editor closed) | Free disk >= `0.2L + 1.2S + DiskMarginGB`; physical use grows as blocks change | 20 GiB Library plus 5 GiB checkout requires 12 GiB; initial clone data may use much less |
| No cache / failed copy | Fresh import plus source checkout, logs and build output | Measure this project's prior import; no universal bound |

Do not open an interactive Editor for a test or validation build. Run a headless process in a closed
workspace and let it exit. Schedule CPU/RAM-heavy tests/builds too; headless does not mean zero memory.
For tests the helper uses this Unity Test Framework command shape:

```powershell
& $editor -batchmode -nographics -projectPath $workspace -runTests -testPlatform EditMode -testResults $xml -logFile $log
# Add -testFilter <regex> and/or -testCategory <category> as needed; use PlayMode for runtime tests.
```

Do **not** add `-quit` to `-runTests`: the test runner owns completion/exit. Inspect both process status
and NUnit XML; missing XML, a crash or zero selected tests cannot pass. For validation builds, use the
project's existing build entry point headlessly with explicit exit/log handling; do not create an
Editor builder that authors gameplay assets. GPU/device/render-dependent QA still requires its
appropriate driver and evidence; a `-nographics` pass cannot prove visuals.

### Idle import workers: exact Unity 6 controls

Reduce idle worker retention locally, for example **Standby Import Worker Count = 0** and
**Idle Import Worker Shutdown Delay = 5 seconds**, then measure import responsiveness. The Unity 6
manual locates these controls under **Edit → Project Settings → Editor → Asset Pipeline**, not in
Preferences. [Unity's Editor settings reference](https://docs.unity3d.com/6000.0/Documentation/Manual/class-EditorManager.html#asset-pipeline)
lists those exact names. They are backed by `EditorUserSettings.standbyImportWorkerCount` and
`EditorUserSettings.idleImportWorkerShutdownDelayMilliseconds`: local user settings that can stay
outside version control. Keep this a local preference; do not change tracked ProjectSettings assets.
See [Unity's EditorUserSettings API](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/EditorUserSettings.html).

**Edit → Preferences → Asset Pipeline → Import Worker Count %** is the per-user default worker
allocation for **new projects**, not the idle shutdown delay. Lower it if appropriate for future
projects; it does not retroactively tune existing workspaces. This UI-location difference from the
requested Preferences route is deliberate documentation of Unity 6's actual controls.
[Unity's Asset Pipeline preferences](https://docs.unity3d.com/6000.0/Documentation/Manual/preferences-asset-pipeline.html)
documents that preference.

## MCP routing

Each Editor registers independently with the bridge, even when registrations share a bridge server.
Resolve live instances, match `.uga-workspace.json`'s `instanceName` to the project folder name, and
pin the candidate with `set_active_instance`. HTTP instance listing does not include project paths:
verify with a pinned read-only project-info call or read `UnityEngine.Application.dataPath` and compare
its normalized parent directory exactly with the workspace root. Use per-call `unity_instance` using
the current provider schema for shared clients. For resources that cannot be routed per call, use
separate sessions with independently pinned state; if state is global across sessions, serialize
selection, verification and the affected call. A missing/mismatched path blocks mutation.

Never mutate an unresolved or foreign instance. On a missing registration, reconnect that workspace;
do not select the canonical Editor as a fallback. Re-resolve after restarts or instance-ID changes.
The workspace marker is routing metadata, not an adapter registration command; wait for its Editor
and bridge to register. See [MCP setup](../mcp-commands.md) and [provider-neutral preflight](mcp-provider-neutral.md).

## Scene/prefab merges

Require text serialization and preserve `.meta` identities. Smart Merge assists conflict resolution;
it does not replace file ownership or visual QA. Only text/YAML `.asset` files use this driver; keep
binary asset rules intact. Use the project's matching Editor's `Data/Tools/UnityYAMLMerge.exe`.
[Unity's Smart Merge manual](https://docs.unity3d.com/6000.0/Documentation/Manual/SmartMerge.html)
describes the tool and argument order.

Run the following in **Git Bash**, in the **Unity project's** git repository, replacing the installed
version. These commands intentionally use Bash quoting to preserve the literal Git placeholders and
the executable path's quotes; do not paste them into Windows PowerShell 5.1.

```bash
git config --local merge.tool unityyamlmerge
git config --local mergetool.unityyamlmerge.trustExitCode false
git config --local mergetool.unityyamlmerge.cmd '"C:/Program Files/Unity/Hub/Editor/6000.0.XXf1/Editor/Data/Tools/UnityYAMLMerge.exe" merge -p "$BASE" "$REMOTE" "$LOCAL" "$MERGED"'
git config --local merge.unityyamlmerge.name 'Unity Smart Merge'
git config --local merge.unityyamlmerge.driver '"C:/Program Files/Unity/Hub/Editor/6000.0.XXf1/Editor/Data/Tools/UnityYAMLMerge.exe" merge -p %O %B %A %A'
```

Merge these entries into that project's `.gitattributes` without replacing existing policies:

```gitattributes
*.unity merge=unityyamlmerge
*.prefab merge=unityyamlmerge
*.asset merge=unityyamlmerge
```

`doctor` checks local tool/driver configuration and attribute routing; it does not write configuration
or tracked files. For remaining conflicts, invoke `git mergetool --tool=unityyamlmerge` and resolve
them deliberately. Inspect the resulting scenes/prefabs in the integration Editor, check missing
references and console, and rerun affected behavior. Syncing a workspace merges its base changes;
the orchestrator performs the reviewed final branch merge after QA.

## Shared-source tests and multiplayer

**TEST CLONES ARE NOT AUTHORING WORKSPACES. NEVER EDIT OR SAVE ASSETS IN THEM.**
`clone-tests` creates directory junctions to the canonical `Assets`, `Packages` and `ProjectSettings`
using PowerShell `New-Item -ItemType Junction` (equivalent to `mklink /J`, no admin requirement), plus
its own Library and a `kind=test-clone` marker.
It saves source checkout space but has no independent source branch. Saving a scene, prefab, setting,
package change or generated asset through those junctions writes into the canonical project.

Freeze canonical sources during a parallel test round. Use only tests/import hooks known not to
write shared sources; package resolution, version migrations and asset-writing tests are unsafe.
Never install packages or run editor authoring actions in a clone. Run `test` for headless validation;
`open` is only for an interactive multiplayer client under the same no-save rule. Distinct runtime
ports, accounts and save locations may be required; a separate Library does not isolate PlayerPrefs,
network ports or arbitrary `persistentDataPath` state. Record each client role in the brief.

For a Netcode project, prefer Unity's official **Multiplayer Play Mode** package when compatible and
already supported by its package/Editor versions; it provides local virtual players. See
[Unity Multiplayer Play Mode](https://docs.unity3d.com/Packages/com.unity.multiplayer.playmode@1.6/manual/index.html).
[ParrelSync](https://github.com/VeriorPies/ParrelSync) is the third-party shared-source alternative;
check its license/version and project compatibility before installation. Worktrees remain the choice
for independently edited feature sources.

`finish` refuses clones and cannot merge them. For manual cleanup, close only that clone's Editor,
resolve/check the absolute clone path against the workspace root, verify the three entries are
junctions to the expected canonical directories, unlink each junction **without traversing it**, then
remove only clone-local files/Library after explicit owner authorization. Never recursively delete a
clone while source junctions remain; never delete their targets.

## Troubleshooting and prohibitions

| Symptom | Action |
|---|---|
| RAM/commit gate refuses `open` | Close idle workspace Editors/workers, run tests headlessly, or change measured per-Editor budget deliberately; do not blindly suppress the gate |
| NTFS/cross-volume copy refuses disk budget | Free space, use `-NoLibrary` with an import budget, or let the owner relocate source and workspace root to one Dev Drive |
| ReFS copy still uses substantial space/time | Check OS support, same-volume paths and actual copy behavior; plan a full copy when cloning is unavailable |
| Eligible-clone budget was insufficient for the actual copy | Cloning is eligibility, not a guarantee; allow a full-copy/import budget, inspect any retained failed cache, and retry with adequate space |
| Library copy fails or source is absent | Read the reported import fallback and allow the first import to finish; do not share/junction Library |
| MCP instance is ambiguous/missing | Match project name and absolute path again; reconnect the assigned Editor, never guess |
| `sync` refuses or reports conflicts | Close its Editor, commit workspace changes, merge and resolve locally; no rebase or canonical reset |
| `finish` refuses dirty/unsaved/hung workspace | Save/commit explicitly, close it gracefully and retry; do not kill all Unity processes |
| Stale lock after crash | Verify no process owns that exact project path before removing only its stale lock |
| Headless selection is empty or XML missing | Fix test discovery/filter/platform or inspect the log; the run is not a pass |

Never run two Editors against one project path/Library; hardlink/junction a Library; concurrently copy
an active Library; author in a shared-source clone; let two workspaces own one scene/prefab; force-kill
all Editors; remove branches with unmerged work; or treat automatic Smart Merge as QA evidence.
