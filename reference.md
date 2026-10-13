# Reference: Templates & Doc Rules

This file contains ONLY templates and doc structure rules. All pipeline/mode/MCP rules are in [SKILL.md](SKILL.md).

---

## Docs Baseline Gate

For full-pipeline bootstrap, create only needed files. A direct tracked item reuses sufficient existing
requirements and one task/feature brief; no mandatory new GDD/log/checklist tree.
[POLICY_MATRIX.md](POLICY_MATRIX.md) → "Docs Requirements" is the source of truth for which are
`REQUIRED` / `OPTIONAL` per mode; this table only gives their purpose. Quick Fix creates none of them.

| Create | Purpose | When |
|--------|---------|------|
| `Docs/DEV_CONFIG.md` | Settings (mode, platform, toggles) | always |
| `Docs/DEV_PROFILE.json` | Machine-readable persistent settings | always |
| `Docs/DEV_STATE.md` | Current state (from template) | always |
| `Docs/AGENT_MEMORY.md` | Long-term memory (never skip) | always |
| `Docs/DEV_LOG/` + `iteration-01-YYYYMMDD-HHMM.md` | Iteration log folder and first entry | always |
| `Docs/Screenshots/` | Required reviewed captures | visual/runtime-visible checks |
| `Docs/GAME_DESIGN.md` | Game outline (mechanics, screens, SO) | when a sufficient TZ/GDD is missing |
| `Docs/DEV_PLAN.md` | Task plan (after Plan mode) | standard/pro; optional in fast |
| `Docs/ARCHITECTURE.md` | Affected architecture decisions | actual boundary/architecture work |
| `Docs/Features/` or `Docs/Tasks/` | One canonical work brief with Developer/QA sections | tracked work |
| Separate `Docs/QA/` | Expanded tracking checklist | explicit expanded tracking |
| `Docs/QA_AGENT/` | Legacy independent duplicate | explicit duplicate request only |

**Anti-patterns:** Do not create a competing docs tree or duplicate results into QA/QA_AGENT/log files
by default. Preserve existing profiles/docs and tracking links without migration churn.

Bootstrap: `setup_project.bat "<project-root>"` scaffolds the tree; delete or leave empty the folders
the selected mode does not require.

---

## Session Start (read order)

1. `Docs/DEV_PROFILE.json` (if exists) → ask only delta questions
2. `Docs/DEV_CONFIG.md` → mode, settings
3. Existing TZ/GDD → relevant requirements, only when needed
4. `Docs/DEV_STATE.md` → current state, iteration N
5. `Docs/AGENT_MEMORY.md` → preferences, decisions, gotchas
6. `Docs/DEV_PLAN.md` → full plan (when choosing task)
7. `Docs/ARCHITECTURE.md` → architecture (if exists)
8. Read the selected brief and relevant linked evidence; do not load full completed-task history.
9. Create evidence/log folders only when the selected task needs them.

---

## Standard/Pro Lead-Dev-QA Docs Flow

For standard/pro, the default is one brief and two sequential result owners:

```text
Existing TZ/GDD -> work brief -> Developer handoff -> independent QA result
                                      ^                    |
                                      +---- correction ----+
QA pass -> optional existing-GDD alignment -> closure/state link
```

1. Reuse sufficient requirements. Design/Lead passes resolve real gaps; otherwise skip them.
2. Brief holds scope/acceptance/reuse decision and risk-selected verification, with Developer/QA owner sections.
3. Developer implements and hands off the final revision after relevant compile/selfcheck. QA inspects
   actual reuse and independently drives changed player outcomes; docs-only work invokes no Unity.
4. Failures return one expected/actual reproduction with evidence/revision and owner/action. After
   corrections, rerun failed/affected checks and cite unchanged valid evidence with scope/environment.
5. After at most two genuine failures on one path, record fail/blocked (legacy degraded), not done;
   unrelated safe work can continue. Required checks must pass before closure. Optional GDD alignment
   follows QA without regenerating the specification.

Fast/Quick Fix uses brief DEV_PLAN/DEV_STATE/DEV_LOG tracking. Feature/task/QA pages are optional unless the user requests stronger tracking.

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
| FEATURE | `templates/FEATURE.md` |
| TASK | `templates/TASK.md` |
| QA checklist | `templates/QA_CHECKLIST.md` |
| QA-agent duplicate | `templates/QA_AGENT_CHECKLIST.md` |
| AGENT_MEMORY | `templates/AGENT_MEMORY.md` |
| ARCHITECTURE | `templates/ARCHITECTURE.md` |
| UI_BRIEF | `templates/UI_BRIEF.md` |
| Iteration log | `templates/iteration-template.md` |

Role subskills live in `roles/`: `game-designer.md`, `designer.md`, `lead.md`, `developer.md`, and `qa.md`.

`tools/new-feature-docs.ps1` creates one compact Feature brief by default. `-Tasks` becomes inline
checklist items. `-DetailedTracking` explicitly creates separate Task/QA records; legacy
`-CreateIndependentQa` also requests the separate QA_AGENT duplicate. Neither flag is needed merely
to run independent QA. Existing files are preserved and no absent-file links are generated.

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

**Update frequency:** after a meaningful task/checkpoint or when state changes. Keep DEV_STATE small and current; do not churn it after every command.

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
- [ ] Scene saved through the MCP scene-save capability.
- [ ] Play Mode smoke test passed.
- [ ] Console clean (read_console): no errors.
- [ ] Final screenshot taken and reviewed by agent.
- [ ] All text uses TextMeshPro (never legacy Text).
```

---

## QA Checklist Template

For explicit expanded tracking, legacy checklist templates remain available. The default compact
brief has separate Developer and independent QA owner sections; evidence is recorded once.

```markdown
## N. [Section name]

| # | Step | Expected | Agent result | QA-agent result | Evidence |
|---|------|----------|--------------|-----------------|----------|
| N.1 | [repro step] | [expected] | [agent fills: OK/issue] | [QA pass fills independently] | [path/log] |
| N.2 | ... | ... | ... | ... | ... |
```

- Developer records relevant selfcheck in its owner section; QA records independent outcomes in its own.
- Explicit legacy records can link the canonical brief/evidence; do not copy every result between files.

---

## Standard/Pro QA Checklist Files

One task/feature brief is sufficient, including independent QA. Separate QA/QA_AGENT files are
explicit expanded tracking or existing project conventions, not a new default. Legacy profiles
remain readable; an old generated duplicate setting alone is not a request to create extra files.

Pass requires the relevant player/risk checks and actual reuse evidence. Missing/empty/unsupported
required checks stay blocked with an owner/action; engine/unit/source/screenshot checks do not replace
runtime/UI/native/network outcomes. Human review remains optional unless a real decision requires it.

---

## Iteration Gate Checklist (mandatory before next feature)

- [ ] Implementation done
- [ ] Compile clean (import/compile readiness + `read_console`)
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
| Option | Source | Reuse mode | Fits | Integration risks | Decision |
|--------|--------|------------|------|-------------------|----------|
| Unity built-in ... | Built-in/docs | direct reuse | Yes/No | ... | Use/Skip |
| Package ... | UPM/GitHub/Asset Store | direct reuse/adapt/reference-only | Yes/No | ... | Use/Skip |
| Open-source game/feature slice ... | GitHub/source repo | direct reuse/adapt/reference-only | Yes/No | ... | Use as package/reference/skip |
| Asset pack/sample ... | Asset Store/open asset repo/Unity sample | import/adapt/reference-only | Yes/No | ... | Import/adapt/skip |
| Shipped game/tutorial/technical breakdown ... | Public article/video/repo/wiki | reference-only | Yes/No | ... | Reimplement behavior/skip |

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
  Features/
  Tasks/
  QA/
  QA_AGENT/
```

---

## DEV_PROFILE.json Schema

The canonical schema (all fields with defaults) is the template itself:
[templates/DEV_PROFILE.json](templates/DEV_PROFILE.json). SKILL.md → "Runtime Policy" explains what the
important fields *mean* but never repeats the JSON; `tools/validate-skill.ps1` checks that the template
carries every required field and that SKILL.md links it. Do not copy the JSON into more places.
