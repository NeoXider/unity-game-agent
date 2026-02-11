# Mode: Fast

**For:** get to playable build faster with simpler process (fewer reports and screenshots). Game size can be medium or large.

## Goal

Quick to playable result. Simplified process: less docs, fewer screenshots, bigger stages. **Several features per pass** is ok.

## Complexity limits

> Default guidelines, not hard limits. Can exceed with user agreement.

- Screens: usually **2–4**, max **5**.
- Mechanics: **2–4** key.
- Scenes: usually **1–2**, max **3**.
- New features per iteration: **up to 4** (with batch check).

## Clarifying questions

- **Before plan:** yes, minimum (1–3). Clarify basics and move on.
- **Before feature:** no. Decide on your own — speed matters.
- **During:** no.
- Can be turned off/on at user request.

## Workflow

1. Clarifying questions (min, 1–3).
2. Outline + stage list.
3. Big stages, fewer screenshots and detail.
4. Reuse-first (default): check Unity built-in and packages; if needed quick search on **GitHub** and **web** (mechanics, libraries, assets). If feature small/simple — code by hand.
5. Implement (components, SO); several features per pass ok.
6. State files brief, no heavy history.

## Reuse-first

- **On by default** (toggle in `Docs/DEV_CONFIG.md` → “Search ready solutions”).
- Check ready-made (Unity + packages) first, then GitHub and web if needed. Priority: **UPM/package** → **GitHub/open code** → asset → reference code.
- In Fast: **quick choice**. Do not add heavy deps for small gains.

## Input policy

- Default `New Input System`.
- Legacy projects: `Both` or `Old` ok per project limits.

## Checks and tests

- **Agent must check**, but **not after every feature**: can check several features in a row or one check at stage end. When checking: Play Mode, try to play (buttons, flow), game screenshots, console via `read_console` during/after Play Mode.
- **Before stage/project handoff:** Play Mode + `read_console` + final screenshot.
- No tests required.
- **QA checklists:** only if enabled in `Docs/DEV_CONFIG.md`. See reference.md → “QA checklist template”.

## Outline

Outline and stage list. Less detail than Standard.

## Stages

Big stages. Fewer screenshots and detail in reports.

## State files

Keep brief. `Docs/DEV_STATE.md` — context + current task + next. `Docs/DEV_PLAN.md` — all tasks with checkboxes (brief). `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` — when finishing tasks (no long descriptions).

## Code style

**Components** — one component one responsibility, data in SO (NpcData, UiData, LevelSettings). Fewer layers, faster to write. **All settings in SO.** See [SKILL.md](../SKILL.md) — “settings only in SO”.
- **No C# namespaces** — keep scripts in default (global) scope. Namespaces only in Pro mode; see [tools/code-writing.md](../tools/code-writing.md).
- **Hierarchy/scene:** prefer manual object setup (Unity Editor/Unity MCP). Do not use bootstrap unless for narrow checks/tech tasks.
- **MonoBehaviour:** fewer “kitchen sink” scripts; split into components with explicit refs.
- **Architecture:** [tools/architecture-by-mode.md](../tools/architecture-by-mode.md).
- **Anti-pattern:** do not add global ServiceLocator without clear reason.

### Logging (Fast)

- **Moderate.** `Debug.LogError` and `Debug.LogWarning` — required. `Debug.Log` — as needed, not excessive.
- Same format: `Debug.Log($"[Feature.Class.Method] description")`.

## Example outline (Fast)

```
Genre: Runner.
Mechanics: run forward, dodge (swipe/arrows), collect coins, obstacles.
Screens: Gameplay, GameOver with Restart.
SO: RunnerSettings (speed, laneDistance), ObstacleData, CoinValue.
```

## Example stages (Fast)

```
Stage 1: Character + endless move + dodge + camera. SO: RunnerSettings.
Stage 2: Obstacles + coins + spawner + Game Over. SO: ObstacleData, CoinValue.
Stage 3: UI (score, GameOver, Restart) + polish + check.
```

## Fast mode checklist

- [ ] Clarifying questions → outline + stage list.
- [ ] Big stages; can combine several features in one pass.
- [ ] Implement (components, SO); Unity editor (refresh, scene, inspector) as needed.
- [ ] Checks per feature block: Play Mode + `read_console` + screenshots.
- [ ] Before handoff: Play Mode + `read_console` + final screenshot.
- [ ] QA checklists only if enabled in `Docs/DEV_CONFIG.md`.
- [ ] State files (DEV_STATE/PLAN/LOG) brief, no heavy history.
