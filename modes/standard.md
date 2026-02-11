# Mode: Standard

**For:** small complete game (few mechanics, few screens) with full process and moderate code style.

## Goal

Small complete game. Few mechanics, few screens — “minimal complete game”. Normal process: stages, state files kept.

## Complexity limits

> Default guidelines, not hard limits. Can exceed with user agreement.

- Screens: **3–6**.
- Mechanics: **3–6**.
- Scenes: **2–5**.
- New features per iteration: **1–2**.

## Clarifying questions

- **Before plan:** yes. Clarify genre, mechanics, screens, style, platform — whatever is unclear.
- **Before feature:** yes **if in doubt**. If mechanic or UI is ambiguous — ask. If clear — do without asking.
- **During:** if unclear — ask. If clear — do not ask.
- Can be turned off/on at user request.

## Workflow

1. Clarifying questions → clarify details.
2. Short outline (genre, 2–3 mechanics, 2–3 screens).
3. Short stages with per-stage checklist.
4. Reuse-first (default): before implementing feature (1) check Unity built-in and installed packages; (2) if needed search for mechanics/libraries on **GitHub** and **web** (UPM, open code, tutorials, Asset Store). If feature is small and simple — code by hand. **Before each feature — ask if in doubt.**
5. State files required (Docs/DEV_STATE + Docs/DEV_PLAN + Docs/DEV_LOG/).

## Reuse-first

- **On by default** (toggle in `Docs/DEV_CONFIG.md` → “Search ready solutions”).
- Check ready-made (Unity + packages) first, then GitHub and web if needed. Priority: **UPM/package** → **GitHub/open code** → asset → reference code.
- Choice criteria: compatibility, activity/support, license, dependency size.
- Record choice: write to current iteration file in `Docs/DEV_LOG/` (name: iteration-NN-YYYYMMDD-HHMM.md); if architecturally important also `Docs/ARCHITECTURE.md`.

## Input policy

- Default `Old` or `Both`.
- If project runs on `New Input System`, change only by agreement.

## Checks and tests

- **Agent must check each feature** before next: run Play Mode, take game screenshots (not only editor scene), try to play (buttons, flow), read console via `read_console` during/after Play Mode. Editor check + screenshot/checklist per feature.
- **Before stage/project handoff:** Play Mode + `read_console` + final screenshot.
- Tests not required by default.
- **QA per feature:** on/off in `Docs/DEV_CONFIG.md`. If on — after each feature agent writes mini QA checklist (steps + expected + “Agent check” + “QA check”) and waits for user OK.
- **Final QA checklist:** only if enabled in `Docs/DEV_CONFIG.md`. See reference.md → “QA checklist template”.

## Outline

Short: genre, 2–3 mechanics, 2–3 screens (menu, gameplay, settings, etc.).

## Stages

Short stages with checklist per stage. List files/scenes/prefabs and what to check in Unity.

## State files

Required. `Docs/DEV_STATE.md` — context + current task + blockers + next 3–5 (update on each action). `Docs/DEV_PLAN.md` — all tasks with checkboxes. `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` — completed task entries (can be simplified).

## Code style

**Moderate** — clear separation of data (SO) and logic, sensible structure without heavy architecture. **All settings in SO** (NpcData, GameFightData, UiData, etc.). See [SKILL.md](../SKILL.md) — “settings only in SO”.
- **No C# namespaces** — keep scripts in default (global) scope. Namespaces only in Pro mode; see [tools/code-writing.md](../tools/code-writing.md).
- **Hierarchy/scene:** use template from [tools/architecture-by-mode.md](../tools/architecture-by-mode.md): `GameManager` + `Core/Features/UI`, separate `Environment`.
- **MonoBehaviour:** ok for feature logic and view layer without extra service layers.
- **Architecture:** [tools/architecture-by-mode.md](../tools/architecture-by-mode.md).

### Logging (Standard)

- **Plenty and relevant.** Log key events, state changes, errors, warnings.
- Format: `Debug.Log($"[Feature.Class.Method] description with params")`. Example: `Debug.Log($"[Spawn.WaveSpawner.StartNextWave] Wave {wave}: {count} enemies")`.
- Do not log every frame.

## Example outline (Standard)

```
Genre: Top-down shooter.
Mechanics: WASD move, mouse shoot, enemy waves.
Screens: MainMenu, Gameplay, GameOver.
Data: PlayerData (speed, fireRate, maxHealth), EnemyData (speed, health, damage), WaveData (enemyCount, spawnInterval).
```

## Example stages (Standard)

```
Stage 1: Gameplay scene + character movement.
  Files: PlayerController.cs, PlayerData.asset
  Check: WASD works, speed from SO.
Stage 2: Shooting.
  Files: ShootController.cs, BulletPrefab
  Check: bullets toward cursor, fireRate from SO.
Stage 3: Enemies and waves.
  Files: Enemy.cs, EnemyData.asset, WaveSpawner.cs, WaveData.asset
  Check: enemies spawn, move to player, params from SO.
Stage 4: UI (HUD + menu + GameOver).
  Files: UIManager.cs, UiData.asset, MainMenu/GameOver scenes
  Check: HP bar, score, scene transitions.
Stage 5: Polish (balance via SO, sound).
```

## Standard mode checklist

- [ ] Clarifying questions → short outline (genre, 2–3 mechanics, 2–3 screens).
- [ ] Detailed plan: short stages with per-stage checklist.
- [ ] **Before each feature** — if in doubt, ask user.
- [ ] Implement by stages, moderate code style, all data in SO.
- [ ] **After each feature** — agent checks: Play Mode, `read_console`, game screenshots, try to play (buttons, flow). Then screenshot/checklist in Docs/DEV_STATE. If “QA per feature” on in Docs/DEV_CONFIG — write QA steps, wait for user OK before next feature.
- [ ] Before stage/project handoff: Play Mode + `read_console` + final screenshot.
- [ ] State files (DEV_STATE/PLAN/LOG) required, update on each action.
- [ ] Final QA checklist only if enabled in `Docs/DEV_CONFIG.md`.
