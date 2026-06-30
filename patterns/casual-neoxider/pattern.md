# Pattern: Casual game on NeoxiderTools

Build casual / hyper-casual / mobile games **from ready Neoxider managers, with minimal custom code.**
States go through `GM`/`G`, screens through `PM`/`UIPage`, balance through `ScriptableObject`,
dynamics through prefabs, polish on DOTween, and the Editor is driven via **MCP**.

This is a **pattern** layered on the universal pipeline (`INTAKE -> PLAN -> BUILD -> VERIFY -> SHIP`).
It sets the stack, scene skeleton, reuse map, and golden rules for casual games; the pipeline's
preflight, verification gate, and QA policy still apply.

> Requires **DOTween** (free is fine; DOTween Pro only if you use Pro-only features) and the
> **NeoxiderTools** package (`com.neoxider.tools`, namespace `Neo`) plus the optional **NeoxiderPages**
> sample (`PM`/`UIPage`/`BtnChangePage`/`G`).

## When to use

Match-3, merge, lotto/bingo, slots, dress-up, idle/clicker, arcade, ping/pong, basketball, puzzle —
building or continuing a casual/mobile game that already uses (or will use) NeoxiderTools.

**Detection signals (auto-select):** `com.neoxider.tools` in `Packages/manifest.json`; `Neo.*`
namespaces in code; a `-System--` root with `GM`/`EM`/`PM` managers; `UIPage`/`PageId`/`BtnChangePage`
in scenes. **Not for:** general C#/Unity API questions without building a game, or non-Neoxider stacks.

## Companion references

- **NeoxiderTools reuse policy** (provider-neutral): [../../tools/neoxider-tools-reuse.md](../../tools/neoxider-tools-reuse.md)
- **What is in the package** (components, modules, full API): the standalone `neoxider-tools` skill if
  installed, plus `Assets/Neoxider/Docs/**` (RU) and `DocsEn/**` in the NeoxiderTools repo.
- **Driving the Editor via MCP:** [../../tools/mcp-provider-neutral.md](../../tools/mcp-provider-neutral.md)
  and [../../mcp-commands.md](../../mcp-commands.md).
- Reference games: study existing casual games in project-provided samples, local references, or approved repos before building.

---

## STOP — before writing your own component

Almost everything is already in NeoxiderTools. **Search first, write second.** Before hardcoding,
read [managers.md](managers.md), the reuse policy, and grep the package. Typical "do not rewrite":

| Need | Use the ready one (don't write your own) |
|------|------------------------------------------|
| Timer -> text | `TimeToText` (`Neo.Tools`) |
| Number/money/score -> text | `SetText` / `TextMoney` / `TextScore` / `TextLevel` |
| Wallet | `Money` (`Neo.Shop`) |
| Score / best score / stars | `ScoreManager` (`Neo.Tools`) |
| Levels-as-stages / progress | `LevelManager` (`Neo.Level`) / `LevelComponent` (XP) |
| HP / mana / lives | `HealthComponent` (`Neo.Core.Resources`) |
| Sound | `AM` (`Neo.Audio`) — `AM.I.Play(index)` |
| Saves | `SaveManager`/`SaveProvider` (`Neo.Save`) — not raw `PlayerPrefs` |
| Shop/purchases | `Shop` + `ShopItemData` + `ButtonPrice` (`Neo.Shop`) |
| Screens/navigation | `PM` / `UIPage` / `BtnChangePage` (`Neo.Pages`) |
| Slots / wheel / chance | `SpinController`/`Row`, `WheelFortune`, `ChanceManager` (`Neo.Bonus`/`Neo.Tools`) |
| Spawn/pool | `Spawner` / `PoolManager` (`Neo.Tools`) |
| Fly "object -> UI slot" | `AnimationFly` (`Neo.UI`) |
| Inspector cheat buttons | `[Button]` (`Neo`) — on **any** MonoBehaviour, no custom Editor |

No ready component -> write a thin adapter/component, not a duplicate system.

---

## Build loop

```
INTAKE -> SCAFFOLD -> REUSE -> CONFIG(SO) -> PAGES -> DYNAMICS(prefab) -> POLISH(DOTween) -> VERIFY(MCP)
```

1. **INTAKE.** Genre and core loop. Is there a **reference** (image) or **GDD** (`Docs/*.docx/.md`)?
   What is already in the scene and in `Assets/_source`? Don't duplicate — continue. Images come from
   the project's `Sprites/`.
2. **SCAFFOLD.** Scene skeleton per [scene-skeleton.md](scene-skeleton.md): `-System--` root for
   managers, `PM` + pages, `AM`, `Canvas bg`. Static objects sit in the scene and are wired — no bootstraps.
3. **REUSE.** Wire the needed managers (see STOP table) — one per object under `-System--`.
4. **CONFIG (SO).** Balance/rules/levels in `ScriptableObject` (see Decisions: SO vs fields).
5. **PAGES.** Menu / Game / Pause / Win / Lose / End. Game-screen content lives **inside its `UIPage`**.
   Navigation via `BtnChangePage`, not custom handlers.
6. **DYNAMICS.** Anything spawned during play and effects — **prefab + `Instantiate`/pool only**.
7. **POLISH.** DOTween juice (idle pulse, punch, fill). `DOTween.Init()` in `BeforeSceneLoad`.
8. **VERIFY (MCP).** Clean compile -> console with no new errors -> screenshot -> Play smoke test.
   Follow the universal Verification Gate in `../../SKILL.md`.

---

## Golden rules (12)

1. **Don't write from scratch** — assemble from Neoxider managers. No component? Check docs, then write.
2. **Minimal code.** Wire references/events in the inspector (UnityEvent/refs); keep branching and game rules in typed C#. **No NoCode.**
3. **No comments** — clear names. (Exception: one "why" line for nontrivial logic is fine.)
4. **State via `GM`/`G`**, not your own bool flags for game flow.
5. **Hook logic through a `<Game>Manager` bridge** that listens to `G.On*` (the bridge is optional for
   simple games — see Decisions).
6. **Buttons/navigation via `BtnChangePage`** (+ optional `GameState.State`), not custom onClick handlers.
7. **Balance in `ScriptableObject`** (see Decisions: when SO, when controller fields).
8. **No bootstraps that create scene statics.** Statics already sit in the scene; **dynamics/frequent
   spawns come from prefabs.**
9. **1 system = 1 component = 1 object** under `-System--`. (Player/cell/UI element — the opposite:
   compose components on one object.)
10. **Editable without code:** SO config + inspector. A designer changes the game without opening scripts.
11. **Game-screen content lives inside its `UIPage`**, not in a separate Canvas.
12. **Animations on DOTween**, initialized before the scene loads.

Flow: **GM changes State -> calls EM -> EM/G broadcast `UnityEvent` -> subsystems react independently.**

> **Progress (level/score/reward) hooks onto the `G.OnWin`/`G.OnEnd` event, not inside your own
> `Win()` method.** A win can arrive via your `Win()`, a direct `G.Win()`/`GM.Win()`, a goal UnityEvent,
> or a cheat — only the event always fires. See [patterns.md](patterns.md) §1.

---

## Decisions (where reference games diverge from the rules — choose deliberately)

From real games (`lotto`, `FootballPing`, `matchamadness`, `4PingPong`, `Basket Battle`, `Gem3`):

- **SO vs controller fields.** SO when config is **reusable / multi-level / multi-difficulty**
  (`MatchSettings`, `PongConfig`, `BettingSettings`). Simple single-game constants (`minNumber`,
  `sessionDuration`) can live as public `[SerializeField]` fields if inspector-editable and stable
  between runs. Per-level/persist -> SO or `SaveManager`.
- **`<Game>Manager` bridge.** Can be a `Singleton<T>` bridge (lotto/match3/basket), a **non-singleton
  flow orchestrator** for complex multi-screen games (`GameFlowController` in FootballPing), **or** the
  controller listens to `G` directly for a one-controller game (4PingPong). Choose by complexity.
- **Bootstrap.** The distinction is **frequency, not place**. Once-per-session objects (match
  controller, match entities) may be created at session start by a bootstrap. Frequently spawned
  (balls, chips, particles) — **only** prefab/pool, never `new GameObject` in a hot path.
- **Local enum vs `GM.State`.** `GM.State` is the single source of truth for game flow. Local `enum`
  (`BallState { Ready, Aiming, Flying }`) is for an object's internal state. Don't mirror game flow
  with local flags.
- **Custom resource wrapper.** For nonstandard economy (bets, coefficients, min-bet) wrap `Money` with
  your own manager (`StarsWallet`/`BettingManager`) instead of bending a Neo component past its intent.
- **Input.** Default to simple direct input: `Input.GetMouseButton`/`GetTouch` or
  `IPointerClickHandler` (EventSystem). Swipes -> `SwipeController` utility. Complex input -> Input System.
- **Folder structure.** `<5` scripts -> flat in `Scripts/Runtime/`. `>10` -> functional folders
  (`Gameplay/`, `Config/`, `UI/`), mirror the namespace in folders. Editor tools -> `Scripts/Editor/`.

---

## Reference files

- **[scene-skeleton.md](scene-skeleton.md)** — canonical scene hierarchy (`-System--`, `PM`+pages, `AM`,
  `Canvas bg`) and the ready Game-Page top bar (money/score/level/settings already wired). Don't rebuild
  the top bar; add only what's missing.
- **[managers.md](managers.md)** — reuse table of Neoxider managers with key API.
- **[patterns.md](patterns.md)** — proven code patterns: GameManager bridge, SO config, result-text
  component, dynamic list (prefab + LayoutGroup), enum state machine, Perlin-noise AI, trajectory
  preview, slow-mo polish, session bootstrap, DOTween juice, `[Button]` cheats, `TimeToText`,
  `AnimationFly`, `SetNativeSize` sprites, custom resource wrapper.

---

## New-game checklist

1. SO config(s). 2. Scene: `-System--` (`PM`+pages, `AM`, as needed `GM/EM`, `ScoreManager`,
`SaveManager`, `Money`), statics wired. 3. `<Game>Controller` (reads SO) + a `<Game>Manager` bridge on
`G.On*` when complex. 4. Buttons via `BtnChangePage`; sound via `AM.I.Play(index)` by constants.
5. Score/level/HP via `ScoreManager`/`LevelManager`/`HealthComponent`. 6. Dynamics/effects from prefabs.
7. Results — Win/Lose/End pages; dynamic result via a small text component. 8. Polish — DOTween.
9. Verify via MCP.

## Anti-patterns

❌ Bootstrap that creates scene statics in `Awake`/`Start`. ❌ Logic/navigation baked into
buttons/controller. ❌ Balance as code constants instead of SO (when reusable/per-level). ❌ Game-screen
content in a separate Canvas instead of the `Game Page (UIPage)`. ❌ Own `PlayerPrefs`/sound/score
instead of `SaveManager`/`AM`/`ScoreManager`. ❌ Recording a sound at volume 0 in `AM._sounds`.
❌ NoCode (`*NoCodeAction`, NeoCondition NoCode). ❌ `new GameObject` for frequently spawned objects
instead of prefab/pool. ❌ Own `CustomEditor` just for buttons (it shadows the `[Button]` fallback).
❌ Progress/score saved only inside your own `Win()` instead of on `G.OnWin`.
