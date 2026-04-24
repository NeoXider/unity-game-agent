# Changelog — Unity Game Agent Skill

All notable changes to this skill are documented here.

---

## [2.0.0] — 2025-04-24

### 🔥 Breaking Changes
- Removed 16 obsolete files (MODE_CHOICE, MODE_DETAILS, modes/prototype, modes/no_ui, tools/unity-mcp, tools/unity-editor, tools/architecture-by-mode, tools/ui-builder, tools/comfyui, tools/figma, tools/index, setup_source_folders.bat, scripts/)
- Modes reduced from 5 (prototype/fast/standard/pro/no_ui) to 3 (fast/standard/pro) + `ui_mode` flag
- NoUI is now a flag (`ui_mode: no_ui`), not a separate mode
- All rules consolidated into SKILL.md — no more fragmented duplicates

### ✨ New Features
- **Session Entry Decision Tree** — handles all scenarios: resume, new project, existing project, quick fix
- **Quick Fix path** — detected FIRST, bypasses pipeline entirely. Has its own DoD.
- **Sub-Agent Architecture** — orchestrator + coding/QA/report agents with verification
- **MCP catalog** — 42+ tools documented in mcp-commands.md (was ~10)
- **MCP file_only fallback** — clear communication template and operation matrix
- **POLICY_MATRIX.md** — single source of truth for mode cadences
- **Pre-Flight Checklist** — 5 checks before BUILD starts
- **Standardized Delivery Report** — template for SHIP phase final message
- **Error Recovery flows** — compilation, Play Mode crash, MCP down, stuck feature
- **DEV_PLAN Feature Format** — concrete example with checkboxes
- **Agent First Message example** — exact format for INTAKE

### 🔧 Improvements
- **UI Strategy**: UI Toolkit (default) / uGUI + TMP_Pro / NoUI (null-safe stubs)
- **Null-safe pattern mandatory** for both uGUI AND NoUI
- **TextMeshPro mandatory** — legacy Text banned in all modes
- **No obvious comments** — use Debug.Log with `[Feature.Class.Method]` pattern. XML docs and TODO allowed.
- **Feature decomposition mandatory** in ALL modes (fast: 2-4, standard: 4-8, pro: 8+)
- **Priority labels**: REQUIRED / DEFAULT / OPTIONAL throughout SKILL.md
- **Compile check clarified**: validate_script (after code) vs refresh_unity (after assets)
- **Play Mode frequency fixed**: fast=batch(2-4), standard=per feature, pro=per task
- **Agent Bootstrap** — creates Docs/ directly via file tools, not bat scripts
- **setup_project.bat** simplified — standalone, no dependencies

### 📁 File Structure (after migration)
```
SKILL.md, mcp-commands.md, reference.md, PROMPTS.md, README.md,
POLICY_MATRIX.md, CHANGELOG.md, setup_project.bat,
modes/{fast,standard,pro}.md,
tools/{code-writing,core-mechanics,libraries-setup}.md,
templates/ (9 files), project-profiles/ (3 files)
```

### Migration Notes
- If you had custom modes in `modes/prototype.md` or `modes/no_ui.md` — they're now in `modes/fast.md` and `ui_mode` flag
- If you referenced `tools/unity-mcp.md` — use `mcp-commands.md` instead
- If you used `scripts/dev_complete_task.bat` — agent now updates Docs/ directly
- `MODE_CHOICE.md` and `MODE_DETAILS.md` content is now in SKILL.md → Modes section

---

## [1.0.0] — 2025-01-xx (original)

- Initial release with 5 modes, ~10 MCP tools, 27+ files
- Fragmented documentation across 15+ files
