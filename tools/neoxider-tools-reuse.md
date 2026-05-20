# NeoxiderTools Reuse Policy

Use this file when a Unity project or task may benefit from ready systems in NeoxiderTools. Reuse is opt-in, not forced.

Treat this as a discovery checklist, not as a promise that every target project has every module imported.

## When To Ask

Ask whether to use NeoxiderTools when `ask_about_neoxider_tools` is true and any of these apply:

- project is new or mostly empty;
- task mentions UI pages/navigation, game state flow, audio, shop/economy, reusable managers, settings/save, quests, cards/decks, inventory, dialogue, docs, editor tooling, or reusable game systems;
- existing project already references `Neoxider`, `Neo.`, `NeoxiderTools`, or similar namespaces/assets;
- user asks to build a system that appears to exist in NeoxiderTools.

Question:

```text
Use ready systems from NeoxiderTools, or build standalone for this project?
```

Default if the user does not answer: standalone, unless the project already depends on NeoxiderTools.

## Discovery Before Use

If the user opts in, discover available systems before planning implementation:

```text
1. Inspect Packages/manifest.json for com.neoxider.tools.
2. Check whether samples were imported under Assets/Samples/Neoxider Tools/* or Assets/Neoxider/Samples~.
3. Search code/scenes for Neo.Pages, Neo.Audio, Neo.Shop, Neo.Tools, PM, UIPage, PageId, BtnChangePage, AM, Money, Shop.
4. Inspect relevant package docs/source before depending on a module.
5. Identify the smallest reusable system or adapter point.
6. Record the decision in Docs/DEV_PROFILE.json and Docs/AGENT_MEMORY.md.
```

Prefer project-local NeoxiderTools code over assumptions from memory.

## Package And Sample Shape

Do not hardcode a NeoxiderTools package URL or branch from another project. If the package is missing and the user opted in, discover the install source from the current project conventions, user instruction, local package clone, or NeoxiderTools documentation before editing `Packages/manifest.json`.

NeoxiderTools has two different integration layers:

- Package modules under `Packages/com.neoxider.tools` or local `Assets/Neoxider`: runtime/editor assemblies such as `Neo.Tools`, `Neo.Audio`, `Neo.Shop`, `Neo.Save`, `Neo.Settings`, `Neo.Quest`, `Neo.Cards`, `Neo.UI`, `Neo.Level`, `Neo.Reactive`, `Neo.Network`, `Neo.Progression`, `Neo.StateMachine`, `Neo.Rpg`, and utility submodules.
- Optional samples, especially `NeoxiderPages`: page prefabs/assets/scripts such as `PM`, `UIPage`, `PageId`, `BtnChangePage`, `PageSubscriber`, `FakeLoad`, `UIKit`, and `UIKitAPI` facades. UPM samples are not always imported, so verify their presence before using `Neo.Pages`.

## Reuse Map

Likely matches after discovery:

| Task area | Look for |
|---|---|
| UI pages/navigation | `Neo.Pages` sample: `PM`, `UIPage`, `PageId`, `BtnChangePage`, `PageSubscriber`, `UIKit.ShowPage`, optional DOTween page animations |
| Game flow/events | `Neo.Pages.G` facade over `Neo.Tools.GM`/`EM`: `OnStart`, `OnRestart`, `OnWin`, `OnLose`, `OnEnd`, `OnMenu`, `OnPause`, `OnResume`, `G.Start()`, `G.Win()`, `G.Lose()` |
| Audio | `Neo.Audio`: `AM`, `AMSettings`, `PlayAudio`, `PlayAudioBtn`, `AudioControl`, `RandomMusicController`, `SettingMixer` |
| Shop/economy | `Neo.Shop`: `Money`, `Shop`, `ShopItemData`, `ShopBundleData`, `ShopListView`, purchase/equip events, `SaveProvider` persistence |
| General utilities | `Neo.Tools`: `Singleton<T>`, `GM`, `EM`, score/text helpers, and narrow utility APIs only when they simplify normal C# code |
| Inventory/dialogue/tooling | `Neo.Tools.Inventory`, `Neo.Tools.Dialogue`, editor windows, custom inspectors, property attributes; inspect first and use only if they fit the project architecture |
| Settings/save | `Neo.Settings`, `Neo.Save`, `SaveProvider`, `GameSettings`, save keys and persistent config |
| Quests/cards/reactive data | `Neo.Quest`, `Neo.Cards`, `Neo.Reactive`, related ScriptableObjects/editors |
| Level/progression/RPG/network | `Neo.Level`, `Neo.Progression`, `Neo.Rpg`, `Neo.StateMachine`, `Neo.Network`; inspect exact docs/API before reuse |

Do not import or copy whole systems when a small adapter/reference is enough.

## Code-First Boundary

Do not choose NoCode-style or inspector-event components as a substitute for straightforward agent-written C#.

Avoid as implementation targets unless the existing scene already depends on them or the user explicitly asks for NoCode wiring:

- `Neo.Condition` / NeoCondition-style conditional graphs. Write normal `if`/`switch` logic in C# instead.
- `UnityLifecycleEvents` and similar lifecycle-to-UnityEvent wrappers. Write `Awake`, `Start`, `OnEnable`, `OnDisable`, `Update`, or explicit methods in C# instead.
- generic UnityEvent relay/bridge components, visual trigger chains, and inspector-only flow-control helpers when a typed method or small adapter script is clearer.
- broad `Neo.Tools` movement/input/physics/spawner/random/view helper components unless the project already uses that exact component family and reuse is clearly smaller than code.

Reuse NeoxiderTools for established high-level systems and data/runtime services. Keep gameplay decisions, branching, lifecycle, and feature-specific behavior in typed project code.

## Minimal Integration Pattern

Prefer a small-adapter style:

- `Packages/manifest.json` may depend on `com.neoxider.tools`; if it does not, ask before adding it.
- `NeoxiderPages` sample assets may be imported under `Assets/Samples/Neoxider Tools/*/NeoxiderPages` or a project-specific location.
- Scene wiring owns UI flow through a `PM` object, `PageId` assets such as `PageMain`, `PageGame`, `PageWin`, `PageLose`, `PagePause`, `PageSettings`, `PageShop`, `UIPage` page objects, `BtnChangePage.targetPageId` references, and an `AM` audio manager object.
- Game code remains project-local, not inside the package.
- Project scripts use narrow bridges:
  - gameplay systems subscribe to `Neo.Pages.G` events and call `G.Win()` / `G.Lose()` when gameplay ends;
  - audio adapters map gameplay events to `AM.I.Play(id)` after verifying configured sound IDs;
  - rewards/economy adapters use `Money.I` only where the scene has a configured `Money` instance;
  - shop adapters wrap `Neo.Shop.Shop` events while keeping project-specific item data and persistence decisions local.

Use this pattern for new games: keep gameplay/data/adapters in the project, and let NeoxiderTools provide reusable managers/views only where they fit.

## Implementation Rules

- Keep game-specific code outside NeoxiderTools unless the task is explicitly to modify NeoxiderTools itself.
- Prefer adapters/facades that let the game use NeoxiderTools without hardcoding unrelated systems.
- Do not silently add NeoxiderTools to a clean project. Ask first.
- Do not replace an existing standalone system with NeoxiderTools unless the user requested reuse or migration.
- Do not claim a module is used by a project just because the package contains it. Verify references in code, scene YAML, prefabs, assets, or docs.
- Do not assume `Neo.Pages` exists from the package alone; verify that the `NeoxiderPages` sample was imported or import/instantiate it only after opt-in.
- Do not hardcode `AM` sound indices without checking the scene or `AMSettings`/sound arrays.
- Do not edit `Packages/packages-lock.json` by hand.
- If NeoxiderTools is unavailable after opt-in, fall back to standalone and report the limitation.

## Docs Updates

When a decision is made, update:

- `Docs/DEV_PROFILE.json`: `neoxider_tools` as `"use"`, `"standalone"`, or `"unavailable"`.
- `Docs/AGENT_MEMORY.md`: short rationale and systems reused or skipped.
- `Docs/DEV_LOG/iteration-*.md`: implementation-level reuse notes.

If Docs/ does not exist because this is a Quick Fix, report the decision in the final response instead.
