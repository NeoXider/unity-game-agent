---
name: unity-game-agent
description: "Unity Game Agent: autonomous Unity game development pipeline for quick fixes, direct feature work, full game builds, verification, Play Mode checks, and MCP-driven Unity Editor automation. Use when working on Unity games, gameplay systems, scenes, UI, ScriptableObjects, builds, tests, or project continuation with Docs/ state files."
---

# Unity Game Agent

Build Unity games end to end, or make targeted fixes, while keeping the project verifiable. This file is the orchestrator. Load detailed references only when needed.

Core loop:

```text
INTAKE -> PLAN -> BUILD -> VERIFY -> SHIP
```

Use the shortest path that still verifies the change. For small fixes, skip the full pipeline and use Quick Fix.

## Runtime Policy

Use these defaults unless the user or `Docs/DEV_PROFILE.json` overrides them.

```json
{
  "dev_mode": "standard",
  "skill_mode": "full_cycle",
  "ui_mode": "enabled",
  "ui_stack": "ui_toolkit",
  "mcp_mode": "use",
  "mcp_adapter": "coplaydev-unity-mcp",
  "auto_install_mcp_in_manifest": true,
  "provider_neutral_tool_mapping": true,
  "strict_preflight": true,
  "visual_verification": true,
  "visual_verification_max_resolution": 512,
  "final_console_check": true,
  "final_playmode_tests_standard_pro": true,
  "final_tests_when_relevant": true,
  "final_build_validation_when_relevant": true,
  "ask_about_neoxider_tools": true,
  "neoxider_tools": "ask",
  "qa_per_feature": true,
  "qa_final": true,
  "screenshot_policy": "per_feature",
  "reuse_first": true,
  "library_policy": "discover_before_plan",
  "project_frameworks": []
}
```

Important policy meanings:

- `strict_preflight: true`: do not mutate Unity state until readiness, target scene/context, console baseline, and task-relevant capabilities are known.
- `strict_preflight: false`: allowed only for narrow file-only edits or explicit user quick fixes. Still avoid destructive scene, package, and build changes without context.
- `visual_verification: true`: visual scene, UI, camera, material, animation, lighting, prefab, and VFX changes need a screenshot or equivalent visual capture.
- `final_playmode_tests_standard_pro: true`: standard and pro tasks must run Play Mode before closing when MCP or equivalent Unity automation is available.
- `auto_install_mcp_in_manifest: true`: if MCP is missing in a Unity project, add the adapter package to `Packages/manifest.json` before falling back to file-only mode.
- `neoxider_tools: "ask"`: ask before using NeoxiderTools systems when the project/task could benefit from them.

## Reference Map

- Provider-neutral MCP workflow: [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md)
- CoplayDev command adapter: [mcp-commands.md](mcp-commands.md)
- NeoxiderTools reuse rules: [tools/neoxider-tools-reuse.md](tools/neoxider-tools-reuse.md)
- Mode cadences: [POLICY_MATRIX.md](POLICY_MATRIX.md) and `modes/<fast|standard|pro>.md`
- Docs/templates: [reference.md](reference.md) and `templates/`
- C# examples: [tools/code-writing.md](tools/code-writing.md)
- Mechanics patterns: [tools/core-mechanics.md](tools/core-mechanics.md)
- Library policy: [tools/libraries-setup.md](tools/libraries-setup.md)
- Ready prompts: [PROMPTS.md](PROMPTS.md)

Load references progressively. Do not load command catalogs or long examples unless the active task needs them.

## Session Routing

Start by classifying the user request.

```text
1. Quick Fix?
   Specific bug, compile error, small edit, 1-3 files, or direct "fix/change/add X".
   -> Use Quick Fix. Do not create Docs/ or ask mode questions.

2. Existing tracked agent project?
   Docs/DEV_PROFILE.json or Docs/DEV_STATE.md exists.
   -> Resume from Docs/.

3. Existing Unity project without Docs/?
   Assets/ and ProjectSettings/ exist.
   -> Ask whether user wants full game pipeline, direct feature work, or quick fix.

4. New/empty project?
   -> Intake for game idea, mode, platform, UI stack, and optional NeoxiderTools reuse.
```

Defaults:

- Mode: `standard` for "make a game"; `fast` for prototypes/simple games; `pro` for scalable architecture, tests, or larger systems.
- Platform: PC unless mobile/WebGL is implied.
- UI: detect existing stack first; default to UI Toolkit for new projects.
- MCP: assume available. If unavailable, install the adapter in `Packages/manifest.json` when allowed, let Unity resolve packages, retry MCP, and only then degrade to `file_only` with limitations.
- Auto mode: work autonomously after the plan is approved; batch non-blocking questions.

## Mandatory Preflight

Before changing Unity scenes, assets, scripts, prefabs, packages, tests, rendering, UI, play mode, or build settings, perform the provider-neutral preflight from [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md).

Required facts:

- active Unity Editor instance, or explicit target instance;
- editor readiness: compile/import/domain reload status and blocking reasons;
- active or requested scene; load/create/switch scenes when the task clearly implies the target;
- baseline console errors and warnings before changes;
- task-relevant capabilities: UI Toolkit, uGUI, TMP, Input System, URP/HDRP/Built-in, Cinemachine, ProBuilder, tests, build support, NeoxiderTools;
- status classification: `READY`, `BUSY`, `BLOCKED`, or `DEGRADED`.

Strict blocking rules:

- readiness false, active compile/import, or pending domain reload: wait/retry before mutating.
- ambiguous Unity instance: resolve it before mutating.
- missing/ambiguous target scene: load/create/switch if the task clearly allows it; otherwise ask.
- pre-existing compile errors: block C# and test/build work unless the user asks for a targeted fix. For scene-only work, continue as `DEGRADED` only if tools are ready.

Preflight summary shape:

```text
Unity Preflight:
- status: READY | BUSY | BLOCKED | DEGRADED
- instance: <active editor instance or unresolved>
- scene: <active/requested scene or unresolved>
- compile/domain reload: idle | busy | pending
- console baseline: <count and key errors>
- capabilities: <task-relevant packages/systems>
- policy: strict_preflight=<true|false>, visual_verification=<true|false>
```

## NeoxiderTools Decision Point

If `ask_about_neoxider_tools` is true and the project is new/empty, or the task involves UI, settings, pages, save, quest, cards, audio, editor tooling, docs, or reusable game systems, ask:

```text
Use ready systems from NeoxiderTools, or build standalone for this project?
```

If the user chooses NeoxiderTools:

- inspect available NeoxiderTools systems before planning implementation;
- prefer reuse/adapters over duplicate systems;
- record the choice in `Docs/DEV_PROFILE.json` and `Docs/AGENT_MEMORY.md`;
- keep project-specific code thin and explicit.

If the user declines or NeoxiderTools is unavailable, build standalone and record that choice. See [tools/neoxider-tools-reuse.md](tools/neoxider-tools-reuse.md).

## C# Change Workflow

Use the same flow with any Unity MCP or file tool stack:

```text
1. Snapshot the target file when supported: hash/SHA/version/timestamp.
2. Apply the smallest structured edit available.
3. Use text patches only when semantic/script edits are unavailable.
4. Validate syntax or script structure when the tool exposes validation.
5. Trigger or wait for Unity import/compilation according to the active tool behavior.
6. Poll editor readiness until import/compile/domain reload completes.
7. Read console and attribute only new errors/warnings to the change.
8. Attach/use the script only after compilation succeeds.
```

Do not overwrite concurrent user edits. If a hash/version changed, re-read the file and merge deliberately.

## Pipeline

### Quick Fix

For narrow fixes:

```text
1. Read relevant files/resources.
2. Run preflight unless this is explicitly file-only.
3. Make the smallest safe edit.
4. Compile/import check if C# or Unity assets changed.
5. Final console check.
6. Save scene only if scene changed.
7. Report changed files and verification.
```

No Docs/ bootstrap, no mode selection, no full plan.

### Resume

When Docs/ exists:

```text
1. Read Docs/DEV_PROFILE.json.
2. Read Docs/DEV_CONFIG.md, GAME_DESIGN.md, DEV_STATE.md, AGENT_MEMORY.md, DEV_PLAN.md.
3. Read ARCHITECTURE.md only for standard/pro or architecture work.
4. Create the next iteration log/screenshot folder if continuing a feature.
5. Run preflight.
6. Continue the next unchecked or in-progress task.
```

### New Existing Project

If a Unity project exists but Docs/ does not, ask once:

```text
What do you need?
1. Full game development pipeline
2. Direct feature/mechanic
3. Bug fix / quick edit
```

For full/direct work, bootstrap only the Docs/ files needed by the selected path. Do not impose `Assets/_source/` if the project has an existing structure.

### New Project / Full Game

Intake needs only decision-making information:

- game idea and core mechanics;
- mode: fast, standard, pro;
- platform: PC, Mobile, WebGL;
- UI stack: detected, UI Toolkit, uGUI, or no_ui;
- NeoxiderTools reuse choice when relevant.

Then create GAME_DESIGN, DEV_PLAN, DEV_PROFILE, and required Docs/ state files from templates. Use feature decomposition for all modes.

## Verification Gate

Before closing any Unity-changing task:

- Always run final console check when `final_console_check` is enabled.
- For C# changes, wait for import/compile and report new compile/runtime errors.
- For visual work, take and review a screenshot when `visual_verification` is enabled.
- For gameplay/system changes in standard/pro, enter Play Mode before closing the task when MCP or equivalent automation is available.
- During Play Mode, check console while running, then verify the changed mechanic/UI/scene/camera behavior directly.
- For pro mode, run relevant EditMode/PlayMode tests when available.
- For build settings, platform, scene-in-build, serialization, package, or player-impacting changes, run build validation when practical.
- If a check is skipped because tooling is unavailable, project lacks tests, or policy/user disabled it, report the reason.

Final verification report format:

```text
Verification:
- Compile/import: pass | fail | skipped (<reason>)
- Console before/after: <baseline count> -> <current count>; new errors: <none/list>
- Play Mode: pass | fail | skipped (<reason>); scenario: <what was tested>
- Changed behavior: <mechanic/UI/scene/camera/system checked>
- Screenshot: <path or skipped reason>
- Tests/build validation: pass | fail | skipped (<reason>)
```

Mode-specific minimums:

| Mode | Close task only after |
|---|---|
| fast | compile/import clean, no new console errors, screenshot/Play Mode per cadence or visible change |
| standard | compile/import clean, Play Mode smoke test, console checked during Play Mode, relevant visual/mechanic checked |
| pro | standard checks plus relevant tests and stricter architecture/docs updates |

## Mode And Docs Rules

Use [POLICY_MATRIX.md](POLICY_MATRIX.md) as the source of truth for cadence. Load `modes/<mode>.md` for detailed mode behavior.

Docs rules:

- All agent memory files live under `Docs/`, never project root.
- `DEV_STATE.md` stays small and current.
- `DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` uses datetime in the filename.
- Screenshots go under `Docs/Screenshots/iter-NN/`.
- Record NeoxiderTools and library decisions in `DEV_PROFILE.json` and `AGENT_MEMORY.md`.

## UI, Libraries, And Architecture

- Detect existing UI stack before choosing one. Do not mix UI Toolkit and uGUI in the same screen unless migrating.
- Use TextMeshPro for uGUI text; never use legacy `UnityEngine.UI.Text`.
- Use null-safe UI references, especially in tests and no_ui mode.
- Discover packages before adding libraries. Install only for a concrete need or explicit user request.
- Prefer reuse: Unity built-ins, installed packages, project systems, NeoxiderTools if opted in, then new code.
- Keep fast mode simple, standard mode component/event-oriented, and pro mode testable with interfaces/services where justified.

## Error Recovery

- Compilation fails: fix from console, retry, simplify if needed, then ask with the exact error after repeated failure.
- Play Mode crash: stop Play Mode, read console, fix, recompile, retry.
- MCP unavailable: switch to `file_only`, report limitations, and continue only with file-level work.
- Screenshot blank/wrong: inspect camera/scene target, retake, and report if visual verification remains blocked.
- Feature fails after repeated attempts: revert only your own recent changes if safe, simplify, record blocker, ask for direction.

## Anti-Patterns

- Start full-cycle work without a plan.
- Skip preflight before Unity mutations in strict mode.
- Skip final console check.
- Close standard/pro tasks without Play Mode verification when tooling is available.
- Report visual work as done without reviewing a screenshot.
- Hardcode settings that belong in ScriptableObjects.
- Add packages before discovery.
- Force NeoxiderTools reuse without user opt-in.
- Impose a new folder structure over an existing project convention.
- Trust sub-agent or tool output without verification.
