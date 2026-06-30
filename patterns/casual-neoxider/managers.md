# Reusable Neoxider managers

All managers are `Singleton<T>` (access via `T.I`, `Init()`), **one object per scene** under `-System--`.
This is a cheat sheet. Full API and inspector fields: the standalone `neoxider-tools` skill
(`references/tools.md`, `modules.md`) and `Assets/Neoxider/Docs/**` in the NeoxiderTools repo.

## Layers and namespaces

| Layer | What it is | Namespace |
|-------|-----------|-----------|
| **GM** | State machine (NotStarted/Menu/Preparing/Game/Win/Lose/End/Pause/Other), pause via `Time.timeScale`, FPS. | `Neo.Tools` |
| **EM** | Event hub: broadcasts `UnityEvent` on state change (`OnGameStart/OnWin/OnLose/OnEnd/OnPause/OnResume`…). | `Neo.Tools` |
| **G** | Facade over GM/EM from Pages: events `OnStart/OnRestart/OnMenu/OnPause/OnResume/OnWin/OnLose/OnEnd`, methods `Start()/Restart()/Win()/Lose()/End()/GoMenu()`, `Pause` property. | `Neo.Pages` |
| **PM** | Screen manager (`PM.I`). Switches `UIPage`. | `Neo.Pages` |
| **UIPage** | Marks a GameObject as a screen, holds a `PageId`. | `Neo.Pages` |
| **AM** | Audio (`AM.I`): SFX by index + music. | `Neo.Audio` |
| **Singleton<T>** | Manager base: `T.I`, `Init()`. | `Neo.Tools` |

Flow: **GM changes State -> calls EM -> EM/G broadcast `UnityEvent` -> subsystems react independently.**

## Gameplay managers

| Manager | Namespace | Key API |
|---------|-----------|---------|
| **AM** (sound) | `Neo.Audio` | `AM.I.Play(index)`, `AM.I.Play(clip, vol)`, music by index, `EnableRandomMusic()`. `_sounds` clip volume > 0. Keep indices in an `enum`/constants (like `LottGameSounds`). |
| **AMSettings** | `Neo.Audio` | mute SFX/music: `SetEfx(bool)`/`SetMusic(bool)`, `IsActiveEfx/Music`, reactive `MuteEfx/MuteMusic`. Toggle binder — `ToggleAudio` (sample). |
| **ScoreManager** | `Neo.Tools` | `.I.Add(int)`, `Set`, `SetBestScore`, `ResetScore`; `Score/BestScore/TargetScore/Progress/CountStars`. Output — `TextScore`. |
| **LevelManager** | `Neo.Level` | levels-as-stages: `LevelManager.I`, `CurrentLevel`, `SetLastLevel()`, `SetLevel(int)`, `SaveLevel()`. Output — `TextLevel` (`startAdd`/`indexOffset` fields). **Not XP.** |
| **LevelComponent** | `Neo.Core.Level` | XP progression: `AddXp(int)`, `SetLevel(int)`; `Level/TotalXp/XpToNextLevel`; `OnLevelUp/OnXpGained`. Curve — `LevelCurveDefinition`. |
| **HealthComponent** | `Neo.Core.Resources` | pools by id (`Hp/Mana`): `GetCurrent/Decrease/Increase/TrySpend/Restore`; events `OnDamage/OnHeal/OnDeath`. Good for lives. |
| **SaveManager / SaveProvider / SaveField** | `Neo.Save` | saves; don't write raw `PlayerPrefs`. `SaveProvider.SetFloat/GetFloat/SetBool/SetString`; for lists — JSON to string. |
| **Money / Shop** | `Neo.Shop` | wallet `Money.I` (`Add/Spend/TrySpend/CanSpend`, reactive `CurrentMoney`); `Shop`+`ShopItemData`+`ShopItem`+`ButtonPrice`; `TextMoney`. |
| **Spawner / PoolManager** | `Neo.Tools` | prefab spawning, waves, area, spawn points (`Spawn Points[]`), pool. |
| **TextScore / TextMoney / TextLevel / SetText / TimeToText / StarView** | `Neo.Tools` / `Neo.UI` | output values to UI (reactive, auto-binding). `TimeToText.Set(float)` — timer -> `mm:ss`. |
| **AnimationFly** | `Neo.UI` | sprite flight "world -> UI slot": `PlaySpriteWorldToCanvas(spr, n, worldStart, uiSlot)`. Needs `parentCanvas`/`spawnParent` inside a Canvas. |
| **SpinController / Row / WheelFortune / ChanceManager** | `Neo.Bonus` / `Neo.Tools` | slots (3 reels), wheel of fortune, weighted pick `new ChanceManager(w0,w1,..).GetChanceId()`. |

## How to search deeper

1. Standalone `neoxider-tools` skill: `references/tools.md` (components), `modules.md` (modules),
   `idioms.md`, `game-systems.md`.
2. Grep the package: `Assets/Neoxider/Scripts/**` (or `Library/PackageCache` for UPM).
3. Docs: `Assets/Neoxider/Docs/**` (RU) and `DocsEn/**` (EN).
4. Via MCP: `unity_reflect` (search type -> get_member) — live C# API.
