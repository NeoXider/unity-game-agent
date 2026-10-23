# Coin Clicker: task brief

This brief is given word for word to every agent in both runs. Only the "How to work" section at
the end differs between the runs (see [README.md](README.md)). The game is deliberately small: a
team should finish it in 5-15 minutes.

Unity 6000.6.0f1 project: `{PROJECT}`. Three agents work in this project **at the same time**:
`core`, `ui` and `scene`. You are **`{ROLE}`**.

## The game

One screen. Tap a big button to earn coins, buy two upgrades, and coins also arrive every second.
Progress survives a restart.

- A new game has 0 coins and both upgrades at level 0.
- Coins per click = 1 + level(StrongerClick). Coins per second = level(AutoClicker).
- Cost = floor(base × 1.15^level); base 10 for StrongerClick, 25 for AutoClicker.
- Buying takes the cost and raises the level by one. With coins < cost it fails and changes nothing.

## Contract

Do not rename anything.

Assembly `Clicker.Core` (`Assets/Clicker/Core/Clicker.Core.asmdef`), namespace `Clicker.Core`:

```csharp
public enum UpgradeId { StrongerClick, AutoClicker }

public sealed class ClickerEconomy
{
    public event System.Action Changed;           // after Click, a Tick that added coins, a successful TryBuy
    public double Coins { get; }
    public double CoinsPerClick { get; }
    public double CoinsPerSecond { get; }
    public int Level(UpgradeId id);
    public double Cost(UpgradeId id);
    public bool CanBuy(UpgradeId id);
    public void Click();
    public void Tick(double seconds);
    public bool TryBuy(UpgradeId id);
    public string ToJson();
    public static ClickerEconomy FromJson(string json); // null, empty or invalid -> a new game
}
```

Assembly `Clicker.UI` (`Assets/Clicker/UI/`, references `Clicker.Core`): `ClickerPresenter :
MonoBehaviour` loads the economy from PlayerPrefs key `clicker.save` in `Awake`, ticks it in
`Update`, saves it in `OnApplicationPause(true)` and keeps the UI in sync.

Prefab `Assets/Clicker/UI/ClickerCanvas.prefab`: a Screen Space Overlay canvas with the
`ClickerPresenter` and these children (`Text` or `TextMeshProUGUI` for texts):

| Name | Shows / does |
|---|---|
| `CoinsText` | Whole coins, for example `Coins: 12` |
| `IncomeText` | Coins per second, for example `+3/s` |
| `ClickButton` | `Button` that calls `Click()` |
| `Upgrade_StrongerClick`, `Upgrade_AutoClicker` | `Button`s; a child text shows level and cost; `interactable` is false while unaffordable |

Scene `Assets/Scenes/Main.unity`: a camera, an `EventSystem` and one `ClickerCanvas` instance; the
only scene in Build Settings.

## Roles

- **core**: `Clicker.Core`, plus at least 3 EditMode tests in `Assets/Clicker/Tests/EditMode` (asmdef
  `Clicker.Tests.EditMode`).
- **ui**: `Clicker.UI` and the `ClickerCanvas` prefab.
- **scene**: `Main.unity`, Build Settings, and a PlayMode test in `Assets/Clicker/Tests/PlayMode`
  (asmdef `Clicker.Tests.PlayMode`) that loads `Main`, clicks `ClickButton` 10 times through the
  EventSystem and checks that `CoinsText` shows 10. At the end, check that the project compiles and
  every test passes.

## Rules

- Do not commit, and do not touch files that belong to another role unless your part cannot work
  otherwise; say so in `notes` if you had to.

## Done

Finish only when your part is done and verified in Unity. End your final reply with this block:

```json
{"role": "{ROLE}", "done": true, "unity_launches": 0, "waited_minutes": 0, "blocked_by_others": 0, "notes": ""}
```

`unity_launches`: Unity processes you started yourself. `waited_minutes`: time spent waiting for
Unity or for other agents. `blocked_by_others`: times another agent's work stopped yours (a locked
project, a compile error you did not write, a file changed under you).

## How to work

{HOW_TO_WORK}
