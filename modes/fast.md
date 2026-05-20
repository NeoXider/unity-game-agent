# Mode: Fast

**For:** Validate idea quickly OR get to playable build fast. Merges former Prototype and Fast modes.

## Scope Limits (guidelines, not hard limits)
- Mechanics: **1–4**
- Screens: **1–4** (0 if `ui_mode = no_ui`)
- Scenes: **1–3**
- Features per iteration: **up to 4** (batch check)

## Pipeline Adjustments

### INTAKE
- Questions: **1–3 max** before plan. No questions during BUILD.
- If user gives enough info → start immediately.

### PLAN
- Minimal outline: genre, key mechanics, screens (if any), SO list.
- Big stages (2–3), no detailed checklists per stage.
- Reuse-first: quick check (1–5 min), if nothing obvious → code by hand.

### BUILD
- **Batch checks allowed:** can implement 2–4 features, then do one Play Mode check for the batch.
- Compile check (`refresh_unity` + `read_console`) still required after EVERY feature.
- Scene save after every batch.
- Screenshots after each batch (not each feature).
- DEV_STATE update after each batch.

### VERIFY
- Play Mode + `read_console` + final screenshot — **required before handoff**.
- No skipping the final verification even in fast mode.

### SHIP
- Brief report. Screenshot gallery.

## Code Style
- Components + SO. Fast scripts, few abstractions.
- **Singletons OK** (`GameManager.Instance`, `AudioManager.Instance`).
- `[SerializeField]` for Inspector fields.
- No C# namespaces.
- No XML docs (except non-obvious).
- Magic numbers OK **except settings** (those in SO always).
- **No DI/ServiceLocator** without clear reason.

## Logging
- **No `//` comments.** Use `Debug.Log` instead — key events only.
- Format: `Debug.Log($"[Feature.Class.Method] ...")` when used.

## Docs
- `Docs/DEV_STATE.md` — context + current + next. Brief.
- `Docs/DEV_PLAN.md` — optional, brief if created.
- `Docs/DEV_LOG/` — brief entries on batch completion.
- `Docs/AGENT_MEMORY.md` — important decisions only.

## Architecture
- MonoBehaviour-first, minimal abstraction.
- Direct `[SerializeField]` references between components.
- No ServiceLocator, no DI.
- Manual scene setup (Unity Editor / MCP).

## Input
- Default: `Old` or `Both`.
- Keep existing if project uses `New Input System`.

## MCP Usage
- Follow provider-neutral preflight from `tools/mcp-provider-neutral.md`.
- If MCP is missing and `auto_install_mcp_in_manifest` is enabled, add the adapter package to `Packages/manifest.json`, retry MCP detection, then fall back to file-only only if still unavailable.
- `batch_execute` or equivalent bulk operations are recommended for multiple objects/components.
- Console check after each feature for C# changes and after each batch for Play Mode.
- Screenshot after batch or stage, not each feature unless the feature is visual.
- Save scene after each batch when the scene changed.

## Checklist

- [ ] 1–3 questions → minimal outline
- [ ] 2–3 big stages, no detailed checklists
- [ ] Implement in batches (2–4 features), all data in SO
- [ ] Compile check after each feature
- [ ] Play Mode + `read_console` + screenshot after each batch
- [ ] Before handoff: Play Mode + `read_console` + final screenshot
- [ ] DEV_STATE updated after each batch
- [ ] All text uses TextMeshPro (never legacy Text)

## Example

```
Genre: 2D platformer.
Mechanics: run + jump.
One level, no menu.

Stage 1: Scene + character with controls. SO: PlayerSettings (speed, jumpForce).
Stage 2: Level (platforms, collisions) + camera.
Stage 3: Check, screenshot, final tweaks.
```
