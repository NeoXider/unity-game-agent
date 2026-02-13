---
name: unity-game-agent
description: Unity Game Agent — build Unity games by stages (outline → plan → implementation → check). Use when the user asks to build or prototype a Unity game, implement features step-by-step, or use Unity MCP / other MCPs for scene and editor automation.
---

# Unity Game Agent

Build a Unity game in a cycle: **outline → stages → implementation → check → report**, using MCP (Unity MCP and others) where available.

This file is intentionally **short** (save tokens). Details and templates are in:
- **Project file templates + reference:** [reference.md](reference.md)
- **Mode choice:** [MODE_CHOICE.md](MODE_CHOICE.md), details: [MODE_DETAILS.md](MODE_DETAILS.md), rules: `modes/*.md`
- **Tools/code/Unity:** `tools/*.md`
- **Ready prompts:** [PROMPTS.md](PROMPTS.md)

## AutoUnity project goal

**Current project goal:** provide **MCP set, ready prompts/skills, automation (bat) and ComfyUI** for **creating autonomous Unity games with AI**.

Tool use rules:
- **Files/folders/code:** do not use Unity MCP. Use file tools (IDE/file MCP/patches) or `setup_source_folders.bat`.
- **Unity Editor** (scene/objects/components/PlayMode/screenshots/console): use Unity MCP.
- **UI policy is project-aware:** detect existing stack first (uGUI/NeoxiderPages/UI Toolkit). Continue existing stack by default; offer migration only if user asks. Support `no_ui` mode for mechanics/system work without UI scope. Before UI layout always ask for design reference (screenshots, mockup link, style guide, Figma-exported refs). Details: [tools/ui-builder.md](tools/ui-builder.md).

Use this goal when configuring and updating.

## Project setup

Briefly:
- Open the current Unity project workspace (any path).
- MCP configured in `.cursor/mcp.json`.
- Details: [tools/unity-mcp.md](tools/unity-mcp.md) and [tools/comfyui.md](tools/comfyui.md).

## When to use

- Request to create/prototype a Unity game.
- Request to implement mechanics step-by-step with editor checks.
- Tasks that need an explicit outline and intermediate stages (not only final code).

## Starting a new game (from scratch)

- **First question to user (always, mandatory):**
  - "Choose mode: **prototype / fast / standard / pro / no_ui**."
  - Do not ask cycle/settings/MCP before user picks one of the 5 modes.
  - After mode selection, read and follow the corresponding file in `modes/`.

- **Second question to user (always):**  
  "Use **full skill cycle** (settings → docs → plan → implementation) or **just do the current task** without full onboarding?"
  - If **full skill cycle** — follow the rules below.
  - If **direct task** — ask only minimal context for the current task; do not overload with settings.

- **At start request two blocks:**
  1. **Settings** — everything that goes into `Docs/DEV_CONFIG.md`: mode, platform(s), orientation, style, resolution, input, toggles (clarifying questions, search ready solutions, ComfyUI, QA per feature, final QA checklist, **Auto mode**). **Auto mode (save time):** ask if desired — when on, agent works as autonomously as possible and batches questions/check requests at the end. For UI separately ask **design source** (screenshots/mockup/ref). If design is from Figma — ask user for export (screenshots, specs, SVG/PNG, code snippet), do not require Figma MCP. Use structured request (AskQuestion or clear list).
  2. **Game design** — asked separately: game idea, mechanics, screens (to fill `GAME_DESIGN.md`).
- **MCP decision is mandatory at start:** ask explicitly "Use Unity MCP on this stage or work without MCP/fallback mode?" and record the choice in `Docs/DEV_CONFIG.md` and `Docs/DEV_PLAN.md`.
- **QA decision is mandatory at start:** ask explicitly and record in `Docs/DEV_CONFIG.md`:
  - "QA per feature: on/off?"
  - "Final QA checklist before handoff: on/off?"
- **Planning in Plan mode:** planning (outline → task plan, write to `GAME_DESIGN.md` and `DEV_PLAN.md`) in Cursor **Plan mode**: agent gathers data, forms implementation plan, user confirms plan, then move to implementation.

### Task size triage (before start)

| Size | Criteria | Process |
|------|----------|---------|
| Micro | ~30 min, local change | No full docs cycle; minimal context + implementation + check |
| Feature | 1 feature/subsystem, several files | Docs light: `DEV_STATE` + `DEV_LOG` if needed |
| Milestone | Large stage/several features/arch decisions | Full skill cycle: `DEV_CONFIG` / `GAME_DESIGN` / `DEV_PLAN` / `DEV_STATE` / `DEV_LOG` |

## Dev mode

Rule: **before starting** always ask for mode from 5 options (`prototype`, `fast`, `standard`, `pro`, `no_ui`) and show [MODE_CHOICE.md](MODE_CHOICE.md).  
After choice — read the mode file from `modes/` and follow it.
Only then ask cycle/settings/MCP.

Common for all modes:
- **All settings and data in ScriptableObject** (NpcData, UiData, GameFightData, etc.).
- **Reuse-first (default):** before implementing **each** feature: (1) **check ready-made** — Unity built-in and installed packages; (2) if needed **search** for mechanics and libraries on **GitHub** and **web** (repos, open code, UPM). Priority: UPM → GitHub/open code → Asset Store → reference code. Do not start coding from scratch without checking. If the feature is very small and simple — code by hand. Toggle: `DEV_CONFIG.md` → "Search ready solutions". **Libraries:** install per [tools/libraries-setup.md](tools/libraries-setup.md) before development (UniTask, DOTween, Newtonsoft.Json and rest as needed).
- Log format: `Debug.Log($"[Feature.Class.Method] ...")` (details and volume in [tools/code-writing.md](tools/code-writing.md)).
- **Agent checks:** agent **must self-check** features: run Play Mode, take game screenshots, try to play (buttons, flow). **During and after Play Mode check console** (Unity MCP: `read_console`) for errors — do not consider check done with unfixed errors. In Standard/Pro — check **per feature** before next. In Fast and Prototype batch checks or one check at stage end are ok. **Before handoff in all modes:** Play Mode + `read_console` + current screenshot.
- QA: writing QA checklists (per feature and final) **depends on `Docs/DEV_CONFIG.md`**. If off — do not write checklists; if on — use template from [reference.md](reference.md) → "QA checklist template".
- Clarifying questions — per mode rules (`modes/*`); toggle in `DEV_CONFIG.md`.
- **Complexity limits by mode:** in `modes/*` these are **guidelines**, not hard limits. Can exceed after explicit agreement with user.
- **Input System policy:**  
  Prototype/Standard: default `Old` or `Both`.  
  Fast/Pro: default `New Input System`.  
  Legacy project: fallback to `Both`/`Old` as needed.

## Required cycle

When **"full skill cycle"** is selected.

Skeleton (details in `modes/*` and [reference.md](reference.md)):
1. **Request mode selection** (one of 5: `prototype`, `fast`, `standard`, `pro`, `no_ui`) and record in docs.
2. **Request settings and game design** — DEV_CONFIG and game idea (GAME_DESIGN). See "Starting a new game".
3. **Request Unity MCP decision** (use MCP / no MCP / try + fallback), and include it into plan/docs.
4. **Request QA decision** (QA per feature on/off, final QA on/off), and include it into `DEV_CONFIG.md`.
5. Clarifying questions (if on and required by mode).
6. Outline → write to `GAME_DESIGN.md`.
7. **Plan (in Plan mode)** → form and write to `DEV_PLAN.md`; user confirms plan before implementation.
8. **MCP preflight gate** (mandatory if user selected `use MCP`):
   - verify Unity MCP connection and core commands availability before coding;
   - if MCP is down, try to set up/fix it first;
   - if still unavailable, **do not start implementation**; continue setup assistance until MCP works, or ask user to explicitly change MCP mode to `no MCP` / `try+fallback`.
9. **Install libraries** — before implementation agent installs per **[tools/libraries-setup.md](tools/libraries-setup.md)**: UniTask, DOTween, Newtonsoft.Json (and rest from that file). Do not start implementation until install done (or confirmed packages already present/not needed).
10. **Docs baseline gate** — verify and create required docs/log folders/files before coding.
11. Implementation by tasks/features → update `DEV_STATE.md` and iteration log.
12. Check (per mode) + required pre-handoff check (Play Mode + `read_console`) + QA per DEV_CONFIG.

### Plan approval gate (mandatory)

After creating/updating the plan and before implementing features/todos, the agent must explicitly ask for user approval and point to the plan file.

Required behavior:
- Ask a direct confirmation question and include plan path, e.g. `Docs/DEV_PLAN.md` (or current generated plan file path).
- If user says **yes/approve**: start implementation.
- If user says **no/not yet**: ask what to change, update plan/docs first, then request approval again.
- Do not start implementation while plan is not explicitly approved.

## Plan mode protocol (explicit)

When Cursor is in **Plan mode**, the agent must produce a concrete implementation structure before coding.

Required output structure in Plan mode:
1. **Scope and assumptions** (what is in/out for current iteration).
2. **Reuse map** (what ready scripts/systems are reused as-is, what wrappers are needed, what is custom code).
3. **Architecture split by folders/files** (Domain/App/Infrastructure/Presentation or chosen mode architecture).
4. **Step-by-step tasks** with done criteria for each step.
5. **Validation plan** (PlayMode checks, console checks, screenshots, QA toggles).

Mandatory Plan mode actions:
- Write/update `Docs/GAME_DESIGN.md` (outline).
- Write/update `Docs/DEV_PLAN.md` (task plan with stages).
- Keep `Docs/DEV_STATE.md` minimal and current after moving to implementation.
- Do not implement code until the user confirms the plan.
- Explicitly ask user if the plan in `Docs/DEV_PLAN.md` is approved before starting feature/todo implementation.
- If scope/requirements changed during discussion, update `Docs/DEV_PLAN.md` before implementation (no stale plan).

For game projects with existing framework/tools, the plan must explicitly list reuse decisions first (framework pages/UI managers, card/deck systems, save systems, etc.), then only add missing logic.

### Mandatory Library Discovery (before plan approval)

Before asking plan approval, agent must run discovery and update `Docs/DEV_PLAN.md` with:
- detected project libraries/frameworks already installed;
- candidate ready solutions (Unity built-in, installed packages, GitHub/UPM/Asset Store);
- selected approach, integration points, and fallback.

Required artifact in plan/docs: **Reuse Decision Matrix**:
- Option,
- Availability in project,
- Pros/cons for this task,
- Decision and reason.

### State-machine execution protocol (mandatory)

Agent must run the process as explicit states with blocking gates:
`intake -> discovery -> plan_draft -> plan_approval -> mcp_gate -> impl_iteration -> validation_iteration -> handoff`.

For each state:
- define input conditions;
- produce required artifacts;
- meet exit criteria before transition;
- on failure move to fail-branch and resolve first.

No transition to implementation is allowed until:
- plan approved;
- MCP gate satisfied according to selected MCP mode.

If **"direct task"** — use simplified flow:
1. Clarify goal and done criteria.
2. Do the task.
3. Check per mode/scope (for Unity: Play Mode + `read_console` before handoff).
4. Short report.

## Project files

All memory and log files — **in `Docs/`**: `Docs/DEV_CONFIG.md`, `Docs/GAME_DESIGN.md`, `Docs/DEV_STATE.md`, `Docs/DEV_PLAN.md`, `Docs/AGENT_MEMORY.md`, `Docs/ARCHITECTURE.md`, `Docs/DEV_LOG/`, `Docs/Screenshots/`. Do not create them in project root. Read order, templates, rules — in [reference.md](reference.md).  
**DEV_STATE** stays small; DEV_PLAN is full plan; iteration log file name **strictly** with date and time (`iteration-NN-YYYYMMDD-HHMM.md`).

### Machine-readable profile (mandatory)

To avoid repeated questions across sessions, keep a persistent profile in:
- `Docs/DEV_PROFILE.json` (source of truth for automation defaults).

Minimum keys:
- `dev_mode`, `skill_mode`, `ui_mode`, `ui_stack`, `mcp_mode`,
- `qa_per_feature`, `qa_final`, `screenshot_policy`,
- `reuse_first`, `library_policy`, `project_frameworks`.

At session start:
- read `Docs/DEV_PROFILE.json` if exists;
- ask only delta questions;
- sync important changes back to profile and `Docs/DEV_CONFIG.md`.

### Docs baseline gate (mandatory, always)

Before implementation starts, agent must verify Docs baseline exists in project and create missing files/folders from templates.

Required baseline:
- `Docs/DEV_CONFIG.md`
- `Docs/GAME_DESIGN.md`
- `Docs/DEV_PLAN.md`
- `Docs/DEV_STATE.md`
- `Docs/AGENT_MEMORY.md`
- `Docs/ARCHITECTURE.md`
- `Docs/UI_BRIEF.md`
- `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` (at least one iteration file)
- `Docs/Screenshots/iter-01/` (or current iteration folder)

Rules:
- If any baseline item is missing, create it immediately before coding.
- If scope/settings changed, update relevant docs before continuing (`DEV_CONFIG`, `DEV_PLAN`, `DEV_STATE`, log).
- Do not report feature implementation complete without docs/log updates.

### Bootstrap scripts (safe usage)

- Prefer:
  - `setup_project.bat "<project-root>"`
  - `setup_source_folders.bat "<project-root>"`
- If no path is passed, scripts try current working directory.
- Scripts validate Unity root (`Assets` + `ProjectSettings`) before creating files.
- Never rely on relative traversal from skill folder for target project selection.

### Docs/DEV_STATE.md format

- **Emoji and structure (required):** use sections with emoji: 🧠 Context · ⚙️ In progress · ⏭️ Next tasks · ⚠️ Blockers · 📸 Last screenshot · 📈 Progress · 📊 Info. At top — **Legend** (🧭): status 🟦 in progress, 🟨 review, 🟥 blocker, 🟩 done; markers `[x]` done, `[ ]` todo, `←` current step.
- **Progress (required):** **📈 Progress** block always: **Feature (current)** — % or micro-plan steps (K / N), status 🟦/🟨/🟥/🟩; **Project (overall)** — M / T tasks from DEV_PLAN, %. Can add bars e.g. `|████░░░░|`.
- **In progress:** current task with micro-plan (numbered list, steps with [x]/[ ] and ← on current). Update on each action.
- Full template — [reference.md](reference.md) → "Docs/DEV_STATE.md template".

## MCP use

Unity MCP and ComfyUI are accelerators.

If user selected `use MCP`, treat MCP as required preflight:
- before implementation, verify MCP connection and required editor checks workflow;
- if unavailable, try to configure/fix MCP first;
- do not implement until MCP works or user explicitly changes MCP mode.

If user selected `no MCP`, continue file/code workflow without MCP.

Details: [tools/unity-mcp.md](tools/unity-mcp.md), [tools/comfyui.md](tools/comfyui.md).

## UI creation

Use project-aware UI strategy:
- if project already uses a UI stack (uGUI/NeoxiderPages/UI Toolkit), keep it by default;
- if no stack is set, propose UI Toolkit as default option;
- if mode is `no_ui`, skip UI creation pipeline entirely.

Details: [tools/ui-builder.md](tools/ui-builder.md). Dynamic elements at runtime — via selected stack API.

Before implementing UI:
- Clarify if design exists (mockup/screenshots/guide).
- If no design — propose basic UI Builder template and ask minimal screen requirements.
- If design in Figma — ask user for exported materials (assets, sizes, typography, colors, code snippet if needed), then implement via UI Builder.

UI intake template: [reference.md](reference.md) → `Docs/UI_BRIEF.md`.  
In `Docs/UI_BRIEF.md` always set `UI Quality Mode` (`quick` / `standard` / `production`).

### UI Toolkit best practices (web-validated)

- Split UI into small UXML screens and reusable components; keep behavior logic in C#.
- For frequently toggled panels, use `display: none` / `display: flex` instead of constant remove/create cycles.
- Cache `Q<T>(name)` references once during page initialization.
- Prefer `transform` / `opacity`-based animations and minimize expensive layout changes per frame.
- Keep shared styles in a common USS, and move screen-specific styling into dedicated USS files.
- Centralize event subscribe/unsubscribe in `OnShow` / `OnHide` / `Dispose` to avoid leaks.
- Build recurring UI blocks as templates (`VisualTreeAsset` + controller), not UXML copy-paste.
- For rare and heavy panels, allow lazy loading (load on demand).

### UI decision table

| Situation | Agent action |
|-----------|--------------|
| Has design (mockup/screenshots/UI kit) | Fill `Docs/UI_BRIEF.md` from it, layout via selected project stack, check in Play Mode + `read_console`. |
| Only text spec | Fill `Docs/UI_BRIEF.md` first (screens, states, interactions), agree unclear points, then implement. |
| No refs and no spec | Fallback: basic UI shell (MainMenu + GameplayHUD + Pause/GameOver), document assumptions in `Docs/UI_BRIEF.md`, show result and ask for changes. |
| Mode = `no_ui` | Skip UI intake and UI implementation; focus on mechanics/systems only. |

### Project profiles / presets

Project-specific rules should live in separate presets under `project-profiles/` (for example `neoxider-pages.md`, `plain-ugui.md`, `ui-toolkit.md`).

Selection rule:
- detect available framework/libraries in project;
- choose matching preset and record in `Docs/DEV_PROFILE.json`;
- if no preset fits, use generic base rules.

### Iteration cycle enforcement (mandatory)

For each feature (or allowed feature block by mode), agent must complete all steps before moving on:
1. Implement.
2. Self-check.
3. Unity check (Play Mode + `read_console`).
4. Artifacts update (`Docs/DEV_STATE.md`, `Docs/DEV_LOG/iteration-*.md`, optional screenshots by policy).
5. Iteration report.

Blocking gate: no next feature until required checks and docs updates are done.

Frequency:
- `standard` / `pro` / `no_ui`: per feature.
- `fast` / `prototype`: batched checks allowed, but block size must follow mode limits.

## Scene hierarchy and bootstrap

- **Generally do not use bootstrap.** Only for specific goals (diagnostics, hypothesis checks, separate tech task); not default architecture.
- For Prototype, Fast, Standard — prefer **manual object creation** via Unity Editor/MCP and explicit inspector references.
- Complex containers and DI — only with clear need (usually Pro).
- Architecture levels and hierarchy template: [tools/architecture-by-mode.md](tools/architecture-by-mode.md).
- Before introducing DI/LifetimeScope/ServiceLocator document a short `why` in `Docs/ARCHITECTURE.md`.

## Unity/C# practices

All style/patterns/logging/comments: **[tools/code-writing.md](tools/code-writing.md)**.

## Error handling

Briefly: compilation must be clean; MCP may fail; verify scene objects via editor state and screenshot.  
Details: [reference.md](reference.md) → "Error handling and common issues".

## Anti-patterns

Briefly (details in [tools/code-writing.md](tools/code-writing.md) and `modes/*`):
- **Do not start without choosing launch mode** — first choose: "full skill cycle" or "direct task". For full cycle ask settings and game design; for direct task ask only minimal context.
- **Do not start implementing a feature without checking ready-made** — check Unity built-in and installed packages first; with Reuse-first on — search GitHub and web for mechanics/libraries. Do not write from scratch what exists in project, package, or open source.
- **Do not skip pre-handoff check** — before handoff always Play Mode + `read_console` + reviewed screenshot.
- **Do not skip MCP setup when user requested it** — if user said `use MCP`, first try to configure/fix MCP and verify it works; do not silently continue as if checks were done.
- **Do not bypass MCP gate** when `use MCP` is selected — implementation is blocked until MCP is confirmed working, unless user explicitly changes MCP mode.
- **Do not add global ServiceLocator in Prototype/Fast without clear reason** — prefer direct refs and simple composition.
- **Do not require Figma MCP** — ask user for design reference and implement via UI Builder; if Figma mockup exists, ask for exported materials.
- **Do not create memory files in root** — only in `Docs/` (DEV_CONFIG, GAME_DESIGN, DEV_STATE, DEV_PLAN, AGENT_MEMORY). Do not skip `Docs/AGENT_MEMORY.md`.
- **Do not create log file without time in name** — only `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md`, not `iteration-NN.md`.
- No hardcoded settings — all in SO.
- Do not forget to update Docs/DEV_STATE, Docs/DEV_PLAN and iteration file in Docs/DEV_LOG.
- Do not run with stale docs: when scope changes, update `Docs/DEV_PLAN.md` and `Docs/DEV_CONFIG.md` before coding.
- Do not skip docs bootstrap: never start coding if `Docs baseline gate` is incomplete.
- Do not bloat DEV_STATE (keep it small).
- Do not continue implementation with broken MCP when mode is `use MCP`.
- **Do not forget to save scene** after changes via Unity MCP (`manage_scene` action=save).
- **Screenshots:** save in **Docs/Screenshots/** (iter-01, iter-02, …). Agent **must review** every screenshot (open image and check content). Do not report success from a screenshot without checking it; if image is wrong — note issue, retake or fix scene.
- **UI at runtime:** when creating UI from code ensure EventSystem in scene; add Button component to buttons and set child Text `raycastTarget = false` (see [tools/code-writing.md](tools/code-writing.md) → "Unity UI (runtime creation)").
- **Script/class/file names:** do not use game or project-specific names (TotalWar, MyGame, etc.) — use role names: GameManager, MainMenuController, RewardPanel, UiData. Details: [tools/code-writing.md](tools/code-writing.md) → "Naming".
