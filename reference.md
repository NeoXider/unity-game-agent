# Reference: project file templates

This file contains:
- Project “memory” templates (DEV_* / ARCHITECTURE / AGENT_MEMORY),
- Rules for `DEV_STATE.md` (including emoji/progress),
- Minimal folder structure agreements.

Instrumental and how-to content is in `tools/*`:
- **Unity MCP:** [tools/unity-mcp.md](tools/unity-mcp.md)
- **ComfyUI:** [tools/comfyui.md](tools/comfyui.md)
- **Unity Editor:** [tools/unity-editor.md](tools/unity-editor.md)
- **Code and practices (SO, logging, comments):** [tools/code-writing.md](tools/code-writing.md)

## Typical order per stage

1. **Before task:** mark `[x]` in `Docs/DEV_PLAN.md`, add task to “In progress” in `Docs/DEV_STATE.md`, set start time.
2. Make changes (scripts/scene via repo or MCP). **If scene was changed via MCP** — **save scene** (`manage_scene` action=save).
3. **In Play Mode** — check console (`read_console`) for errors during and after check; do not consider stage done until errors are fixed.
4. Request `editor_state` or `read_console` if needed.
5. **On progress:** update `Docs/DEV_STATE.md`: “⚙️ In progress”, micro-plan steps ([x]/[ ]/←), **📈 Progress** (feature: K/N steps, status; project: M/T tasks). Add screenshot if needed. Use emoji and structure from template. **After taking a screenshot — review it:** open the image and confirm it shows expected (game in Play Mode, correct screen). If empty or wrong — do not consider task done; retake or note issue.
6. **After task done:** remove from `Docs/DEV_STATE.md`, add entry to current iteration file in `Docs/DEV_LOG/` (date, result, files, screenshot). Update “Next tasks” and **📈 Progress** in DEV_STATE.
7. In the reply: what was done, what to check in Unity, stage status. **Always mention that state files were updated.** Do not report “implementation complete” from a screenshot without reviewing it.

## Definition of Done (DoD) per feature

Feature is done only when all are met:

- [ ] **Compile clean** — no compile errors.
- [ ] **Play Mode smoke** — basic feature scenario runs.
- [ ] **`read_console` clean** — no new errors in console after check.
- [ ] **Scene saved** — scene changes saved (`manage_scene` action=save / Ctrl+S).
- [ ] **Screenshot reviewed** — screenshot taken and reviewed by agent.
- [ ] **Docs updated** — `Docs/DEV_STATE.md` updated; on step/feature completion — `Docs/DEV_LOG/iteration-*.md`.

## Project files

**Location: all memory and log files in `Docs/`.** Do not create DEV_CONFIG, GAME_DESIGN, DEV_STATE, DEV_PLAN, AGENT_MEMORY, ARCHITECTURE in project root; only `Docs/DEV_CONFIG.md`, `Docs/GAME_DESIGN.md`, etc.

### Machine-readable profile

Use `Docs/DEV_PROFILE.json` as persistent source of truth to avoid repeated intake questions.

Recommended minimal schema:

```json
{
  "dev_mode": "standard",
  "skill_mode": "full_cycle",
  "ui_mode": "enabled",
  "ui_stack": "ugui",
  "mcp_mode": "use",
  "qa_per_feature": true,
  "qa_final": true,
  "screenshot_policy": "per_feature",
  "reuse_first": true,
  "library_policy": "discover_before_plan",
  "project_frameworks": ["NeoxiderPages", "Neo.Cards"]
}
```

Session start rule:
- read profile first;
- ask only delta questions;
- update profile after approved changes.

**On new session start** the agent reads files in this order (paths relative to project root):

| File | Purpose | Size | When to update | Read at start |
|------|---------|------|----------------|---------------|
| **Docs/DEV_CONFIG.md** | Settings: mode, toggles, platform(s), orientation, style | Small | When settings change | **1st (always)** |
| **Docs/GAME_DESIGN.md** | Game design: outline, mechanics, screens, SO | Medium | When outline approved | **2nd** |
| **Docs/DEV_STATE.md** | Context + in progress + next tasks + blockers + iteration | **Small (always)** | Every action | **3rd** |
| **Docs/AGENT_MEMORY.md** | Long-term memory: preferences, decisions, conventions, gotchas | Small–medium | When something important | **4th (always if exists)** |
| **Docs/DEV_PLAN.md** | Full plan: all features/tasks with checkboxes | Medium | When planning | **5th (when choosing task)** |
| **Docs/ARCHITECTURE.md** | Architecture: systems, dependencies, decisions | Medium | When starting implementation | **6th (if exists)** |
| **Docs/DEV_LOG/** | Iteration logs. File name **strict:** `iteration-NN-YYYYMMDD-HHMM.md` (date and time at creation). Not `iteration-NN.md` without time. | Each small | On task completion | As needed: **only previous iteration** |
| **Docs/Screenshots/** | Screenshots by iteration: `iter-01/`, `iter-02/`, ... Agent **must** review every screenshot. | Grows | On screenshots | On request only |

### Why this structure

- **Docs/DEV_STATE.md** — small, always current. “Context” (2–3 sentences for quick understanding). Does not grow.
- **Docs/AGENT_MEMORY.md** — long-term memory. Everything the agent learned: preferences, decisions, conventions, gotchas. Read at start. **Create when starting from scratch** (with other memory files).
- **Docs/DEV_PLAN.md** — full plan. Read when planning, not every action.
- **Docs/DEV_LOG/** — iteration logs. File name **strict** `iteration-NN-YYYYMMDD-HHMM.md`. Not read by default at start; **if needed — only previous iteration**.
- **Docs/Screenshots/** — by iteration (iter-01, iter-02, ...). Agent **must** review each screenshot. Chronological order.

### VCS safety rules (Unity)

- Move/rename assets **only in Unity Editor** so `.meta` move with them.
- `.meta` files must be in VCS (do not exclude).
- No spaces in file/folder names (use `CamelCase` / `snake_case`).
- Keep sandbox/experimental scenes separate (e.g. `Assets/_source/Scenes/Sandbox/`) from production.

### Agent rules on new session start

1. Read `Docs/DEV_CONFIG.md` → mode and settings. **If missing (from scratch):** first ask agent launch mode: “full skill cycle” or “direct task”.  
   - **Full skill cycle:** ask for settings and game design; for QA ask and write in DEV_CONFIG: “QA per feature” (on/off), “final QA checklist” (on/off).  
   - **Direct task:** ask only minimal data for current task, no full onboarding.  
   Optionally ask **“Auto mode (save time)”**: when on, agent works as autonomously as possible and batches questions/check requests at the end. Then **create in Docs/** all memory files: `Docs/DEV_CONFIG.md`, `Docs/GAME_DESIGN.md`, `Docs/DEV_STATE.md`, `Docs/DEV_PLAN.md`, **`Docs/AGENT_MEMORY.md`** (required), and if needed `Docs/ARCHITECTURE.md`. Create `Docs/DEV_LOG/`, `Docs/Screenshots/`. Do not create these in project root (anti-pattern).
2. Read `Docs/GAME_DESIGN.md` → what the game is. If missing — after getting settings and game design, write outline to `Docs/GAME_DESIGN.md`.
3. **Planning** (create/update `Docs/DEV_PLAN.md`) in **Plan mode**: agent forms plan, user confirms, then implementation.
4. **Before implementation** install libraries per **[tools/libraries-setup.md](tools/libraries-setup.md)**: UniTask, DOTween, Newtonsoft.Json (and rest from that file). Do not start first feature without install or without confirming packages are already in project.
5. Read `Docs/DEV_STATE.md` → **“Context”** gives quick understanding. Get iteration number N.
6. Read `Docs/AGENT_MEMORY.md` → preferences, decisions, conventions, gotchas. If file missing — **create `Docs/AGENT_MEMORY.md`** in this session (empty from template or with first entry).
7. **Create new iteration:** log file **strictly** `Docs/DEV_LOG/iteration-{N+1}-{YYYYMMDD}-{HHMM}.md` (current date and time at creation). **Do not create** `iteration-NN.md` without date and time. Screenshot folder: `Docs/Screenshots/iter-{N+1}/`. Update iteration number in `Docs/DEV_STATE.md`.
8. Read `Docs/DEV_PLAN.md` → full plan (if choosing a task).
9. Read `Docs/ARCHITECTURE.md` → architecture (if exists).
10. Log iterations: **do not read** by default. If context from `Docs/DEV_STATE.md` is not enough — read **only the previous** iteration in `Docs/DEV_LOG/`. Older iterations — do not read.

### Task flow across files

```
Docs/DEV_PLAN.md     Docs/DEV_STATE.md         Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md
  [ ] Task A  ──→   ⚙️ Task A           ──→   ✅ Task A (date, result)
  [ ] Task B         (in progress)
  [ ] Task C         Blockers: [...]
                    Context: [...]
```

1. Task taken from `Docs/DEV_PLAN.md` → mark `[x]`.
2. Moved to `Docs/DEV_STATE.md` → “In progress”.
3. On completion → entry in current iteration file in `Docs/DEV_LOG/`, remove from `Docs/DEV_STATE.md`.

### Iteration lifecycle

```
New session → Docs/DEV_CONFIG → Docs/GAME_DESIGN → Docs/DEV_STATE (iteration=N) → Docs/AGENT_MEMORY
    → Create Docs/DEV_LOG/iteration-{N+1}-YYYYMMDD-HHMM.md (with current time) → Docs/DEV_PLAN → Docs/ARCHITECTURE
    → Work, write tasks to iteration file
    → Important finding → write to Docs/AGENT_MEMORY.md
    → End session → “Context” in Docs/DEV_STATE.md + “Summary” in iteration file
```

### Checklist when starting from scratch (what to create)

When creating project from scratch the agent **must** create in **Docs/** (not in root):

| Create | Purpose |
|--------|---------|
| `Docs/DEV_CONFIG.md` | Settings (mode, platform, orientation, toggles) |
| `Docs/GAME_DESIGN.md` | Game outline (mechanics, screens, SO) |
| `Docs/UI_BRIEF.md` | UI input (screens, style, states, interactions, assets). Create when working on UI. |
| `Docs/DEV_STATE.md` | Current state (from template) |
| `Docs/DEV_PLAN.md` | Task plan (after Plan mode) |
| **`Docs/AGENT_MEMORY.md`** | **Required.** Long-term memory (empty from template or with first entry). Do not skip. |
| `Docs/ARCHITECTURE.md` | As needed (Standard/Pro) |
| `Docs/DEV_PROFILE.json` | Machine-readable persistent settings/profile |
| Folder `Docs/DEV_LOG/` | For iteration files |
| Folder `Docs/Screenshots/` | For screenshots by iteration (agent must review every screenshot) |
| First log file | `Docs/DEV_LOG/iteration-01-YYYYMMDD-HHMM.md` (current date and time) |

**Anti-patterns:** do not create DEV_*, GAME_DESIGN, AGENT_MEMORY in project root; do not create log file without date and time in name (`iteration-01.md` is wrong); do not skip `Docs/AGENT_MEMORY.md`.

---

## Templates (full content)

Full template content is in the **`templates/`** folder (English). Use `setup_project.bat` to copy them to `Docs/` or copy manually.

| Doc | Template file |
|-----|----------------|
| DEV_CONFIG | `templates/DEV_CONFIG.md` |
| GAME_DESIGN | `templates/GAME_DESIGN.md` |
| UI_BRIEF | `templates/UI_BRIEF.md` |
| DEV_STATE | `templates/DEV_STATE.md` (with emoji: 🧭📈🧠⚙️⏭️⚠️📸📊) |
| DEV_PLAN | `templates/DEV_PLAN.md` |
| AGENT_MEMORY | `templates/AGENT_MEMORY.md` |
| ARCHITECTURE | `templates/ARCHITECTURE.md` |
| Iteration log | `templates/iteration-template.md` |

---

## Scene Checklist (before handing off a feature)

```markdown
# Scene Checklist — [FeatureName]

- [ ] Inspector references set, no Missing.
- [ ] Scene saved (`manage_scene` action=save).
- [ ] Play Mode smoke test passed (basic scenario works).
- [ ] Console clean (`read_console`): no errors after check.
- [ ] Final screenshot taken and reviewed by agent.
```

---

## QA checklist template (Docs/QA_CHECKLIST_*.md)

Final QA checklist and “per feature” checklists must have **four elements**:

1. **Step** — how to reproduce (user action).
2. **Expected behavior** — what should happen.
3. **Agent check** — filled by **agent** after own check (Play Mode, screenshots, tried to play): result (OK / issue description). Agent fills before passing checklist on.
4. **QA check** — leave **empty** when creating checklist; **QA (user/tester)** fills when agent hands off for check.

Example table per block (screen/section):

```markdown
## N. [Section name]

| # | Step | Expected behavior | Agent check | QA check |
|---|------|--------------------|-------------|----------|
| N.1 | [repro step] | [what should happen] | [agent fills after check: OK or issue] | [empty — QA fills when asked] |
| N.2 | ... | ... | ... | ... |

Optional: space for QA comments after block.
```

- Agent fills **“Agent check”** from own check (played, screenshots).
- Agent leaves **“QA check”** empty and explicitly asks QA to fill after check (e.g. at top or end of file).

---

## Library Discovery Report template

Create before plan approval (`discovery` state).

```markdown
# Library Discovery Report

## Existing in project
- [Library/System] — version / location / usage

## Candidate solutions
| Option | Source | Fits requirements | Risks | Decision |
|--------|--------|-------------------|-------|----------|
| Unity built-in ... | Built-in | Yes/No | ... | Use/Skip |
| Package ... | UPM/GitHub/Asset Store | Yes/No | ... | Use/Skip |

## Reuse Decision Matrix
| Feature | Reuse option | Why chosen | Fallback |
|---------|--------------|------------|----------|
| ... | ... | ... | ... |
```

---

## Iteration gate checklist (mandatory)

Before moving to next feature/block:

- [ ] Implement step done.
- [ ] Self-check done.
- [ ] Play Mode check done.
- [ ] `read_console` checked (no new errors).
- [ ] `Docs/DEV_STATE.md` updated.
- [ ] `Docs/DEV_LOG/iteration-*.md` updated.
- [ ] Screenshot saved/reviewed if policy is enabled.

---

## DEV_LOG — iteration folder

Log is split into iterations. One iteration = one work session (or logical block). Files in `Docs/DEV_LOG/`. Not read at start — only on demand.

**File name:** `iteration-NN-YYYYMMDD-HHMM.md` (e.g. `iteration-01-20250210-1430.md`). **Folder:** `Docs/Screenshots/iter-NN/`.

**Rules:** See “Iteration lifecycle” above. Full iteration template: `templates/iteration-template.md`.

---

## ScriptableObject (minimal)

Rule: **all settings and data in ScriptableObject** (`Assets/_source/Data/`). Details: [tools/code-writing.md](tools/code-writing.md).

Minimal SO class:

```csharp
using UnityEngine;

[CreateAssetMenu(fileName = "NewData", menuName = "GameData/NewData")]
public sealed class NewData : ScriptableObject
{
    [Tooltip("Display name (for UI).")]
    public string displayName;
}
```

---

## Recommended Assets folder structure

```
Assets/
  _source/     # all agent/user-created
    Art/
    Audio/
    Data/      # SO assets
    Prefabs/
    Scenes/
    Scripts/
    Materials/
    Textures/
    UI/
    Resources/ # Unity Resources (if needed)
  ...          # third-party packages

Docs/          # Outside Assets (project root)
  DEV_LOG/     # iteration-NN-YYYYMMDD-HHMM.md
  Screenshots/ # iter-NN/
```

Details and examples by mode: [tools/unity-editor.md](tools/unity-editor.md).

---

## Tools and common issues (links)

Guides and troubleshooting are in `tools/*`:

- Unity MCP (patterns, tools, diagnostics): [tools/unity-mcp.md](tools/unity-mcp.md)
- ComfyUI (workflow, prompts, Import Settings, fallback): [tools/comfyui.md](tools/comfyui.md)
- Unity Editor (folders, scenes, PlayMode check): [tools/unity-editor.md](tools/unity-editor.md)
- Code/SO/logging/comments: [tools/code-writing.md](tools/code-writing.md). **Namespaces:** only in Pro mode; in Prototype/Standard/Fast do not use C# namespaces (default scope).

---

## Links

- [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp) — package in project; server starts in Unity (Window → MCP for Unity → Start Server).
- MCP setup and practices: `tools/*` and [SKILL.md](SKILL.md).
- Ready prompts: [PROMPTS.md](PROMPTS.md).
- Mode choice: [MODE_CHOICE.md](MODE_CHOICE.md).
