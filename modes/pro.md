# Mode: Pro (long-term)

**For:** scalable project, long development with extensibility, tests, and full state tracking.

## Goal

Long project with foundation. Full outline, detailed stages with acceptance criteria, architecture, tests. Full state files: Docs/DEV_STATE (current + context), Docs/DEV_PLAN (plan), Docs/DEV_LOG/ (iterations with iteration-NN-YYYYMMDD-HHMM.md, screenshots).

## Complexity limits

> Default guidelines, not hard limits. Can exceed with user agreement.

- Screens: **6+** (or cross-scene UI).
- Mechanics: **6+** or systemic gameplay.
- Scenes: **5+**.
- New features per iteration: usually **1** (deep implementation and check).

## Clarifying questions

- **Before plan:** yes, detailed. Clarify genre, all mechanics, screens, systems, style, platform, extensibility, priorities.
- **Before feature:** yes **if in doubt**. Clarify implementation details, behavior, edge cases, what data in SO, what UI. If clear from plan — do without asking.
- **During:** when unclear — ask. Better ask than redo.
- Can be turned off/on at user request.

## Workflow

1. Detailed clarifying questions → full project understanding.
2. Full outline (systems, screens, data, extensibility).
3. Detailed stages with checklists and acceptance criteria.
4. Reuse-first (default): before implementing feature (1) check Unity built-in and packages; (2) if needed search GitHub and web. Compare 1–3 options and choose. If feature small/simple — code by hand. **Before each feature — ask if in doubt.**
5. Full state files: Docs/DEV_STATE + Docs/DEV_PLAN + Docs/DEV_LOG/ (iterations).

## Reuse-first

- **On by default** (toggle in `Docs/DEV_CONFIG.md` → “Search ready solutions”).
- Check ready-made (Unity + packages) first, then GitHub and web if needed. Priority: **UPM/package** → **GitHub/open code** → asset → reference code.
- Choice criteria (required): license, support/updates, Unity/platform compatibility, dependency size/risks.
- Record: write to `Docs/ARCHITECTURE.md` (what chosen and why) + current iteration file in `Docs/DEV_LOG/` (what was done).

## Input policy

- Default `New Input System`.
- Use `Both`/`Old` only for confirmed legacy limits; document reason.

## Checks and tests

- **Agent must check:** per task in feature + per feature. Play Mode, game screenshots (not only scene), try to play (buttons, flow), console via `read_console` during/after Play Mode. Editor + screenshots + checklists.
- **Before stage/project handoff:** Play Mode + `read_console` + final screenshot.
- **Autotests on by default.** User can disable. At Pro start ask: “Autotests on by default; disable?”
- **QA per feature:** on/off in `Docs/DEV_CONFIG.md`. If on — after each feature agent writes QA checklist (steps + expected + edge cases + “Agent check” + “QA check”) and waits for user OK.
- **Final QA checklist:** only if enabled in `Docs/DEV_CONFIG.md`. See reference.md → “QA checklist template”.

## Outline

Full: genre, mechanics, all screens/scenes, main systems (input, saves, UI, audio), data and extensibility.

## Stages

Detailed stages with checklists and acceptance criteria. Per stage — files/scenes/prefabs, check checklist, “done” criteria.

## State files

Full format. `Docs/DEV_STATE.md` — context + current task + blockers + next (update on each action). `Docs/DEV_PLAN.md` — all tasks with checkboxes, stats. `Docs/DEV_LOG/iteration-NN-YYYYMMDD-HHMM.md` — full entries: date, result, files, screenshots with descriptions. Update on each action.

## Code style

**Architecture** — SO for all data + services/interfaces, refactor, extensibility. Unit/autotests on by default. **All settings in SO** (NpcData, GameFightData, UiData, etc.). See [SKILL.md](../SKILL.md) — “settings only in SO”.
- **C# namespaces** — use namespaces by system (e.g. `Game.Combat`, `Game.UI`). Pro is the only mode where namespaces are used; see [tools/code-writing.md](../tools/code-writing.md).
- **Composition:** main logic mostly in classes/services; MonoBehaviour — mainly view/entry points. Use DI/LifetimeScope when project really needs scalable composition.
- **Architecture:** [tools/architecture-by-mode.md](../tools/architecture-by-mode.md).

### Code comments (Pro)

- **XML docs required** for: classes, public methods, public fields/properties, interfaces.
- **No plain `//` comments.** Code must be self-documenting.
- **Only:** `// TODO:`, `// HACK:` / `// WORKAROUND:`, `// NOTE:` (non-obvious), SO field explanations (`[Tooltip]` or `//`).
- **No** “obvious” comments like `// increment counter`, `// call method`.

### Logging (Pro)

- **Plenty and relevant.** Log key events, state changes, actions, errors, warnings.
- Format: `Debug.Log($"[Feature.Class.Method] description with params")`. Example: `Debug.Log($"[Combat.HealthComponent.TakeDamage] Damage={amount}, HP={_currentHealth}")`.
- `Debug.LogError` — errors. `Debug.LogWarning` — suspicious cases.
- Do not log every frame in Update.

Details and examples: [tools/code-writing.md](../tools/code-writing.md).

## Example outline (Pro)

```
Genre: RPG with turn-based combat.
Goal: scalable project with room for content.

Systems:
- Combat: turn-based, abilities, effects. SO: AbilityData, StatusEffectData.
- Inventory: items, equipment. SO: ItemData, EquipmentData.
- Dialogue: NPCs, quests. SO: DialogueData, QuestData.
- Progression: levels, XP. SO: LevelCurveData.

Screens: MainMenu, WorldMap, Battle, Inventory, Dialogue, Settings.

Data: all combat, items, NPC, quest, UI params in SO.
Extensibility: new enemy = new EnemyData asset, new quest = new QuestData asset.
Tests: combat, inventory, progression.
```

## Example stages (Pro)

```
Stage 1: Architecture — GameManager, SceneLoader, ServiceLocator.
  Criteria: scenes switch, services available. Test: SceneLoadTest.

Stage 2: Combat system.
  2.1: Combat model (BattleManager, TurnSystem). Test: TurnOrderTest.
  2.2: Abilities (AbilitySystem + AbilityData SO). Test: DamageCalcTest.
  2.3: Battle UI (HP bars, ability choice). Editor check.
  Feature criteria: combat runs start to end, params from SO.

Stage 3: Inventory.
  3.1: Model (Inventory, ItemData SO). Test: InventoryAddRemoveTest.
  3.2: Inventory UI. Editor check.
  Criteria: add/remove items, data from SO.

Stage 4: Dialogue and quests (DialogueSystem, QuestSystem, SO data).
Stage 5: World, navigation, integrate all systems.
Stage 6: Polish, balance via SO, final tests.
```

## Pro mode checklist

- [ ] Detailed clarifying questions → full outline (systems, screens, data). Clarify: autotests? Questions? QA per feature? Final QA checklist? Write to Docs/DEV_CONFIG.md.
- [ ] Detailed plan: stages with checklists and acceptance criteria.
- [ ] **Before each feature** — if in doubt or ambiguous, ask user.
- [ ] Implement by stages: architecture, SO, tests. **Check per task in feature and per feature.**
- [ ] After each feature/task agent checks: Play Mode, `read_console`, game screenshots, try to play. If QA per feature on — write QA steps, wait for OK.
- [ ] Before stage/project handoff: Play Mode + `read_console` + final screenshot.
- [ ] Run autotests as you go (unless user disabled).
- [ ] State files (DEV_STATE/PLAN/LOG) in full format; update on each action; screenshots with dates.
- [ ] Final QA checklist only if enabled in `Docs/DEV_CONFIG.md`.
