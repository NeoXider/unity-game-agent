# Proven code patterns (take and reuse)

Small proven patterns from real games (`lotto`, `FootballPing`, `matchamadness`, `4PingPong`,
`Basket Battle`, `Gem3`). All are code-first, editable in the inspector / via SO.

---

## 1. GameManager bridge on `G.On*`

A thin manager listens to states and calls gameplay. The controller doesn't open screens itself — it
calls states (`G.Win/Lose/End`), and the page system shows Win/Lose/End. (Reference: `LottGameManager`,
match3 `GameManager`, `BetflagGameSession`.)

```csharp
using Neo.Pages;
using Neo.Tools;
using UnityEngine;

public sealed class MyGameManager : Singleton<MyGameManager>
{
    [SerializeField] private MyGame game;

    protected override void Init()
    {
        base.Init();
        G.OnStart?.AddListener(game.Begin);
        G.OnRestart?.AddListener(game.Restart);
        // Progress hooks onto the win EVENT, not your own Win(): a win can come from any source
        // (G.Win/GM.Win/goal UnityEvent/cheat), so the level/score is saved every time.
        G.OnWin?.AddListener(SaveProgress);
    }

    private void SaveProgress()
    {
        if (LevelManager.I != null) LevelManager.I.SaveLevel();   // ++MaxLevel, persist
    }
}
```

```csharp
public void OnPlayerWon() { G.Win(); G.End(); }
```

**Why the event, not your own `Win()`:** if `SaveLevel()`/reward is wired only inside
`<Game>Manager.Win()`, any other win path bypasses it and progress is lost (the exact "level number
doesn't grow after Next" bug). On restart pair it with `G.OnRestart -> LevelManager.SetLastLevel()`
(sets `CurrentLevel = MaxLevel`). The same rule applies to money/score/stars: hook the award on
`G.OnWin`/`G.OnEnd`, not on one controller's method.

**When the bridge isn't needed:** a simple one-controller game subscribes to `G` itself in `OnEnable`
(like `PongGame`). A complex multi-screen game uses a non-singleton flow orchestrator (`GameFlowController`).

---

## 2. Settings via ScriptableObject

Balance/rules in an SO asset, not in constants. The controller holds a reference and reads it. Several
difficulty modes = several assets of one type. (References: `PongConfig`, `MatchSettings`, `BoardConfig`,
`BettingSettings`, `AISettings`.)

```csharp
[CreateAssetMenu(menuName = "Game/MyGameConfig")]
public sealed class MyGameConfig : ScriptableObject
{
    public int playerCount = 2;
    public float spawnDelay = 0.5f;
    public float ballSpeedMax = 18f;
}
```
```csharp
public sealed class MyGame : MonoBehaviour { [SerializeField] private MyGameConfig config; }
```

Helper methods right on the SO are fine (`BettingSettings.GetCoefficient(outcome)`).

---

## 3. Result-text component (Win/Lose/Draw)

Decouples result display from logic: a small component reads the controller's state and sets the text on
`OnEnable`. (Reference: `LottResultText`.)

```csharp
public sealed class MyResultText : MonoBehaviour
{
    [SerializeField] private TMP_Text label;
    [SerializeField] private string win = "Win!", lose = "Defeat";
    private void OnEnable()
    {
        var g = MyGame.I;
        if (g != null && g.HasResult) label.text = g.PlayerWon ? win : lose;
    }
}
```

---

## 4. Dynamic list (prefab + LayoutGroup)

A list of cells = **one-element prefab** + a container with `HorizontalLayoutGroup`/`GridLayoutGroup`.
The view spawns elements from data (not fixed `Slot_0..3` in the scene). The panel is a prefab too.
(References: tickets/bots in `lotto`, stars in match3, goals `GoalsView` in `Gem3`.)

```csharp
[SerializeField] private ItemView itemPrefab;   // one-cell prefab
[SerializeField] private Transform container;    // has a LayoutGroup
public void Setup(Sprite[] sprites, int[] counts)
{
    Clear();
    for (int i = 0; i < sprites.Length; i++)
        Instantiate(itemPrefab, container).Setup(sprites[i], counts[i]);
}
```

---

## 5. State machine on a local enum

An **object's** state (not the game flow) — an explicit `enum`, not bool flags. Game flow stays in
`GM.State`. (References: `BallState` in `4PingPong`/`Basket Battle`.)

```csharp
private enum BallState { Ready, Aiming, Flying, Frozen }
private BallState _state = BallState.Ready;
```

---

## 6. AI on Perlin noise (smooth "miss")

Human-like AI error without random jitter. (Reference: AI paddle in `4PingPong`.)

```csharp
float error = (Mathf.PerlinNoise(Time.time * cfg.aiErrorSpeed, 0f) - 0.5f) * 2f * cfg.aiError;
float target = ballX + error;
paddleX = Mathf.MoveTowards(paddleX, target, cfg.aiSpeed * Time.deltaTime);
```

---

## 7. Trajectory preview + slow-mo (physics aiming)

For drag-to-aim games: show an arc while aiming and slow time on hold. (Reference: `Basket Battle`.)

```csharp
// preview: simulate n steps and place dots/line
Vector2 p = start, v = launch;
for (int i = 0; i < steps; i++) { p += v * dt; v += Physics2D.gravity * dt; dots[i].position = p; }
// slow-mo on hold:
Time.timeScale = slowMotionScale; Time.fixedDeltaTime = 0.02f * Time.timeScale;
```

---

## 8. Session bootstrap (once per session — allowed)

Once-per-match/session objects may be created at session start (not per-frame). Frequently spawned —
prefab/pool only. (Reference: `FootballGameBootstrap.PrepareFootballersForMatch()`.)

```csharp
public void PrepareMatch()  // called on G.OnStart, not every frame
{
    _match = Instantiate(matchPrefab);
    _match.Init(config);
}
```

---

## 9. DOTween juice

`DOPunchScale`, looped `DOScale` Yoyo (idle "press me"), `DOFillAmount` (progress bar).
`DOKill()` before restarting a tween. Init before the scene:

```csharp
[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
static void Init() => DG.Tweening.DOTween.Init();
```
```csharp
transform.DOPunchScale(Vector3.one * 0.14f, 0.3f);                       // tap feedback
btn.transform.DOScale(1.08f, 0.7f).SetLoops(-1, LoopType.Yoyo);          // idle pulse
fill.DOFillAmount(progress, 0.3f).SetEase(Ease.OutQuad);                  // progress
```

---

## 10. Inspector cheat buttons — `[Button]`, no custom Editor

`[Button]` draws on **any** `MonoBehaviour` (even in the global namespace) via the global fallback
inspector `NeoCustomEditor`. **Don't write your own `CustomEditor` just for buttons** — it shadows the
fallback and the buttons disappear. Guard with `#if UNITY_EDITOR`.

```csharp
using Neo;                       // ButtonAttribute
#if UNITY_EDITOR
    [Button("Win")] public void Cheat_Win() => G.Win();
    [Button("+30 sec")] public void Cheat_AddTime() => timeLeft += 30f;
#endif
```

---

## 11. Timer text — `TimeToText` (don't write your own)

`TimeToText` (`Neo.Tools`) formats seconds to `mm:ss` on a `TMP_Text` (Clock/Compact, prefix/suffix).
No custom `MonoBehaviour` timer needed.

```csharp
[SerializeField] private Neo.Tools.TimeToText timerText;
private void Tick() { timeLeft -= Time.deltaTime; timerText.Set(timeLeft); }
// or in the inspector: onTimeChanged (UnityEvent<float>) -> TimeToText.Set
```

---

## 12. Fly "object -> UI slot" — `AnimationFly`

A collected/reward sprite flies into a HUD slot. One scene object with `AnimationFly` (singleton) and a
set `parentCanvas`/`spawnParent` **inside a Canvas** (otherwise the UI Image won't render). Start
position is read **synchronously** — the original can be removed immediately. Update the counter
**immediately**; the flight is cosmetic.

```csharp
using Neo;
if (AnimationFly.I != null) AnimationFly.I.PlaySpriteWorldToCanvas(sprite, 1, worldStart, uiSlot);
view.MarkCollected(sprite); // don't tie correctness to the animation callback
```

---

## 13. UI sprites — only from the project + `SetNativeSize`

Don't substitute homemade images and don't guess sizes. Take a ready asset from `Sprites/` and call
`image.SetNativeSize()` — the image takes its native pixel size; the designer adjusts final sizes.

```csharp
img.sprite = AssetDatabase.LoadAssetAtPath<Sprite>("Assets/_source/Sprites/Layer 11.png");
img.SetNativeSize();   // don't guess sizeDelta
```

---

## 14. Custom resource wrapper (nonstandard economy)

For bets/coefficients/min-bet, wrap `Money` with your own manager instead of bending a Neo component.
(Reference: `StarsWallet` + `BettingManager` in `FootballPing`.)

```csharp
public sealed class BettingManager : MonoBehaviour
{
    [SerializeField] private BettingSettings settings;
    public bool TryPlaceBet(int amount, Outcome pick) { /* min-bet, spend Money, remember */ }
    public void Resolve(MatchResult r) { if (r.Outcome == _bet.Outcome) Money.I.Add(_bet.amount * _bet.coef); }
}
```
