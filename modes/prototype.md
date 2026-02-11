# Mode: Prototype

**For:** quickly validate an idea, get playable in minimal time (a couple of hours).

## Goal

Validate idea fast; minimal planning, max speed. Game scope minimal (1 screen, 1–2 mechanics).

## Complexity limits

> These are defaults, not hard limits. Can exceed with user agreement.

- Screens: usually **1**, max **2**.
- Mechanics: **1–2** key.
- Scenes: usually **1**, max **2**.
- New features per iteration: **up to 2**.

## Clarifying questions

- **Before plan:** yes, minimum (1–3 — genre, key mechanic, platform). Do not go deep.
- **Before feature:** no. Decide on your own — speed matters.
- **During:** no.
- Can be turned off/on at user request.

## Workflow

1. Clarifying questions (min, 1–3).
2. Minimal outline (1 screen, 1–2 mechanics).
3. 2–3 big stages without detailed checklists.
4. Reuse-first (default): check Unity built-in and installed packages; if needed quick search on **GitHub** and **web** (1–5 min). If not found or feature is small/simple — code by hand.
5. Implement “straight”, settings in SO.
6. State files (DEV_STATE/PLAN/LOG) optional or brief.

## Code

- **No C# namespaces** — keep all scripts in default (global) scope. Namespaces only in Pro mode; see [tools/code-writing.md](../tools/code-writing.md).

## Reuse-first (search ready solutions)

- **On by default** (toggle in `Docs/DEV_CONFIG.md` → “Search ready solutions”).
- Check ready-made first (Unity + packages), then search GitHub and web if needed. Priority: **UPM/package** → **GitHub/open code** → asset → reference code.
- Prototype limit: **do not spend much time evaluating**. If no clear win in 1–5 min — implement ourselves.

## Input policy

- Default `Old` or `Both` (quick start, compatibility).
- If project already uses `New Input System`, do not revert without reason.

## Checks and tests

- **Agent must check**, but **batch** (several features per pass) or at stage end is ok. When checking: Play Mode, try to play (buttons, flow), game screenshots, console via `read_console` during/after Play Mode.
- **Before stage/project handoff:** Play Mode + `read_console` + final screenshot.
- No tests required.
- **QA checklists:** only if enabled in `Docs/DEV_CONFIG.md` (QA per feature / final QA). See reference.md → “QA checklist template”.

## Outline

Minimal: one screen, 1–2 mechanics. No detailed system descriptions.

## Stages

Big blocks (2–3 stages). No detailed checklists or acceptance criteria.

## State files

Optional or brief. `Docs/DEV_STATE.md` — context + current task + next. `Docs/DEV_PLAN.md` — optional. `Docs/DEV_LOG/` — can skip; short “done / in progress” in Docs/DEV_STATE is enough.

## Code style

**Hardcode** — fast scripts, few abstractions, straight logic. **Settings must be in SO** (GameFightData, UiData, etc.): balance and texts change without touching scene/code. See [SKILL.md](../SKILL.md) — “settings only in SO”.
- **Hierarchy/scene:** prefer manual object setup (Unity Editor/Unity MCP). Do not use bootstrap unless for narrow checks/tech tasks. MonoBehaviour solutions ok in this mode.
- **Architecture:** [tools/architecture-by-mode.md](../tools/architecture-by-mode.md).
- **Anti-pattern:** do not add global ServiceLocator without clear reason.

### Logging (Prototype)

- **Minimal or none.** Log only when debugging a specific issue. No `Debug.Log` at all is fine.
- If logging: same format `Debug.Log($"[Feature.Class.Method] description")`.

## Example outline (Prototype)

```
Genre: 2D platformer.
Mechanics: run + jump.
One level, no menu.
```

## Example stages (Prototype)

```
Stage 1: Scene + character with controls (run, jump). SO: PlayerSettings (speed, jumpForce).
Stage 2: Level (platforms, collisions) + camera.
Stage 3: Check, screenshot, final tweaks.
```

## Prototype mode checklist

- [ ] Ask minimum clarifying questions, capture outline (1 screen, 1–2 mechanics).
- [ ] Split into 2–3 big stages without detailed checklists.
- [ ] Implement blocks “straight”, all tunable data in ScriptableObject.
- [ ] Checks in batch or at stage end: Play Mode + `read_console` + screenshots.
- [ ] Before handoff: Play Mode + `read_console` + final screenshot.
- [ ] QA checklists only if enabled in `Docs/DEV_CONFIG.md`.
- [ ] State files (DEV_STATE/PLAN/LOG) optional or brief.
