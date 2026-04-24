# Mode: Standard

**For:** Small complete game with quality balance — few mechanics, few screens, full process.

## Scope Limits (guidelines, not hard limits)
- Mechanics: **3–6**
- Screens: **3–6** (0 if `ui_mode = no_ui`)
- Scenes: **2–5**
- Features per iteration: **1–2**

## Pipeline Adjustments

### INTAKE
- Questions before plan: **yes, clarify** genre, mechanics, screens, style, platform.
- Questions before feature: **yes, if in doubt.** If clear from plan → proceed.

### PLAN
- Short outline: genre, 2–3 mechanics, 2–3 screens, key SO data.
- Short stages with per-stage checklist (files, scenes, what to check).
- Reuse-first: check Unity + packages, search GitHub/web if needed.
- Record reuse decisions in DEV_LOG and ARCHITECTURE if significant.

### BUILD
- **Per feature checks** — Play Mode + `read_console` + screenshot after EACH feature.
- Compile check after every code change.
- Scene save after every feature.
- Screenshot after every feature → link in DEV_STATE.
- DEV_STATE + DEV_LOG update after every feature.
- **Do NOT move to next feature until current passes all checks.**

### VERIFY
- Full Play Mode walkthrough of complete game flow.
- `read_console` — completely clean.
- Screenshot series of all key screens.
- QA checklist if enabled in DEV_CONFIG.

### SHIP
- Full report with screenshot gallery.
- All docs updated.

## Code Style
- **Moderate** — clear separation, sensible structure.
- Separate scripts per responsibility: `PlayerMovement`, `PlayerHealth`, `PlayerCombat`.
- `[SerializeField]` for all Inspector fields.
- Cache components in `Awake`/`Start`.
- Data in SO, references via `[SerializeField]`.
- Prefabs for repeated objects.
- Events / UnityEvents for cross-system communication.
- No C# namespaces.
- XML docs for public methods.
- `[Header]`, `[Tooltip]`, `[Range]` on SO fields.

## Logging
- **No `//` comments.** Use `Debug.Log` instead — plenty, for key events and state changes.
- Format: `Debug.Log($"[Feature.Class.Method] description with params")`
- `Debug.LogError` for errors, `Debug.LogWarning` for warnings.
- Do not log every frame in Update.

## Docs
- `Docs/DEV_STATE.md` — **required**, update every action.
- `Docs/DEV_PLAN.md` — **required**, all tasks with checkboxes.
- `Docs/DEV_LOG/iteration-*.md` — **required**, completed task entries.
- `Docs/AGENT_MEMORY.md` — **required**.
- `Docs/ARCHITECTURE.md` — create when structure decisions are made.

## Architecture
- Feature nodes in hierarchy (`Feature_Player`, `Feature_Enemies`).
- Moderate separation into features/subsystems.
- MonoBehaviour for feature logic — no extra infra layers.
- DI only when it clearly pays off.
- Hierarchy: GameManager + Core/Features/UI, separate Environment.

## Input
- Default: `Old` or `Both`.
- Change only by agreement.

## QA
- **QA per feature:** on/off in DEV_CONFIG. If on → agent writes mini QA checklist after each feature, waits for user OK.
- **Final QA:** if enabled in DEV_CONFIG.

## MCP Usage
- Per feature: `refresh_unity` → `read_console` → Play Mode → screenshot.
- `manage_gameobject` / `manage_components` — for scene setup.
- `batch_execute` — when creating multiple objects.
- `manage_scene action=save` — after every feature.

## Checklist

- [ ] Clarifying questions → short outline (genre, 2–3 mechanics, 2–3 screens)
- [ ] Stages with per-stage checklist
- [ ] Before each feature — ask user if in doubt
- [ ] Implement per feature, all data in SO
- [ ] After each feature: compile + Play Mode + `read_console` + screenshot
- [ ] Screenshot reviewed (not blank, shows expected)
- [ ] DEV_STATE + DEV_LOG updated after each feature
- [ ] Before handoff: full Play Mode + `read_console` + final screenshot
- [ ] All text uses TextMeshPro (never legacy Text)
- [ ] QA checklist if enabled in DEV_CONFIG

## Example

```
Genre: Top-down shooter.
Mechanics: WASD move, mouse shoot, enemy waves.
Screens: MainMenu, Gameplay, GameOver.
SO: PlayerData (speed, fireRate, maxHealth), EnemyData, WaveData.

Stage 1: Gameplay + character movement.
  Files: PlayerController.cs, PlayerData.asset. Check: WASD works.
Stage 2: Shooting.
  Files: ShootController.cs, BulletPrefab. Check: bullets toward cursor.
Stage 3: Enemies and waves.
  Files: Enemy.cs, WaveSpawner.cs. Check: enemies spawn, move to player.
Stage 4: UI (HUD + menu + GameOver).
  Files: UIManager.cs, UiData.asset. Check: HP bar, score, transitions.
Stage 5: Polish (balance, sound).
```
