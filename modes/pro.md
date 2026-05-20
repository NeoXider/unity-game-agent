# Mode: Pro

**For:** Scalable project, long development, architecture, tests, full state tracking.

## Scope Limits (guidelines, not hard limits)
- Mechanics: **6+** or systemic gameplay
- Screens: **6+** (0 if `ui_mode = no_ui`)
- Scenes: **5+**
- Features per iteration: **1** (deep implementation + full check)

## Pipeline Adjustments

### INTAKE
- **Detailed questions:** genre, all mechanics, screens, systems, style, platform, extensibility, priorities.
- Ask: "Autotests on by default; disable?" Record in DEV_CONFIG.
- Ask about QA per feature and final QA checklist.

### PLAN
- Full outline: systems, screens, data, extensibility.
- Detailed stages with acceptance criteria per stage.
- Library discovery with Reuse Decision Matrix (compare 1–3 options).
- Record choices in ARCHITECTURE.md.
- **Before each feature — ask if in doubt.** Clarify edge cases, behavior, SO structure.

### BUILD
- **Per task checks** within a feature + **per feature checks.**
- After each task in feature: compile + `read_console`.
- After each feature: full Play Mode + `read_console` + screenshot + try to play.
- Scene save after every task.
- DEV_STATE + DEV_LOG update after every task.
- **Run autotests** after features (if enabled).
- Before closing any task/feature, run Play Mode when MCP or equivalent automation is available, check console during Play Mode, verify changed mechanics/UI/scene behavior directly, and run relevant tests.

### VERIFY
- Full Play Mode walkthrough of all game paths.
- `read_console` — completely clean.
- Run full test suite (`run_tests`).
- Final screenshot series.
- Performance check (`manage_profiler` if needed).
- Final QA checklist if enabled.

### SHIP
- Full report with test results, screenshot gallery, known issues.
- All docs complete and current.

## Code Style
- **Architecture-first** — SO for data, services for logic, MonoBehaviour as view/entry.
- **Interfaces** for key systems: `IDamageable`, `IInteractable`, `ISaveable`, `IInputProvider`.
- **Namespaces** by system: `Game.Combat`, `Game.Inventory`, `Game.UI`.
- **Services** via ServiceLocator or DI (VContainer / Zenject) when justified.
- Data vs logic: SO for data, MonoBehaviour for Unity binding, POCO for pure logic.
- Events / Observer for cross-system communication.
- **XML docs required** for: classes, public methods, public fields/properties, interfaces.
- **No plain `//` comments.** Code self-documenting. Only: `// TODO:`, `// HACK:`, `// NOTE:`.
- `[SerializeField]`, cache components, null checks.
- Assembly Definitions for compile speed.
- Object pool for frequent create/destroy.
- State machine for complex behavior.

## Logging
- **No `//` comments.** Use `Debug.Log` instead — plenty, with params and state info.
- Format: `Debug.Log($"[Feature.Class.Method] Damage={amount}, HP={_currentHealth}")`
- `Debug.LogError` for errors, `Debug.LogWarning` for suspicious cases.

## Testing
- **Autotests ON by default.** User can disable.
- EditMode tests for pure logic (combat math, inventory add/remove).
- PlayMode tests for integration (scene load, interaction flow).
- Run via MCP: `run_tests mode="EditMode"` → `get_test_job id=<id>`.
- Tests must pass before feature is done.

## Docs
- **Everything required.** DEV_STATE, DEV_PLAN, DEV_LOG, AGENT_MEMORY, ARCHITECTURE.
- Full format: detailed entries with timestamps, screenshots, file lists.
- Update on every action — not optional.

## Architecture
- Main logic in classes/services.
- MonoBehaviour mainly as view/entry points.
- DI/LifetimeScope when composition justifies it.
- **Document DI decisions** in ARCHITECTURE.md: what problem, why needed, benefit, risks.
- Architecture escalation: simple components → service layer → DI.

## Input
- Default: `New Input System`.
- `Both`/`Old` only for confirmed legacy limits. Document reason.

## QA
- **QA per feature:** on/off in DEV_CONFIG. If on → agent writes QA checklist with edge cases, waits for user OK.
- **Final QA:** if enabled — full checklist including performance.

## MCP Usage
- Follow provider-neutral preflight from `tools/mcp-provider-neutral.md`.
- If MCP is missing and `auto_install_mcp_in_manifest` is enabled, add the adapter package to `Packages/manifest.json`, retry MCP detection, then fall back to file-only only if still unavailable.
- Full MCP or equivalent automation every step:
  - before task: editor readiness + console baseline;
  - after task: compile/import readiness + console comparison + screenshot when visual;
  - after feature: full Play Mode check, console during Play Mode, screenshot, relevant tests.
- Use script validation after each script edit when available.
- Use bulk/batch capabilities for complex object systems.
- Create prefabs immediately for reusable scene objects.
- Use profiler/performance capabilities for major systems and final verification.

## Checklist

- [ ] Detailed questions → full outline (systems, screens, data)
- [ ] Clarify: autotests? QA per feature? Final QA? Write to DEV_CONFIG
- [ ] Detailed stages with acceptance criteria
- [ ] Before each feature — ask if in doubt or ambiguous
- [ ] Implement: architecture + SO + tests
- [ ] After each task: compile + `read_console`
- [ ] After each feature: Play Mode + `read_console` + screenshot + tests
- [ ] During Play Mode: console checked and changed mechanic/UI/scene behavior verified
- [ ] Screenshot reviewed (not blank, shows expected)
- [ ] DEV_STATE + DEV_LOG updated after every action
- [ ] All text uses TextMeshPro (never legacy Text)
- [ ] Autotests pass (unless disabled)
- [ ] Before handoff: full Play Mode + tests + final screenshot
- [ ] Final QA checklist if enabled

## Example

```
Genre: RPG with turn-based combat.
Goal: scalable project with room for content.

Systems:
- Combat: turn-based, abilities, effects. SO: AbilityData, StatusEffectData.
- Inventory: items, equipment. SO: ItemData, EquipmentData.
- Dialogue: NPCs, quests. SO: DialogueData, QuestData.
- Progression: levels, XP. SO: LevelCurveData.

Screens: MainMenu, WorldMap, Battle, Inventory, Dialogue, Settings.
Tests: combat, inventory, progression.

Stage 1: Architecture — GameManager, SceneLoader, ServiceLocator.
  Criteria: scenes switch, services available. Test: SceneLoadTest.
Stage 2: Combat system.
  2.1: Combat model (BattleManager, TurnSystem). Test: TurnOrderTest.
  2.2: Abilities (AbilitySystem + AbilityData SO). Test: DamageCalcTest.
  2.3: Battle UI. Editor check.
Stage 3: Inventory.
  3.1: Model (Inventory, ItemData SO). Test: InventoryAddRemoveTest.
  3.2: Inventory UI. Editor check.
Stage 4: Dialogue and quests.
Stage 5: World, navigation, integrate all systems.
Stage 6: Polish, balance, final tests.
```
