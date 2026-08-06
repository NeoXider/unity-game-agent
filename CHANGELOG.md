# Changelog — Unity Game Agent Skill

All notable changes to this skill are documented here.

---

## [3.3.0] — 2026-08-06

### 🎯 Added — field lessons from a full mobile uGUI project (TropicMania)
- **`project-profiles/plain-ugui.md` grew an adaptivity canon**: one project-wide `CanvasScaler`
  contract (`Scale With Screen Size`, single reference resolution, `Screen Match Mode = Expand`) with
  a guard test over scenes *and* prefabs; the top safe-area rule (100 px with a top pivot/anchor,
  150 px otherwise, against a real ~141 px notch inset) built from anchors and `Screen.safeArea`;
  adaptivity ranked above pixel-perfect mockup matching; a list of layout defects that are cheap to
  measure and were each shipped-and-missed once; and the rule that mockup typos get fixed in the
  product, not copied.
- **`tools/ui-screenshot-truth.md` (new)**: how to produce UI evidence that cannot lie. Never force
  `canvas.scaleFactor` or render at a resolution the player never sees; capture through the Device
  Simulator so `Screen.safeArea` is real; verify each PNG by parsing IHDR; work around
  `DeviceLoader.LoadDevices()` ignoring custom `.device` assets and declare synthetic profiles as
  inset-free. Also: measure before claiming a visual defect, never read PNGs back into an agent's
  context, treat the editor as a single-writer resource, and audit the editor side effects
  (`UnityConnectSettings`, TMP fallbacks, `EditorSettings`, IDE files) that builds cause on their own.

### 🧠 Skill memory
- Six entries covering screenshot truthfulness, measuring instead of eyeballing, one-editor agent
  orchestration, the CanvasScaler/safe-area contract, builder-versus-hand-authored scene ownership,
  and the Input System port of Android Back.

---

## [3.2.0] — 2026-07-02

### 🔧 Improvements (independent audit follow-up)
- **mcp-commands.md rewritten 409 → 40 lines**: now covers only installing (manifest snippet + rules)
  and enabling the adapter (recent versions auto-start on editor open). Static command catalogs are
  gone by design — tool usage comes from live MCP tool schemas and the dedicated `unity-mcp-skill`.
- **Single source of truth for DEV_PROFILE**: canonical schema is `templates/DEV_PROFILE.json` only
  (now includes `pattern`, `minimal_change`, `preserve_serialized_contracts`); SKILL.md and
  reference.md link to it instead of duplicating the JSON.
- **Field-tested gotchas** moved to `tools/mcp-provider-neutral.md` (overlay-canvas screenshots,
  paused/unfocused editor, `ExecuteEvents` clicks for `IPointerClickHandler`, inactive-object lookup,
  C#6 code-execution limits, stale `UnityLockfile`); input-injection recipe added to
  `tools/playmode-qa-automation.md`.
- **Contradictions resolved**: standard-mode tests are "per task declaration" in POLICY_MATRIX;
  SKILL.md core loop aligned with README (+DESIGN/+QA for standard/pro); mode-specific minimums
  now defer to POLICY_MATRIX; bounded-QA rules canonicalized in `tools/playmode-qa-automation.md`.
- **Validator**: new broken-relative-link check across all md (templates excluded — placeholder links);
  mojibake heuristic no longer flags Russian-language AUDIT files; profile fields validated in the
  template only; mode checklists condensed to final gates.
- Accuracy fixes: `ChangePageByName` takes the PageId asset name; Save System prompt is reuse-first;
  skill name unified to `unity-game-agent`.

## [3.1.0] — 2026-06-30

### ✨ New Features
- **Runtime UI Toolkit profile (Unity 6.5 / `PanelRenderer`)** — vendored the standalone `uitk-6-5`
  skill (author: Neoxider) into `project-profiles/ui-toolkit/`: a `PanelRenderer`-first router plus
  `docs/` (architecture, UXML/USS, binding, animation, shaders/materials/filters, performance,
  verification), `examples/`, and `templates/`. Covers USS filters and `-unity-material`/UI Shader Graph.
  From Unity 6.5, prefer `PanelRenderer` for new runtime UI; keep `UIDocument` on 6.4 and earlier or for existing screens unless migrating intentionally.

### 🔧 Improvements
- SKILL.md UI section and Reference Map now point at the UI Toolkit profile.
- `project-profiles/ui-toolkit.md` (thin flat profile) replaced by `project-profiles/ui-toolkit/README.md`.
- Independent-audit follow-up: reconciled the NeoxiderTools opt-in anti-pattern with pattern stack-defaults, softened "DOTween (Pro)" to free-DOTween-by-default, clarified PanelRenderer-vs-UIDocument as preference (not global migration), and made the UI Toolkit docs map link exact filenames.

### Notes
- Vendored `docs/`/`examples/` were translated to English. Source repo:
  github.com/NeoXider/uitk-6-5-unity-skill (target Unity 6.5 / 6000.5).

---

## [3.0.0] — 2026-06-30

### ✨ New Features
- **Development Patterns** — pluggable, opinionated playbooks layered on the universal pipeline. Patterns
  live under `patterns/`, are auto-selected by project detection or request match, and override universal
  defaults where they conflict while keeping preflight/verification/QA intact. See `patterns/README.md`.
- **`casual-neoxider` pattern** — merged the standalone casual-games method into this skill as the first
  pattern: NeoxiderTools (`Neo.*`) + NeoxiderPages + DOTween via MCP. `patterns/casual-neoxider/` ships
  the entry playbook plus `managers.md`, `patterns.md`, and `scene-skeleton.md`. When selected,
  NeoxiderTools reuse is the default instead of an opt-in question.

### 🔧 Improvements
- `DEV_PROFILE.json` gains `"pattern"` (`auto` | `none` | `<name>`); Session Routing now selects a pattern.
- Provider-neutral framing: README and docs no longer assume a single client (Claude Code / Codex / Cursor).
- Removed all Figma references from templates; genericized hardcoded personal paths in the merged content.

### 🗑️ Removed
- `project-profiles/neoxider-pages.md` — superseded by the `casual-neoxider` pattern.

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
