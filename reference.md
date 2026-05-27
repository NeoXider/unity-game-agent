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
| `Docs/Features/` | Standard/Pro feature pages, one file per Feature |
| `Docs/Tasks/` | Standard/Pro task pages, one file per implementation task |
| `Docs/QA/` | Agent-filled feature QA checklists |
| `Docs/QA_AGENT/` | Duplicate independent QA-agent checklists |
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

## Standard/Pro Lead-Dev-QA Docs Flow

For Standard/Pro, this explicit file flow supersedes the simple DEV_PLAN -> DEV_STATE -> DEV_LOG flow below.

```text
DEV_PLAN.md -> Docs/Features/FEAT-*.md -> Docs/Tasks/TASK-*.md
      |                 |                         |
      v                 v                         v
DEV_STATE.md      Docs/QA/FEAT-*-qa.md     DEV_LOG/iteration-NN-*.md
                  Docs/QA_AGENT/FEAT-*-qa.md
```

1. Game Designer and Designer prepare `GAME_DESIGN.md` / `UI_BRIEF.md` when needed; Lead then creates feature pages, task pages, agent QA checklist, and QA-agent duplicate before implementation.
2. Developer phase takes the next task from DEV_PLAN and its task page, then marks DEV_STATE "In progress" with a micro-plan.
3. On task completion, update the task page evidence, DEV_LOG, DEV_STATE, and DEV_PLAN checkbox.
4. On feature completion, Developer/orchestrator runs self-check into `Docs/QA/`, then independent QA role fills `Docs/QA_AGENT/`.
5. If both pass, mark the feature done and continue automatically. If QA cannot complete a required check after 2 attempts, write the degraded report, create a follow-up task, mark the risk, and continue. Ask the user only for blockers or ambiguous product decisions.

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

Use `tools/new-feature-docs.ps1` to generate Standard/Pro feature, task, QA, and QA-agent files from these templates when running on Windows.

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

| # | Step | Expected | Agent result | QA-agent result | Evidence |
|---|------|----------|--------------|-----------------|----------|
| N.1 | [repro step] | [expected] | [agent fills: OK/issue] | [QA pass fills independently] | [path/log] |
| N.2 | ... | ... | ... | ... | ... |
```

- Agent fills `Docs/QA/` after own Play Mode test.
- QA agent or independent second pass fills `Docs/QA_AGENT/`.

---

## Standard/Pro QA Checklist Files

For Standard/Pro, the QA checklist above is implemented as two files:

- `Docs/QA/FEAT-*-qa.md`: Agent fills this after own Play Mode and behavior checks.
- `Docs/QA_AGENT/FEAT-*-qa.md`: QA agent or independent second pass fills this separately.

User review is optional after both pass. If QA cannot complete a required check after 2 attempts, write a degraded report, create a follow-up defect/automation-gap task, and continue. Stop for the user only on blockers that cannot be bypassed with degraded reporting, ambiguity, missing required assets/credentials, or destructive decisions.

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
  "library_policy": "discover_before_plan",
  "project_frameworks": []
}
```
