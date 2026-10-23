# Shared Editor Sessions (several agents, one Unity Editor)

The default way to run two or more agents on one Unity project on one machine. Every agent works
in the **same project folder, on the same branch, against the same open Editor**. A broker inside the
Editor turns the Editor into a scheduled resource: agents hold leases on what they edit, and
everything that stalls the whole Editor (import + compile, Play Mode, tests, packages, builds) runs in
batched windows. Requires **Unity 6 (6000.0) or newer**.

Components:

- `com.neoxider.uga-editor-broker` (this skill's `unity-package/`): Editor-only package that executes
  windows, writes the heartbeat and shows the board (**Window > Unity Game Agent > Editor Broker**).
- [`editor-broker.ps1`](editor-broker.ps1): the agents' channel. It keeps working while the Editor
  compiles, reloads, plays or is closed, because all state lives in `<project>/Library/UgaBroker`.
  Written for Windows PowerShell 5.1 and PowerShell 7+ (`pwsh` on macOS/Linux); tested on Windows
  PowerShell 5.1.
- Optional `uga_broker` command for MCP for Unity (CoplayDev) and for the Unity CLI (Pipeline
  package), compiled only when that adapter is installed.

Use [isolated workspaces](parallel-editors.md) instead only when tasks truly need separate branches,
different package sets or simultaneous Play Mode.

## Orchestrator preflight (multi-agent modes)

Run this once before delegating to two or more agents, after the normal preflight in
[mcp-provider-neutral.md](mcp-provider-neutral.md). `$broker` is the absolute path of this skill's
`tools/editor-broker.ps1`; pass `-ProjectRoot` (or set `UGA_PROJECT_ROOT`) on every call.

```powershell
& $broker doctor -ProjectRoot $project -Fix   # installs the package, requests project settings
& $broker doctor -ProjectRoot $project        # must end with READY
& $broker session start -Agent lead -ProjectRoot $project
& $broker status -ProjectRoot $project        # the board
& $broker say -Agent lead -Message 'Split: core owns Assets/Scripts/Core/, ui owns Assets/UI/, qa runs the tests.' -ProjectRoot $project
```

Give every agent its name, role and leases in its work brief, and tell it to start each step with
`brief` (see [Team brief and board](#team-brief-and-board)).

`doctor` checks and reports:

| Check | Fix |
|---|---|
| Unity 6+ (`ProjectSettings/ProjectVersion.txt`) | Upgrade; the broker refuses older Editors |
| Broker package installed and matching this skill | `install` embeds it in `Packages/` (`-Mode git` writes a git URL instead) |
| Live Editor heartbeat (`Library/UgaBroker/editor.json`) | Open the project; wait for import |
| Project settings: Enter Play Mode Options with **Disable Domain Reload**, parallel import | `-Fix` asks the Editor to apply them, saves `ProjectSettings/EditorSettings.asset`, then runs one smoke Play Mode; errors in that run roll the option back |
| Asset serialization Force Text, Visible Meta Files | Reported only; never changed silently |
| MCP for Unity transport | Must be **HTTP**: with stdio every new client disconnects the others |
| Unity CLI Pipeline port file | Present when the Pipeline package runs |
| Other live brokers, free RAM, git branch | Information for multi-project machines |

`session start` applies per-user Editor preferences and `session stop` restores them:

| Preference | Session value | Why |
|---|---|---|
| Auto Refresh (`kAutoRefreshMode`) | Disabled | Files written by agents are not imported until a sync window |
| Directory Monitoring | Off | Same |
| Script Changes While Playing | Recompile After Finished Playing | A sync never interrupts a Play Mode run |
| Interaction Mode | No Throttling | An unfocused Editor keeps ticking |
| Standby Import Worker Count | 1 (Unity default 2; Unity rejects 0) | Each import worker is a Unity process of about 1 GB |
| Idle Import Worker Shutdown Delay | 10 s (Unity default 60 s) | Workers exit soon after a sync window |

The first four belong to the user, not the project. When several projects run sessions on one
machine, the first session backs them up and the **last** session to stop restores them. The import
worker values live in the project's untracked `UserSettings/` and are restored per project.

## Lanes and order of operations

| Priority | Lane | What | Parallelism | Opens when |
|---|---|---|---|---|
| 1 | cold | Work on leased resources: prefabs (isolated contents), ScriptableObjects, materials, animation, UI Toolkit files, writing staged files, small imports of your own non-script files | Many agents; conflict only on overlapping resources | Always |
| 1b | focus | Scene-graph edits and Scene/Game view captures; the broker makes your scene the active one | One holder, max 3 min per hold while others wait, FIFO | When no window runs |
| 2 | sync | Publish staged files, import, one `Refresh`, one compile | One window for every requester | Requests exist and (oldest waited 30 s, or every lease holder yielded, or a hot window is due) |
| 3 | hot | All test selections of one mode in a single Test Runner execution, then Play Mode sessions one by one | Exclusive | Cold work is quiet, or the oldest hot request waited 10 min, or 3 hot requests are queued; never while scripts fail to compile |
| 4 | exclusive | Changes that recompile, reimport or reload for everyone: packages, scripting defines, build target, color space or graphics API, builds, merges into the folder | One holder | After every other agent yields, or after 2 min |

Before a window starts the broker **drains**: it waits until every lease holder (except the window's
holder) has called `yield`, at most 60 s. Then the window runs and agents calling `gate` hear `wait`.

Inside a sync window: publish every requester's staging folder into the project, import explicit
paths in one batch, `Refresh` (which compiles), wait for compile and reload, then attribute results:
a requester whose files broke the build gets `failed` with the compiler errors; the others get
`blocked` (their files are in place and load after the next clean compile); everyone else `passed`.

## Leases

```powershell
& $broker take    -Agent ui-1 -Resource folder:Assets/UI/Shop/ -ProjectRoot $project
& $broker take    -Agent level -Resource scene:Assets/Scenes/Arena.unity -ProjectRoot $project
& $broker take    -Agent level -Kind focus -Resource scene:Assets/Scenes/Arena.unity -ProjectRoot $project
& $broker renew   -Agent ui-1 -ProjectRoot $project      # default lease: 15 min
& $broker release -Agent ui-1 -ProjectRoot $project      # all of ui-1's leases
```

- Resources: `scene:`, `prefab:`, `asset:` (one file), `folder:` (everything below), `asmdef:<name>`
  (the folder of that assembly). Paths start with `Assets/` or `Packages/`; `asset:` also takes one
  `ProjectSettings/` file. Matching ignores case.
- **Settings without a window.** A settings file whose change triggers no compile, import or domain
  reload is cold work under a lease on that file: Build Settings scene list
  (`asset:ProjectSettings/EditorBuildSettings.asset`), tags and layers (`TagManager.asset`), input
  axes, time or physics values. You decide: take the lease and edit it, and request an exclusive
  window only when the change recompiles, reimports or reloads for everyone (packages, scripting
  defines, build target, color space, graphics API).
- Overlapping leases of different agents conflict; the later request waits in FIFO order and never
  jumps an earlier waiter. `take -Wait` blocks until granted. Exit code 3 means queued.
- `focus` needs a cold lease on the same scene. Only one agent holds focus at a time.
- Hold leases only while you work. Expired leases (TTL) are dropped automatically.

## The agent loop

```text
brief -> take leases -> loop { gate (exit 0 = go, 4 = wait) -> one short batch of Editor calls -> save your own assets }
      -> stage compiled/heavy files -> request sync -> yield -> keep working on your next task
      -> brief again after a window, a result or a new message; say what the others must know
      -> request hot tests/session when behavior must be proven -> release when done
```

- **Start every step with `brief`.** It shows who else works here, what the queue holds and roughly
  when your job runs, and what the others asked of you.
- **A request is not a pause.** After `request` keep working: the next file, the next test, the next
  part of your task, reviews of what is already done. Look at the job with `status -Job <id>` when you
  actually need its result. Waiting idle is only for the moment nothing else is left.
- `gate` before each batch of Editor calls. `yield` whenever you stop touching the Editor (reading,
  thinking, writing files): it lets windows start without waiting for the drain deadline.
- Save only your own scene/prefab/asset. Never "save all": it saves other agents' half-done work.
- **Background waiting** (only when nothing else is left): run `request ... -Wait` (or
  `wait -Job <id>`) as a background task and end your turn; the process exits with the result. Exit
  codes: 0 passed, 8 failed, 9 blocked/canceled, 6 timeout, 7 Editor offline.

## Team brief and board

Agents in one Editor should know about each other. Two commands give them that:

```powershell
& $broker brief -Agent ui -ProjectRoot $project       # team, queue with ETA, your leases, new messages
& $broker brief -Agent ui -Role ui -Doing 'upgrade screen' -ProjectRoot $project
& $broker say -Agent core -Message 'Renamed ScoreModel.Add to AddPoints; update callers.' -ProjectRoot $project
& $broker say -Agent qa -To ui -Message 'Upgrade tooltip overlaps at 1280x720.' -ProjectRoot $project
```

- **Roster.** Every agent command (`take`, `gate`, `request`, `brief`, `say` and the rest) records
  the agent and when it was last seen. `-Role` and a one-line `-Doing` (accepted by any agent
  command) tell the others what it is and what it works on now. The brief lists every agent with its
  leases, waiting requests and jobs, including agents known only from their leases. An agent quiet
  for 2 hours that holds nothing drops out.
- **Queue and ETA.** The brief lists the active window and the queued jobs in the order the scheduler
  runs them (one sync window, each exclusive request, one hot window with the tests first) with a
  rough start and finish. The estimate uses this project's telemetry (average window run, drain and
  wait per lane) and default guesses until there is some. `request` prints the same ETA for the new
  job. It is an estimate: a sync request made later still goes before waiting hot work, and sessions
  are counted at their full time box.
- **Team board.** `Library/UgaBroker/team-board.md` is a Markdown log, one
  `### M<n> <UTC time> <from> -> <to>` heading per message. `say` appends under the state lock, so
  agents never overwrite each other; do not edit the file by hand. `-To` takes agent names separated
  by commas; the default is everyone (`all`). The human posts from the board window (**Team** section).
- **Short by design.** Every brief lands in an agent's context, so a message is one note of up to
  300 characters; put details in a file and post its path. The brief stays compact: one line per
  agent, per queued job and per message (the latest 5).
- **Unread.** The brief shows the messages for you since your previous brief (the latest 5, one line
  each; the rest stay in the file) and marks them read. Other commands print `Team board: N new message(s) for you`
  while something waits.
- **What to post:** interface changes others call (renames, signatures, events), handoffs ("Shop
  prefab ready for QA"), blockers and questions to a named agent, and the result of a check someone
  asked for. Skip progress chatter: the roster and the queue already show it.

Over MCP the `uga_broker` tool does the same with `action: brief` or `action: say` (`message`, `to`,
`role`, `doing`).

## Staging: compiled and heavy files

Many MCP tools call `AssetDatabase.Refresh()` on their own (creating assets, saving scenes, editing
prefab contents). A refresh imports **every** changed file under `Assets/`, so a half-written script of
another agent would compile in the middle of everyone's work. Therefore:

- `.cs`, `.asmdef`, `.asmref`, `.dll`, `.rsp`, models, large or batch imports are written to your
  staging folder `Library/UgaBroker/staging/<agent>/Assets/...`, never directly to `Assets/`.
- `stage -Agent <a> -Path Assets/Game/Combat/Hit.cs` copies the current file there and prints the
  path to edit; add `-New` for a new file. Staging works only inside your lease.
- `request -Lane sync -Agent <a>` publishes the staging folder in the next sync window. Add
  `-Paths` to reimport files already under your lease (for example after import-setting changes).
- A compiled file imported outside a sync window is reported on the board.
- Small non-script assets of your own (a texture, a sound, a ScriptableObject) may be imported in the
  cold lane with a single-asset import of that path.

## Hot work: tests and Play Mode

```powershell
& $broker request -Agent qa -Lane hot -Tests 'category:Smoke; name:Game.Tests.ShopTests.Buy' -ProjectRoot $project -Wait
& $broker request -Agent qa -Lane hot -Tests 'assembly:Game.EditTests' -TestMode EditMode -ProjectRoot $project
& $broker request -Agent qa -Lane hot -JobKind session -Scene Assets/Scenes/Shop.unity -Minutes 3 -ProjectRoot $project
& $broker done -Agent qa -Job J42 -ProjectRoot $project      # end your session early
```

- Selections: `name:`, `group:` (regex), `category:`, `assembly:`; clauses separated by `;`. A run that
  matched no test fails: an empty selection is not a pass.
- A session opens the scene, enters Play Mode and gives you a time box (up to 30 min). Drive it with
  your adapter's input/capture tools; stop Play Mode or call `done` when finished. Console errors of
  the session are attached to the job; the verdict about behavior is yours.
- Unsaved scenes block hot windows (Test Runner would show a modal save dialog). Save before yield.

## Exclusive work

`request -Lane exclusive -Reason 'Add Input System package' -Minutes 10`, then `wait` until your job is
`running`; during the window you alone may change packages, scripting defines, the build target, run
a build or merge a branch into the folder. Call `done` when finished; the broker refreshes the project
and reports compile errors.

An exclusive window stops every other agent, so it is for changes that need it. Editing the Build
Settings scene list, tags and layers or other settings that do not recompile or reimport is cold work
under a lease on that settings file (see Leases).

## Telemetry

The Editor counts how the team shares it, per project, and `stats` shows it:

```powershell
& $broker stats -ProjectRoot $project          # current session, per agent and per lane, project totals
& $broker stats -ProjectRoot $project -Json    # the same for scripts and dashboards
```

| Number | Meaning |
|---|---|
| Wait per job (avg, max), per agent and per lane | From `request` to the start of its window (includes the drain) |
| Run per job | From the window start to the job's result |
| Queue length (time-weighted average, peak) | Jobs waiting for a window |
| Lease waiters (average, peak) and lease wait (avg, max) | Agents queued behind another agent's lease |
| Windows (count, run avg/max, drain avg) | How often the Editor was taken away and for how long |
| Failed / blocked / canceled jobs | Compile breaks and their knock-on effect |

Live counters sit in `state.json`; when a session starts or stops, the finished segment is appended
to `Library/UgaBroker/telemetry.jsonl`, so the project keeps its history across sessions. The board
shows the live numbers. Use them to tune the split: long lease waits mean overlapping ownership, a
long queue or drain means agents hold the Editor without `yield`, frequent exclusive windows mean
work that could be cold. The ETA in `brief` and `request` is computed from the same numbers.

## Splitting work between agents

The orchestrator decides the split; resources must not overlap.

- **Programmers:** by assembly (`asmdef:` lease) when assembly definitions match the task boundaries;
  otherwise by feature folder (`folder:` lease); an epic is a set of feature folders owned by one
  programmer. Two programmers never share an assembly or folder. Compile errors are routed to the
  owner by file path.
- **Scene builders:** one scene each (cold lease); scene-graph edits need the focus token.
- **UI:** one screen folder each; UI Toolkit UXML/USS are text and need the Editor only for capture.
- **QA:** no leases; requests hot windows and reads results.
- Blind code agents may work in a git worktree with plain C# and `dotnet test` (no Editor); their
  branch enters the shared folder through an exclusive window (merge) followed by a sync.

## One folder, one branch

All agents share the project folder and the session branch. Do not switch branches, reset or pull in
that folder during a session (a reimport for everyone); merges go through an exclusive window.
Commit only your own paths (`git commit -- <paths>`), never `git add -A`.

## Several projects on one machine

Each project has its own Editor, broker, state, leases and queues; they never block each other.

- Give every agent its project explicitly: `-ProjectRoot`, or `UGA_PROJECT_ROOT` in its environment
  (`UNITY_PROJECT_PATH`, the Unity CLI's variable, also works).
- Route MCP to the right Editor: MCP for Unity `set_active_instance` / per-call `unity_instance`;
  Unity CLI `--project-path`. Verify the instance's project path before mutating.
- `& $broker projects` lists every live broker on the machine (project, session, leases, queue, window).
- Budget memory: each open Editor needs several GB, and Unity keeps import worker processes of about
  1 GB each alive after imports. A session trims them (table above). On Windows the commit limit
  (RAM + page file) usually runs out before free RAM does; `doctor` warns about both.
- Editor preferences are shared by all projects; the broker reference-counts sessions (see above).

## Adapter rules

Neither MCP for Unity nor the Unity CLI knows about leases, and calls from both interleave on the
Editor's main thread. Follow these tables during a session.

### MCP for Unity (CoplayDev)

| Tool | During a session | Instead |
|---|---|---|
| `manage_gameobject`, `manage_components`, `find_gameobjects`, `manage_scene get_hierarchy / load / set_active_scene` | Only with the focus token for your scene (the tools work on the active scene) | - |
| `manage_prefabs modify_contents / get_hierarchy`, `manage_material`, animation tools, `manage_asset` for your assets | Cold lane, inside your lease | - |
| `manage_scene save` | Your scene only | - |
| `manage_script create / update / edit / delete`, `refresh_unity` | **No** | Staging + `request -Lane sync` |
| `manage_asset import` of large/batch files, model import, batch texture import | **No** | Staging + sync |
| `run_tests`, `get_test_job` | **No** (it saves every dirty scene, including other agents') | `request -Lane hot -Tests ...` |
| `manage_editor play / stop / pause` | Only inside your own hot session | `request -Lane hot -JobKind session` |
| `open_prefab_stage`, `save_prefab_stage` | **No** (the prefab stage redirects every agent's lookups) | `manage_prefabs modify_contents` |
| `manage_packages`, `manage_editor deploy_package` | **No** | `request -Lane exclusive` |
| `manage_scene screenshot` | With the focus token or in your session; set `output_folder` outside `Assets/` | - |
| `batch_execute` | Inside your lease or token, at most 25 commands | - |
| `uga_broker` (this package) | Always | `status`, `brief`, `say`, `take`, `release`, `renew`, `yield`, `gate`, `request`, `cancel`, `done`, `job` |

Use the **HTTP** transport. Calls of all clients are serialized per Editor, so keep each call short.

### Unity CLI and the Pipeline package

Pipeline 0.9 names commands `<group> <name>` (`unity command scene save`); the 0.5-era single names
(`save_scene`) are still accepted as obsolete aliases.

| Command | During a session | Instead |
|---|---|---|
| `unity status`, `unity list`, `editor status`, `scene list_open`, `scene get_hierarchy`, `gameobject find`, `asset find`, `component get_*`, `console get` | Always (read-only) | - |
| `gameobject *`, `component add / remove / set_properties / set_field`, `prefab instantiate`, `scene open / set_active`, `capture *` | With the focus token for your scene | - |
| `prefab save_contents / create_variant / apply_overrides / revert_overrides`, `material *`, `animation.*`, `asset move / rename / copy / delete` | Cold lane, inside your lease | - |
| `scene save` | Your scene only | - |
| `scene create` | Your scene only, inside your lease | - |
| `scene add_to_build / remove_from_build` | Cold, with a lease on `asset:ProjectSettings/EditorBuildSettings.asset`; no exclusive window | - |
| `editor save_all`, `editor invoke_menu` | **No** | `scene save` for your scene |
| `script create / attach` of new scripts, `asset write_text` for compiled files, `script recompile`, `script.methodreload *`, CLI `unity recompile` | **No** | Staging + sync |
| `asset import` / `asset create` in batches, large files | **No** | Staging + sync |
| `test run / cancel`, CLI `unity test`, `unity watch test` | **No** | Hot lane |
| `editor.playmode start / stop / pause`, `runtime simulate_*` | Only inside your own hot session | Hot session |
| `package *`, `build *`, `build.target switch`, `settings.* set`, `lighting bake`, `navmesh bake` | **No** | Exclusive lane |
| `script eval` | Short reads or edits of your own leased objects, or calling your own compiled Editor builder; no refresh, compile or Play Mode | - |
| `unity command --detach` + `unity job wait` | Short cold operations only (jobs are lost on domain reload) | `editor-broker.ps1 wait` |
| `unity command uga_broker --action <verb> ...` | Always | Same verbs as the CLI |

The Pipeline HTTP server restarts on every domain reload, possibly on another port; prefer the
PowerShell CLI for anything that must survive a compile.

## Troubleshooting

| Symptom | Action |
|---|---|
| `doctor` says no heartbeat | Open the project in Unity 6+, wait for import; check the Console for `[UGA Broker]` |
| A window drains for 60 s every time | Agents forget `yield`; the board names who blocks it |
| Hot jobs never start | Scripts fail to compile (fix first), or cold work is busy and fewer than 3 hot requests wait (max wait 10 min) |
| A hot window is blocked by unsaved scenes | The scene's owner saves and yields; the window retries after a minute |
| `failed` with compile errors you did not write | You staged into a path you do not own, or the board shows `unowned-compile-errors` |
| MCP calls time out during a window | Expected: the Editor is compiling or playing; call `gate -Wait` before retrying |
| Preferences stayed changed after a crash | `session stop -Force` in that project, or open and close a session; a crashed project's hold expires after 10 min |
| Need to work alone in the Editor | Pause the broker on the board: no windows open and guards are off |
| `brief` ETAs say "default guesses" | The project has no finished windows yet; the estimate improves after the first sync and hot windows |
| An agent misses messages | It must call `brief` (not only `status`); messages addressed to another agent count as "other new" |
| A second Editor exits at startup: "Array buffer allocation failed", no packages loaded | Out of commit memory, not a project defect: close idle Editors or browser windows and start it again |
