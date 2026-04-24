# Reference: Templates & Doc Rules

This file contains ONLY templates and doc structure rules. All pipeline/mode/MCP rules are in [SKILL.md](SKILL.md).

---

## Docs Baseline Gate (mandatory)

Before implementation starts, verify and create missing:

| Create | Purpose |
|--------|---------|
| `Docs/DEV_CONFIG.md` | Settings (mode, platform, toggles) |
| `Docs/GAME_DESIGN.md` | Game outline (mechanics, screens, SO) |
| `Docs/DEV_STATE.md` | Current state (from template) |
| `Docs/DEV_PLAN.md` | Task plan (after Plan mode) |
| `Docs/AGENT_MEMORY.md` | Long-term memory (required, never skip) |
| `Docs/ARCHITECTURE.md` | Architecture decisions (standard/pro) |
| `Docs/DEV_PROFILE.json` | Machine-readable persistent settings |
| `Docs/DEV_LOG/` | Iteration log folder |
| `Docs/Screenshots/` | Screenshot folders (iter-01/, iter-02/) |
| First log file | `Docs/DEV_LOG/iteration-01-YYYYMMDD-HHMM.md` |

**Anti-patterns:** Do not create docs in project root. Do not skip AGENT_MEMORY. Do not create log files without datetime.

Bootstrap: `setup_project.bat "<project-root>"` creates all of the above.

---

## Session Start (read order)

1. `Docs/DEV_PROFILE.json` (if exists) → ask only delta questions
2. `Docs/DEV_CONFIG.md` → mode, settings
3. `Docs/GAME_DESIGN.md` → what the game is
4. `Docs/DEV_STATE.md` → current state, iteration N
5. `Docs/AGENT_MEMORY.md` → preferences, decisions, gotchas
6. `Docs/DEV_PLAN.md` → full plan (when choosing task)
7. `Docs/ARCHITECTURE.md` → architecture (if exists)
8. Create new iteration: `Docs/DEV_LOG/iteration-{N+1}-YYYYMMDD-HHMM.md`
9. Create screenshot folder: `Docs/Screenshots/iter-{N+1}/`

---

## Task Flow Across Files

```
DEV_PLAN.md          DEV_STATE.md              DEV_LOG/iteration-NN-*.md
  [ ] Task A  ──→   ⚙️ Task A (in progress)  ──→   ✅ Task A (date, result)
  [ ] Task B         Blockers: [...]
  [ ] Task C         Context: [...]
```

1. Take task from DEV_PLAN → mark `[x]`
2. Move to DEV_STATE → "In progress" with micro-plan
3. On completion → entry in iteration log, remove from DEV_STATE

---

## Templates

Full template files are in `templates/` folder. Use `setup_project.bat` to copy them.

| Doc | Template |
|-----|----------|
| DEV_CONFIG | `templates/DEV_CONFIG.md` |
| GAME_DESIGN | `templates/GAME_DESIGN.md` |
| DEV_STATE | `templates/DEV_STATE.md` (with emoji) |
| DEV_PLAN | `templates/DEV_PLAN.md` |
| AGENT_MEMORY | `templates/AGENT_MEMORY.md` |
| ARCHITECTURE | `templates/ARCHITECTURE.md` |
| UI_BRIEF | `templates/UI_BRIEF.md` |
| Iteration log | `templates/iteration-template.md` |

---

## DEV_STATE.md Format

**Emoji sections (required):**
- 🧭 Legend — status symbols
- 📈 Progress — feature % + project %
- 🧠 Context — 2-3 sentences for quick start
- ⚙️ In progress — current task with micro-plan `[x]/[ ]/←`
- ⏭️ Next tasks — 3-5 upcoming
- ⚠️ Blockers — current issues
- 📸 Last screenshot — link + date
- 📊 Info — stage, iteration number

**Progress block (required):**
```
**Feature (current):** 60% `|██████░░░░|` (3 / 5 steps) · **Status:** 🟦
**Project (overall):** 25% `|██░░░░░░░░|` (3 / 12 tasks) · **Status:** 🟦
```

**Update frequency:** EVERY action. Keep DEV_STATE small and current.

---

## DEV_LOG — Iteration Files

- **Name format (strict):** `iteration-NN-YYYYMMDD-HHMM.md` (e.g. `iteration-01-20250210-1430.md`)
- **Never** `iteration-01.md` without datetime
- One iteration = one work session or logical block
- Not read at session start by default — only previous iteration if DEV_STATE lacks context

---

## Scene Checklist (before handing off feature)

```markdown
# Scene Checklist — [FeatureName]

- [ ] Inspector references set, no Missing.
- [ ] Scene saved (manage_scene action=save).
- [ ] Play Mode smoke test passed.
- [ ] Console clean (read_console): no errors.
- [ ] Final screenshot taken and reviewed by agent.
- [ ] All text uses TextMeshPro (never legacy Text).
```

---

## QA Checklist Template

When QA per feature is enabled in DEV_CONFIG:

```markdown
## N. [Section name]

| # | Step | Expected | Agent check | QA check |
|---|------|----------|-------------|----------|
| N.1 | [repro step] | [expected] | [agent fills: OK/issue] | [empty — user fills] |
| N.2 | ... | ... | ... | ... |
```

- Agent fills "Agent check" after own Play Mode test
- Agent leaves "QA check" empty for user

---

## Iteration Gate Checklist (mandatory before next feature)

- [ ] Implementation done
- [ ] Compile clean (`validate_script` or `refresh_unity` + `read_console`)
- [ ] Play Mode test done
- [ ] `read_console` checked (no new errors)
- [ ] Screenshot saved and reviewed
- [ ] `Docs/DEV_STATE.md` updated
- [ ] `Docs/DEV_LOG/iteration-*.md` updated

---

## Library Discovery Report (before plan approval)

```markdown
# Library Discovery Report

## Existing in project
- [Library] — version / location / usage

## Candidate solutions
| Option | Source | Fits | Risks | Decision |
|--------|--------|------|-------|----------|
| Unity built-in ... | Built-in | Yes/No | ... | Use/Skip |
| Package ... | UPM/GitHub | Yes/No | ... | Use/Skip |

## Reuse Decision Matrix
| Feature | Reuse option | Why | Fallback |
|---------|-------------|-----|----------|
| ... | ... | ... | ... |
```

---

## Recommended Assets Folder Structure

**If project has existing structure → use it.** Only impose this for new empty projects:

```
Assets/
  _source/
    Scripts/
    Editor/
    Data/        # SO assets
    Prefabs/
    Scenes/
    Materials/
    Textures/
    Audio/
    UI/          # UXML/USS or Canvas prefabs
    Resources/

Docs/            # Outside Assets (project root)
  DEV_LOG/
  Screenshots/
```

---

## DEV_PROFILE.json Schema

```json
{
  "dev_mode": "standard",
  "ui_mode": "ui_toolkit",
  "mcp_mode": "use",
  "qa_per_feature": true,
  "qa_final": true,
  "screenshot_policy": "per_feature",
  "reuse_first": true,
  "auto_mode": true,
  "library_policy": "discover_before_plan",
  "project_frameworks": [],
  "text_component": "TextMeshPro"
}
```
