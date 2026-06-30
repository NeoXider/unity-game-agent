---
name: unity-game-agent
description: "Unity Game Agent: autonomous Unity game development pipeline for quick fixes, direct feature work, full game builds, verification, Play Mode checks, and MCP-driven Unity Editor automation. Use when working on Unity games, gameplay systems, scenes, UI, ScriptableObjects, builds, tests, or project continuation with Docs/ state files."
metadata:
  version: 3.1.0
  author: Neoxider
  homepage: https://github.com/NeoXider/unity-game-agent
---

# Unity Game Agent

Build Unity games end to end, or make targeted fixes, while keeping the project verifiable. This file is the orchestrator. Load detailed references only when needed.

Core loop: `INTAKE -> PLAN -> BUILD -> VERIFY -> SHIP`.

Use the shortest path that still verifies the change. For small fixes, skip the full pipeline and use Quick Fix.

## Operating Guardrails

Act as a senior Unity C# game development agent that makes working, verified changes.

- Read the existing codebase before choosing architecture. Follow local style and project patterns unless they are clearly broken.
- Make the smallest change that correctly solves the task. Prefer targeted edits over redesigns.
- Preserve existing systems, public APIs, serialized field names, prefabs, scenes, ScriptableObjects, and data layouts whenever possible.
- Do not refactor unrelated code, impose new folder structures, replace working systems, or move code between assemblies/folders without a clear task-driven reason.
- If a solution requires touching many files, changing ownership boundaries, or replacing an architecture, explain the tradeoff and ask before proceeding.
- Prefer adapters, extension points, and small isolated components over rewriting managers/controllers.
- Use `rg` / `rg --files` for project search. Reuse project-local systems, installed packages, Unity built-in APIs, prefabs, ScriptableObjects, editor tools, scenes, and tests before building new framework code.
- Do not revert user changes or run destructive git commands unless explicitly requested.

## Reference And Reuse Discovery

Before choosing an implementation for any task, perform a reference/reuse pass proportional to the task size. Do not build from zero by default. If the user explicitly asks for a from-scratch implementation, respect that request and still use references only to validate behavior, APIs, and edge cases.

Search in this order:

1. Existing project code, prefabs, scenes, ScriptableObjects, tests, packages, samples, and Docs/.
2. Unity built-in APIs, installed packages, official Unity samples, and package documentation.
3. Maintained external options: UPM/GitHub packages, open-source Unity games, reusable feature slices, Unity Asset Store packages, free/open asset packs, shaders, controllers, UI kits, AI/navigation/combat/dialogue/inventory examples, and other credible source repos.
4. Public examples from shipped games, tutorials, talks, reverse-engineering notes, and technical breakdowns as behavior/design references when direct reuse is not appropriate.

Selection rules:

- Prefer adapting a proven library, open-source implementation, sample, asset pack, or part of an existing open game over writing custom framework/mechanic code from scratch.
- Use a whole package/asset only when it is narrower and safer than custom code. Otherwise use it as a reference and write a small project-local adapter.
- Classify each candidate as `direct reuse`, `adapt`, or `reference-only`. Directly import/copy when the source is usable for the project; otherwise study the behavior, API shape, architecture, data model, and edge cases, then reimplement the logic independently in project code.
- Do not reject useful references just because they cannot be copied verbatim. Restrictive or unclear sources can still guide mechanics, tuning, UX, algorithms, test cases, and architecture.
- Do not use leaked code, decompiled sources, private repositories, or ripped assets. Do not clone copyrighted expression; reproduce the underlying behavior or logic in original code/assets.
- If no suitable reuse option exists, implement the smallest custom solution and record why reuse was rejected.

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
  "qa_verification_driver_required": true,
  "qa_tests_required_standard_pro": true,
  "qa_screenshot_evidence_required": true,
  "interactive_qa_requires_runtime_driver": true,
  "qa_max_attempts_before_degraded_report": 2,
  "qa_continue_after_degraded_report": true,
  "qa_degraded_report_required": true,
  "ask_about_neoxider_tools": true,
  "neoxider_tools": "ask",
  "qa_per_feature": true,
  "qa_final": true,
  "screenshot_policy": "per_feature",
  "reuse_first": true,
  "external_reference_discovery": true,
  "no_reinventing_without_reason": true,
  "lead_dev_qa_workflow_standard_pro": true,
  "task_pages_standard_pro": true,
  "qa_agent_duplicate_checklist": true,
  "auto_advance_after_self_qa": true,
  "skill_memory_enabled": true,
  "skill_memory_write_policy": "auto_after_verified_task",
  "skill_memory_scope": "universal_only",
  "role_subskills_enabled": true,
  "mandatory_subagents_standard_pro": true,
  "subagent_fallback_policy": "only_when_tools_unavailable",
  "gd_before_lead": true,
  "designer_before_lead_when_visual": true,
  "minimal_change": true,
  "preserve_serialized_contracts": true,
  "library_policy": "discover_before_plan",
  "pattern": "auto",
  "project_frameworks": []
}
```

Important policy meanings:

- `strict_preflight: true`: do not mutate Unity state until readiness, target scene/context, console baseline, and task-relevant capabilities are known.
- `strict_preflight: false`: allowed only for narrow file-only edits or explicit user quick fixes. Still avoid destructive scene, package, and build changes without context.
- `visual_verification: true`: visual scene, UI, camera, material, animation, lighting, prefab, and VFX changes need a screenshot or equivalent visual capture.
- `final_playmode_tests_standard_pro: true`: standard and pro tasks must run Play Mode before closing when MCP or equivalent Unity automation is available.
- `qa_verification_driver_required: true`: every standard/pro Feature and Task declares how runtime behavior will be driven and verified.
- `qa_tests_required_standard_pro: true`: write and run EditMode/PlayMode tests for standard/pro tasks that involve logic, runtime behavior, or risky flows.
- `qa_screenshot_evidence_required: true`: visual/runtime-visible checks need screenshot evidence linked from task/feature/QA docs.
- `interactive_qa_requires_runtime_driver: true`: screenshot-only checks cannot pass interactive gameplay, input, UI flow, collision, spawn, scene transition, pause, or restart behavior.
- `qa_max_attempts_before_degraded_report: 2`: QA gets at most two serious attempts per required verification item before it must stop retrying.
- `qa_continue_after_degraded_report: true`: after the second failed/unavailable QA attempt, write a degraded report, create a follow-up defect/automation-gap task, and continue instead of waiting for the user.
- `qa_degraded_report_required: true`: degraded QA must list attempts, why testing failed, skipped checks, available evidence, risk, and the follow-up task.
- `auto_install_mcp_in_manifest: true`: if MCP is missing in a Unity project, add the adapter package to `Packages/manifest.json` before falling back to file-only mode.
- `neoxider_tools: "ask"`: ask before using NeoxiderTools systems when the project/task could benefit from them.
- `external_reference_discovery: true`: search local and credible external ready solutions before planning nontrivial implementation work.
- `no_reinventing_without_reason: true`: prefer libraries, open-source feature slices, samples, reusable assets, and reference implementations unless custom code is smaller, safer, or explicitly requested.
- `lead_dev_qa_workflow_standard_pro: true`: standard/pro work uses Lead planning pages, Developer task execution, then Agent QA before advancing.
- `task_pages_standard_pro: true`: standard/pro features must have one file per task under `Docs/Tasks/`.
- `qa_agent_duplicate_checklist: true`: each standard/pro feature gets `Docs/QA/` and duplicate `Docs/QA_AGENT/` checklists.
- `auto_advance_after_self_qa: true`: after Agent QA passes, or after degraded QA is reported with a follow-up task, continue to the next task/feature without waiting for human approval unless blocked or ambiguous.
- `skill_memory_enabled: true`: use `SKILL_MEMORY.md` for universal improvements to this skill, separate from project memory.
- `skill_memory_write_policy: "auto_after_verified_task"`: append a memory entry after a verified task when a reusable skill-level lesson was found.
- `skill_memory_scope: "universal_only"`: store only lessons that apply across Unity projects, not project-local decisions.
- `role_subskills_enabled: true`: load compact role files from `roles/` instead of expanding the main orchestrator.
- `mandatory_subagents_standard_pro: true`: when subagent tools are available, standard/pro role passes must run as subagents.
- `subagent_fallback_policy: "only_when_tools_unavailable"`: local role switching is allowed only when subagent tools are unavailable or blocked.
- `gd_before_lead: true`: Game Designer role prepares/updates `GAME_DESIGN.md` before Lead planning when design is incomplete or gameplay changes are broad.
- `designer_before_lead_when_visual: true`: Designer role prepares/updates `UI_BRIEF.md` before Lead planning when UI/UX/visual work is involved.

## Development Patterns

A **development pattern** is a reusable, opinionated playbook for building one *family* of games on top
of this same pipeline. The pipeline (preflight, verification gate, QA policy, roles) is unchanged; a
pattern fills it with concrete stack choices, scene skeletons, reuse maps, golden rules, and
anti-patterns. Patterns are additive — new ones live under `patterns/` without changing the engine.

| Pattern | Use for | Stack | Entry file |
|---|---|---|---|
| `casual-neoxider` | Casual/hyper-casual/mobile: match-3, merge, lotto/bingo, slots, dress-up, idle/clicker, arcade, puzzle | NeoxiderTools (`Neo.*`) + NeoxiderPages + DOTween via MCP | [patterns/casual-neoxider/pattern.md](patterns/casual-neoxider/pattern.md) |

Pattern selection (during Session Routing / INTAKE), at most one:

1. **Detect** — scan for the pattern's signals (packages, namespaces, scene shape, managers). A
   confident detection auto-selects it. For `casual-neoxider`: `com.neoxider.tools`, `Neo.*` usage, a
   `-System--` root, `UIPage`/`PageId`/`BtnChangePage`.
2. **Match the request** — for a new/empty project, match the described genre/stack to the table.
3. **Confirm only when ambiguous** — weak detection + generic request -> ask; otherwise proceed with the
   best fit (or no pattern).

Record the choice in `Docs/DEV_PROFILE.json` (`"pattern"`) and `Docs/AGENT_MEMORY.md`. A selected
pattern's defaults override the universal defaults where they conflict (e.g. `casual-neoxider` treats
NeoxiderTools reuse as the default, not an opt-in question). The universal preflight, verification gate,
and QA policy always still apply. To add a pattern, see [patterns/README.md](patterns/README.md).

## Reference Map

- Development patterns: [patterns/README.md](patterns/README.md); casual games on NeoxiderTools: [patterns/casual-neoxider/pattern.md](patterns/casual-neoxider/pattern.md)
- UI stack profiles: `project-profiles/` — runtime UI Toolkit on Unity 6.5 / `PanelRenderer`: [project-profiles/ui-toolkit/README.md](project-profiles/ui-toolkit/README.md)
- Provider-neutral MCP workflow: [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md)
- CoplayDev command adapter: [mcp-commands.md](mcp-commands.md)
- NeoxiderTools reuse rules: [tools/neoxider-tools-reuse.md](tools/neoxider-tools-reuse.md)
- Mode cadences: [POLICY_MATRIX.md](POLICY_MATRIX.md) and `modes/<fast|standard|pro>.md`
- Docs/templates: [reference.md](reference.md) and `templates/`
- C# examples: [tools/code-writing.md](tools/code-writing.md)
- Mechanics patterns: [tools/core-mechanics.md](tools/core-mechanics.md)
- Library policy: [tools/libraries-setup.md](tools/libraries-setup.md)
- Play Mode QA automation: [tools/playmode-qa-automation.md](tools/playmode-qa-automation.md)
- Skill memory: [SKILL_MEMORY.md](SKILL_MEMORY.md) and [tools/append-skill-memory.ps1](tools/append-skill-memory.ps1)
- Role subskills: [roles/game-designer.md](roles/game-designer.md), [roles/designer.md](roles/designer.md), [roles/lead.md](roles/lead.md), [roles/developer.md](roles/developer.md), [roles/qa.md](roles/qa.md)
- Standard/Pro feature docs generator: [tools/new-feature-docs.ps1](tools/new-feature-docs.ps1)
- Script smoke tests: [tools/test-scripts.ps1](tools/test-scripts.ps1)
- Ready prompts: [PROMPTS.md](PROMPTS.md)

Load references progressively. Do not load command catalogs or long examples unless the active task needs them.

## Skill Self-Improvement Memory

Use `SKILL_MEMORY.md` as persistent memory for the skill itself. This is separate from a Unity project's `Docs/AGENT_MEMORY.md`.

Read `SKILL_MEMORY.md` when using this skill unless the task is a tiny Quick Fix and no skill-level behavior decision is needed.

After a task is completed and verified, append a skill memory entry when the task reveals a universal improvement:

- a better repeatable workflow, verification step, tool usage, or QA pattern;
- a reusable Unity/MCP/documentation approach that should apply across future projects;
- an anti-pattern or failure mode that future agents should avoid;
- a correction to how this skill should route, plan, verify, or document work.

Do not write project-specific decisions, user preferences for one project, secrets, private paths, one-off fixes, or noisy observations to `SKILL_MEMORY.md`. Put project-local facts in `Docs/AGENT_MEMORY.md`.

Prefer `tools/append-skill-memory.ps1` for entries. If a lesson would materially change skill behavior, propose the change or patch the skill intentionally instead of only recording memory.

## Role Subskills And Subagents

Use the role files in `roles/` to keep responsibilities narrow and context clean. The orchestrator remains accountable for sequencing, conflict resolution, final verification, and user communication.

For `standard` and `pro`, use real subagents for role passes whenever subagent tools are available: `Game Designer -> Designer when visual/UI -> Lead -> Developer task pass(es) -> QA -> Auto-advance`.

Role routing:

- Game Designer: use `roles/game-designer.md` before Lead for new games, missing/weak `GAME_DESIGN.md`, or broad gameplay/core-loop changes.
- Designer: use `roles/designer.md` before Lead when UI, UX, visual style, screens, feedback, animation, camera presentation, or assets are involved.
- Lead: use `roles/lead.md` to create/update `DEV_PLAN`, Feature pages, Task pages, QA checklists, QA-agent duplicates, acceptance criteria, and rollback risk.
- Developer: use `roles/developer.md` for one selected task page at a time with narrow write ownership.
- QA: use `roles/qa.md` after all feature tasks are done; QA verifies independently against `Docs/QA_AGENT/`, creates/reopens defect tasks on failure, and follows the two-attempt degraded-report policy when tooling cannot complete a check.

Subagent rules:

- If subagent tools are available, standard/pro role passes must be delegated to subagents. Use `worker` for roles that write docs/code and `explorer` only for read-only review/research.
- Give each subagent exactly one role file, concrete inputs, expected outputs, and disjoint primary write ownership. Shared coordination docs (`DEV_STATE`, `DEV_LOG`, `AGENT_MEMORY`) may be updated by multiple roles only within their own role-specific sections/entries.
- Do not delegate the orchestrator's accountability: read role outputs, check contradictions, and choose the next step.
- If subagents are unavailable or blocked, record degraded mode in `DEV_STATE`/`DEV_LOG`, then execute the role locally by following the role file.
- For `fast`, Quick Fix, narrow file-only edits, or explicitly free-form/direct tasks, role subagents are optional and usually skipped.
- Role outputs go to `Docs/*`. Universal role improvements may go to `SKILL_MEMORY.md` only under the skill memory rules.

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

After classifying, **select a development pattern** (see Development Patterns): detect from the project,
or match the request for a new project. A selected pattern (e.g. `casual-neoxider`) sets the stack
defaults and reuse posture for the rest of the session; record it in `Docs/DEV_PROFILE.json`.

Defaults:

- Mode: `standard` for "make a game"; `fast` for prototypes/simple games; `pro` for scalable architecture, tests, or larger systems.
- Platform: PC unless mobile/WebGL is implied.
- UI: detect existing stack first; default to UI Toolkit for new projects.
- MCP: assume available. If unavailable, install the adapter in `Packages/manifest.json` when allowed, let Unity resolve packages, retry MCP, and only then degrade to `file_only` with limitations.
- Auto mode: work autonomously after the plan is approved; batch non-blocking questions.

## Mandatory Preflight

Before changing Unity scenes, assets, scripts, prefabs, packages, tests, rendering, UI, play mode, or build settings, perform the provider-neutral preflight from [tools/mcp-provider-neutral.md](tools/mcp-provider-neutral.md).

Required facts:

- Unity project root exists: `Assets/`, `Packages/`, and `ProjectSettings/`;
- `Packages/manifest.json`, installed packages, Unity version, and build target when relevant;
- active Unity Editor instance, or explicit target instance;
- editor readiness: compile/import/domain reload status and blocking reasons;
- active or requested scene; load/create/switch scenes when the task clearly implies the target;
- baseline console errors and warnings before changes;
- relevant project architecture, existing scenes, prefabs, ScriptableObjects, editor tools, and tests;
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

If `ask_about_neoxider_tools` is true and the project is new/empty, or the task involves UI pages/navigation, game flow, audio, shop/economy, reusable managers, settings/save, quests, cards/decks, inventory, dialogue, spawning, movement/input helpers, editor tooling, docs, or other reusable game systems, ask:

```text
Use ready systems from NeoxiderTools, or build standalone for this project?
```

If the user chooses NeoxiderTools:

- inspect available NeoxiderTools systems before planning implementation;
- distinguish package modules from optional samples such as `NeoxiderPages`;
- prefer reuse/adapters over duplicate systems;
- record the choice in `Docs/DEV_PROFILE.json` and `Docs/AGENT_MEMORY.md`;
- keep project-specific code thin and explicit.

If the user declines or NeoxiderTools is unavailable, build standalone and record that choice. See [tools/neoxider-tools-reuse.md](tools/neoxider-tools-reuse.md).

When the `casual-neoxider` pattern is selected, NeoxiderTools reuse is the **default**, not an opt-in
question — follow [patterns/casual-neoxider/pattern.md](patterns/casual-neoxider/pattern.md) and only ask
if the user explicitly wants a standalone build instead.

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

### C# Authoring Rules

- Use normal C# gameplay logic: `if`, `switch`, typed methods, events, and explicit state.
- Do not replace simple C# with visual/no-code flow components, lifecycle wrappers, UnityEvent relay chains, or inspector-only logic.
- Prefer clear MonoBehaviours for scene behavior and plain C# classes for testable domain logic.
- Use ScriptableObjects for shared game data/configuration only when they improve authoring or reuse.
- Keep serialized fields private with `[SerializeField]`; preserve serialized field names unless the task requires a migration.
- Cache required components in `Awake` or explicit initialization.
- Avoid new global singletons unless the project already uses them consistently.
- Keep `Update` loops small; move decisions into named methods.

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
4. For standard/pro, read the active feature page, active task page, `Docs/QA/` checklist, and `Docs/QA_AGENT/` duplicate when referenced by DEV_STATE/DEV_PLAN.
5. Create the next iteration log/screenshot folder if continuing a feature.
6. Run preflight.
7. Continue the next unchecked or in-progress task.
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

### Feature Decomposition

For work larger than a narrow fix, break the plan into Epics, SubEpics, and Features:

- Epic: a major product/gameplay area.
- SubEpic: a coherent slice inside an Epic.
- Feature: a small, shippable behavior change.

Each Feature must define purpose, affected systems/files, expected player/user behavior, verification steps, and rollback risk. Implement and verify feature-by-feature when practical. Keep new features owned by their relevant systems instead of mixing unrelated behavior into shared managers.

### Standard/Pro Lead-Dev-QA Workflow

Use this workflow for `standard` and `pro` full-cycle or direct feature work. Do not force it onto Quick Fix, `fast`, narrow file-only edits, or explicitly free-form/direct tasks unless the user asks for stronger tracking.

Lead phase:

1. Run project discovery, reference/reuse discovery, and Unity preflight before planning implementation.
2. Run Game Designer and Designer role passes first when their routing conditions apply.
3. Confirm `Docs/GAME_DESIGN.md` and `Docs/UI_BRIEF.md` are current from those role passes; Lead writes or updates `Docs/ARCHITECTURE.md` when relevant and `Docs/DEV_PLAN.md`.
4. Prefer `tools/new-feature-docs.ps1` to create feature/task/QA files from templates when running on Windows.
5. Create one feature page per Feature in `Docs/Features/FEAT-NNN-slug.md` from `templates/FEATURE.md`.
6. Create one task page per implementation task in `Docs/Tasks/TASK-NNN-slug.md` from `templates/TASK.md`.
7. For each Feature and Task, declare `Verification Driver`, `Tests Required`, `Screenshot Required`, and any `Automation Gap` using [tools/playmode-qa-automation.md](tools/playmode-qa-automation.md).
8. Link every task page from its feature page and from `DEV_PLAN.md`.
9. Create `Docs/QA/FEAT-NNN-slug-qa.md` from `templates/QA_CHECKLIST.md`.
10. Create a duplicate independent checklist at `Docs/QA_AGENT/FEAT-NNN-slug-qa.md` from `templates/QA_AGENT_CHECKLIST.md`.
11. Ask the user only for decisions that materially change product behavior, require paid/large external assets, alter architecture boundaries, or cannot be inferred safely. Otherwise proceed autonomously.

Developer phase:

1. Pick the next unchecked task from `DEV_PLAN.md` and its task page.
2. Mark it in progress in `Docs/DEV_STATE.md`, the task page, and the current iteration log.
3. Implement the smallest change that satisfies the task acceptance criteria.
4. Add required EditMode/PlayMode tests, scenario runner, input seam, or QA hook declared by the task. If the automation hook is missing, create/fix it before claiming the task is verified.
5. After each task, run compile/import readiness, console checks, declared tests, and screenshot capture/review when required.
6. Record touched files, verification driver, test results, screenshots/logs, skipped checks with reasons, and remaining risk in the task page and `DEV_LOG`.
7. Mark the task done only when its acceptance criteria and verification steps pass.

Feature QA and auto-advance:

1. When all task pages for a feature are done, Developer/orchestrator runs feature self-check: declared verification driver, Play Mode, console during Play Mode, changed behavior check, required tests, and screenshot capture/review when required.
2. Developer/orchestrator fills the Agent result column in `Docs/QA/FEAT-NNN-slug-qa.md`.
3. Run an independent QA role pass against `Docs/QA_AGENT/FEAT-NNN-slug-qa.md`. Use a QA subagent when available; otherwise switch context mentally, follow only the checklist and player-facing expected behavior, and avoid relying on implementation assumptions.
4. If QA passes, mark the feature done in the feature page, `DEV_PLAN.md`, `DEV_STATE.md`, and `DEV_LOG`, then continue to the next task/feature automatically.
5. If QA finds an implementation defect, create or reopen a task page for the defect, fix it, and rerun the affected QA check. Limit each required QA check/driver to two serious attempts.
6. If QA cannot execute a required check after two attempts because tooling, Play Mode, tests, screenshots, or runtime drivers remain unavailable/failing, do not retry indefinitely. Fill a degraded QA report, list what was attempted, why testing failed, what was skipped, available evidence, risk, and the follow-up defect/automation-gap task, then continue to the next task/feature.
7. Stop for human input only on blockers that cannot be bypassed with degraded reporting, missing required assets/credentials, destructive changes, or unresolved product decisions. Do not ask solely because QA reached the retry limit.

## Verification Gate

Before closing any Unity-changing task:

- Always run final console check when `final_console_check` is enabled.
- For C# changes, wait for import/compile and report new compile/runtime errors.
- For visual work, take and review a screenshot when `visual_verification` is enabled.
- For gameplay/system changes in standard/pro, enter Play Mode before closing the task when MCP or equivalent automation is available.
- During Play Mode, check console while running, then verify the changed mechanic/UI/scene/camera behavior directly.
- For interactive behavior, use the declared runtime driver. Do not accept screenshot-only verification for player input, UI flows, collision, spawn, scene transition, pause, restart, or runtime state changes.
- For required tests, write and run EditMode/PlayMode tests. If tests cannot run, mark verification `degraded` and explain why.
- For QA verification failures caused by unavailable/failing tooling, make at most two serious attempts, then record a degraded report with skipped checks and continue with a follow-up task.
- For screenshot evidence, capture, review, and link the image. Screenshots must be nonblank, correctly framed, and show the expected state.
- For mechanics, verify runtime state, inputs/outputs, reset/restart, pause/time scale when relevant, scene reload behavior, and object lifecycle.
- For physics/cameras, verify layers, colliders, Rigidbody/Rigidbody2D settings, time scale, and camera framing when relevant.
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
- Verification driver/tests: <driver>; tests: <pass/fail/skipped reason>
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

- Project agent memory files live under `Docs/`, never project root. Skill-level memory lives only in this skill's `SKILL_MEMORY.md`.
- For standard/pro, create and maintain `Docs/Features/`, `Docs/Tasks/`, `Docs/QA/`, and `Docs/QA_AGENT/`.
- `DEV_STATE.md` stays small and current.
- `DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` uses datetime in the filename.
- Screenshots go under `Docs/Screenshots/iter-NN/`.
- Record NeoxiderTools and library decisions in `DEV_PROFILE.json` and `AGENT_MEMORY.md`.

## UI, Libraries, And Architecture

- Detect existing UI stack before choosing one. Do not mix UI Toolkit and uGUI in the same screen unless migrating.
- For UI Toolkit runtime UI on Unity 6.5+, use the `PanelRenderer` profile (`PanelRenderer` replaces `UIDocument`, supports USS filters and `-unity-material`/UI Shader Graph): [project-profiles/ui-toolkit/README.md](project-profiles/ui-toolkit/README.md). On Unity 6.4 and earlier, keep `UIDocument`.
- Use TextMeshPro for uGUI text; never use legacy `UnityEngine.UI.Text`.
- Use null-safe UI references, especially in tests and no_ui mode.
- Separate UI view updates from game rules.
- Respect the existing input stack.
- Keep gameplay mechanics deterministic and testable where practical.
- Keep scene wiring explicit and inspectable.
- Reuse existing audio, save, settings, inventory, quest, economy, UI navigation, and progression systems before adding new ones.
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
- Rename serialized fields casually and break scene/prefab data.
- Build systems, mechanics, UI frameworks, controllers, asset pipelines, or tools from scratch before checking existing packages, open-source examples, samples, reusable assets, and reference implementations.
- Reject useful external references just because direct import/copy is not appropriate; use them as reference-only and reimplement the behavior independently.
- Close with "done" without stating changed files, verification run, skipped checks, and remaining risk.
