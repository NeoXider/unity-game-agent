# Mode: NoUI

**For:** gameplay/system implementation where UI is out of scope for the current iteration.

## Goal

Ship mechanics and systems fast, without entering UI pipeline (UI Builder/uGUI screens/layout/visual polishing).

## Complexity limits

> Default guidelines, not hard limits. Can exceed with user agreement.

- Screens: **0** (UI tasks excluded).
- Mechanics: **1–4** per iteration.
- Scenes: usually **1–2**, max **3**.
- New features per iteration: **up to 3** with mandatory checks after block.

## Clarifying questions

- **Before plan:** minimum (goal, done criteria, constraints).
- **Before feature:** only if blocker/ambiguity.
- **UI-related questions:** skip by default.

## Workflow

1. Clarify goal and done criteria (no UI intake).
2. Mechanics/system outline and staged plan.
3. Reuse-first discovery (built-in, installed packages, GitHub/web).
4. Implement core logic/components/SO.
5. Per feature or per small feature block: Play Mode + `read_console`.
6. Update `DEV_STATE`, `DEV_PLAN`, `DEV_LOG`.

## Reuse-first

- **On by default** (toggle in `Docs/DEV_CONFIG.md`).
- Check ready-made first, then add minimal libraries needed for systems.
- Do not implement from scratch when reusable solution exists and fits constraints.

## Checks and tests

- Required per feature/block:
  - Play Mode smoke,
  - `read_console` clean from new errors.
- Before handoff:
  - final Play Mode check,
  - final `read_console`,
  - final report.

## State files

- `Docs/DEV_STATE.md` — required, keep current.
- `Docs/DEV_PLAN.md` — required, keep task checkboxes current.
- `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` — required per iteration.

## Code style

- Component-based implementation, all tunables in ScriptableObject.
- No UI layer tasks unless user explicitly opens a separate UI scope.

## NoUI checklist

- [ ] UI intake skipped (mode confirmed as NoUI).
- [ ] Mechanics/system scope defined with done criteria.
- [ ] Reuse-first discovery recorded.
- [ ] Implemented feature(s) checked in Play Mode.
- [ ] Console checked with `read_console` (no new errors).
- [ ] `DEV_STATE`/`DEV_PLAN`/`DEV_LOG` updated.
