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
- **UI design only via UI Builder** (UI Toolkit): always do UI via UI Builder (UXML/USS) and UIDocument in scene. No Canvas/uGUI. If the user does not ask otherwise, offer UI Builder as the main path. Before layout always ask for design reference (screenshots, mockup link, style guide, Figma-exported UXML/CSS refs). Details: [tools/ui-builder.md](tools/ui-builder.md). Unity docs: [UI Toolkit](https://docs.unity3d.com/Manual/UIElements.html), [UI Builder](https://docs.unity3d.com/Manual/UIBuilder.html).

Use this goal when configuring and updating.

## Project setup

Briefly:
- Open project as folder `C:\Git\AutoUnity`.
- MCP configured in `.cursor/mcp.json`.
- Details: [tools/unity-mcp.md](tools/unity-mcp.md) and [tools/comfyui.md](tools/comfyui.md).

## When to use

- Request to create/prototype a Unity game.
- Request to implement mechanics step-by-step with editor checks.
- Tasks that need an explicit outline and intermediate stages (not only final code).

## Starting a new game (from scratch)

- **First question to user (always):**  
  "Use **full skill cycle** (settings → docs → plan → implementation) or **just do the current task** without full onboarding?"
  - If **full skill cycle** — follow the rules below.
  - If **direct task** — ask only minimal context for the current task; do not overload with settings.

- **At start request two blocks:**
  1. **Settings** — everything that goes into `Docs/DEV_CONFIG.md`: mode, platform(s), orientation, style, resolution, input, toggles (clarifying questions, search ready solutions, ComfyUI, QA per feature, final QA checklist, **Auto mode**). **Auto mode (save time):** ask if desired — when on, agent works as autonomously as possible and batches questions/check requests at the end. For UI separately ask **design source** (screenshots/mockup/ref). If design is from Figma — ask user for export (screenshots, specs, SVG/PNG, code snippet), do not require Figma MCP. Use structured request (AskQuestion or clear list).
  2. **Game design** — asked separately: game idea, mechanics, screens (to fill `GAME_DESIGN.md`).
- **Planning in Plan mode:** planning (outline → task plan, write to `GAME_DESIGN.md` and `DEV_PLAN.md`) in Cursor **Plan mode**: agent gathers data, forms implementation plan, user confirms plan, then move to implementation.

### Task size triage (before start)

| Size | Criteria | Process |
|------|----------|---------|
| Micro | ~30 min, local change | No full docs cycle; minimal context + implementation + check |
| Feature | 1 feature/subsystem, several files | Docs light: `DEV_STATE` + `DEV_LOG` if needed |
| Milestone | Large stage/several features/arch decisions | Full skill cycle: `DEV_CONFIG` / `GAME_DESIGN` / `DEV_PLAN` / `DEV_STATE` / `DEV_LOG` |

## Dev mode

Rule: **before starting** always ask for settings (including mode) and show [MODE_CHOICE.md](MODE_CHOICE.md).  
After choice — read the mode file from `modes/` and follow it.

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
1. **Request settings and game design** — DEV_CONFIG and game idea (GAME_DESIGN). See "Starting a new game".
2. Clarifying questions (if on and required by mode).
3. Outline → write to `GAME_DESIGN.md`.
4. **Plan (in Plan mode)** → form and write to `DEV_PLAN.md`; user confirms plan before implementation.
5. **Install libraries** — before implementation agent installs per **[tools/libraries-setup.md](tools/libraries-setup.md)**: UniTask, DOTween, Newtonsoft.Json (and rest from that file). Do not start implementation until install done (or confirmed packages already present/not needed).
6. Implementation by tasks/features → update `DEV_STATE.md` and iteration log.
7. Check (per mode) + required pre-handoff check (Play Mode + `read_console`) + QA per DEV_CONFIG.

If **"direct task"** — use simplified flow:
1. Clarify goal and done criteria.
2. Do the task.
3. Check per mode/scope (for Unity: Play Mode + `read_console` before handoff).
4. Short report.

## Project files

All memory and log files — **in `Docs/`**: `Docs/DEV_CONFIG.md`, `Docs/GAME_DESIGN.md`, `Docs/DEV_STATE.md`, `Docs/DEV_PLAN.md`, `Docs/AGENT_MEMORY.md`, `Docs/ARCHITECTURE.md`, `Docs/DEV_LOG/`, `Docs/Screenshots/`. Do not create them in project root. Read order, templates, rules — in [reference.md](reference.md).  
**DEV_STATE** stays small; DEV_PLAN is full plan; iteration log file name **strictly** with date and time (`iteration-NN-YYYYMMDD-HHMM.md`).

### Docs/DEV_STATE.md format

- **Emoji and structure (required):** use sections with emoji: 🧠 Context · ⚙️ In progress · ⏭️ Next tasks · ⚠️ Blockers · 📸 Last screenshot · 📈 Progress · 📊 Info. At top — **Legend** (🧭): status 🟦 in progress, 🟨 review, 🟥 blocker, 🟩 done; markers `[x]` done, `[ ]` todo, `←` current step.
- **Progress (required):** **📈 Progress** block always: **Feature (current)** — % or micro-plan steps (K / N), status 🟦/🟨/🟥/🟩; **Project (overall)** — M / T tasks from DEV_PLAN, %. Can add bars e.g. `|████░░░░|`.
- **In progress:** current task with micro-plan (numbered list, steps with [x]/[ ] and ← on current). Update on each action.
- Full template — [reference.md](reference.md) → "Docs/DEV_STATE.md template".

## MCP use

Unity MCP and ComfyUI are accelerators. **If MCP unavailable** — ask user: help set up MCP or start without (develop via code/files). Do not block development: if user declines setup — continue without MCP.

Details: [tools/unity-mcp.md](tools/unity-mcp.md), [tools/comfyui.md](tools/comfyui.md).

## UI creation

**UI only via UI Builder** (UI Toolkit): UXML/USS in editor, **UIDocument** in scene; code wires element refs, shows/hides panels, attaches handlers. No Canvas/uGUI. Details: [tools/ui-builder.md](tools/ui-builder.md). Unity docs: UI Toolkit, UI Builder. Dynamic elements at runtime — via UI Toolkit API if needed, see [tools/code-writing.md](tools/code-writing.md).

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
| Has design (mockup/screenshots/UI kit) | Fill `Docs/UI_BRIEF.md` from it, layout via UI Builder, check in Play Mode + `read_console`. |
| Only text spec | Fill `Docs/UI_BRIEF.md` first (screens, states, interactions), agree unclear points, then implement. |
| No refs and no spec | Fallback: basic UI shell (MainMenu + GameplayHUD + Pause/GameOver), document assumptions in `Docs/UI_BRIEF.md`, show result and ask for changes. |

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
- **Do not add global ServiceLocator in Prototype/Fast without clear reason** — prefer direct refs and simple composition.
- **Do not require Figma MCP** — ask user for design reference and implement via UI Builder; if Figma mockup exists, ask for exported materials.
- **Do not create memory files in root** — only in `Docs/` (DEV_CONFIG, GAME_DESIGN, DEV_STATE, DEV_PLAN, AGENT_MEMORY). Do not skip `Docs/AGENT_MEMORY.md`.
- **Do not create log file without time in name** — only `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md`, not `iteration-NN.md`.
- No hardcoded settings — all in SO.
- Do not forget to update Docs/DEV_STATE, Docs/DEV_PLAN and iteration file in Docs/DEV_LOG.
- Do not bloat DEV_STATE (keep it small).
- Do not block development on missing MCP; if MCP unavailable — ask: help set up or start without.
- **Do not forget to save scene** after changes via Unity MCP (`manage_scene` action=save).
- **Screenshots:** save in **Docs/Screenshots/** (iter-01, iter-02, …). Agent **must review** every screenshot (open image and check content). Do not report success from a screenshot without checking it; if image is wrong — note issue, retake or fix scene.
- **UI at runtime:** when creating UI from code ensure EventSystem in scene; add Button component to buttons and set child Text `raycastTarget = false` (see [tools/code-writing.md](tools/code-writing.md) → "Unity UI (runtime creation)").
- **Script/class/file names:** do not use game or project-specific names (TotalWar, MyGame, etc.) — use role names: GameManager, MainMenuController, RewardPanel, UiData. Details: [tools/code-writing.md](tools/code-writing.md) → "Naming".
