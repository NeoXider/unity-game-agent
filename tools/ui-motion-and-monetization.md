# UI Motion, Reveal Order, and Monetisation Priority (uGUI)

Load this for any mobile/casual screen that opens, rewards, or sells something. A static screen reads
as unfinished no matter how good the art is; a screen whose buttons can be pressed before they are
visible is a bug. The recipes below are DOTween-based and assume uGUI; they were shaped over eight QA
rounds on a shipped casual puzzle game.

## 1. Three layers of motion

| Layer | What moves | Owner |
|---|---|---|
| Page transition | the whole page (fade / slide / scale) | page framework (`UIPage` in NeoxiderPages, or one `PageTransition` component) |
| In-page entrance | the page's items, one after another | one stagger component per page (`UiStaggerIn` pattern below) |
| Feedback | a single control reacting to the finger or to a state change | per-control component (`UiButtonPress`, punch on arrival, attention loop on a CTA) |

Keep the layers on different properties or different objects, or they fight: a page entrance that
scales items and a press effect that scales the same button will leave it stuck at 0.93.

## 2. In-page entrance (stagger)

Animate **alpha and scale only** — never position — so layout groups keep ownership of placement.

Rules that each cost a QA round when missing:

- **Invisible items take no taps.** Set `CanvasGroup.blocksRaycasts = false` at the start and turn it
  on in the fade tween's `OnStart`, not `OnComplete`: the control answers the moment it starts to
  appear. Without this, a fast player taps an invisible `Claim` and gets a reward they never saw.
- **Store the rest scale once** (first `Play`) and restore it on `OnDisable` (kill with complete).
  Re-reading `localScale` on every show captures a half-animated value and the item shrinks a little
  on every visit.
- **Replay on every show** (`OnEnable`), with `SetUpdate(true)` so a paused game (`timeScale = 0`)
  still animates its pause/Win/Lose pages.
- **`SetLink(gameObject)` on every tween** so destroying or disabling the page kills its tweens; a
  tween outliving its target throws or animates a pooled object.
- Typical timings: delay 0.05 s, stagger 0.05 s, duration 0.35 s, from-scale 0.9, `Ease.OutBack`.

## 3. Press feedback on every button

A tactile press (scale to 0.93 in 0.08 s, spring back with `OutBack` in 0.28 s) should exist on
**every** `Button` — inject it at startup by walking the page root
(`GetComponentsInChildren<Button>(true)`) instead of hand-adding it, and skip objects that are not
real buttons (map markers, debug toggles).

- Take the rest scale in `Awake` and snap near-1 values (within 0.15) to exactly 1: `Awake` can run
  while an entrance still has the button at 0.9, and that value must not become the rest size.
- Kill only the component's own tween — never `DOTween.Kill(transform)`, which also kills the
  entrance or a reward punch on the same object.
- Release on `PointerUp` **and** `PointerExit`, and restore the rest scale in `OnDisable` if the
  finger was down when the page closed. Otherwise a button pressed during a page switch comes back
  small ("sticky scale").

## 4. Reveal order: read order first, the ad offer last, the exit later still

A result screen (Win, Gift, Daily reward, Time's Up) reveals in the order the player should read it,
and the order itself is the monetisation design:

```
1. Headline (BRILLIANT! / TIME'S UP)                    0.00 s
2. What was earned (coins roll up, icons pop)            ~0.3 s
3. Progress cards (bars fill as each card arrives)       ~0.6 s
4. Rewarded / IAP offer (x2 coins, Continue for video)   ~1.0 s  <- attention loop starts here
5. Plain exit (Next / No thanks / Close)                 ~1.0 s + DelayedDecline (1-2 s, tunable)
```

- **The paid or rewarded action appears before the free exit, and is visually heavier** (gold vs
  green/plain, larger, with shine or a pulse). The free exit arrives after a tunable delay
  (`DelayedDeclineSeconds` in the economy config) — never hide it entirely: stores reject dark
  patterns, and a player who cannot leave uninstalls.
- **Attention loop on the CTA only:** a slow scale breathe (1.0 → 1.04, 1.2 s yoyo) plus a shader
  shine sweep. Use a *private material clone* so one button's shine does not animate every button
  sharing the material, and **unscaled time** (Sprite Shaders Ultimate `_TOGGLEUNSCALEDTIME_ON` /
  `UnscaledTimeSSU`) — result screens usually freeze `timeScale`, and a monetisation button that
  stops shimmering there is exactly where the effect was bought for.
- The shine follows availability: turn it off when the offer is consumed or unavailable (no ad
  loaded, already doubled), and restore the original material — a disabled button that still
  shimmers reads as broken.
- Buttons are not pressable before they are visible (see §2), and each reward is **single-use per
  showing**: a duplicate tap or a late second callback must not pay twice.
- A replay with no reward still needs content: show one clear line ("ALREADY CLEARED") where the
  reward was, and collapse the empty space instead of leaving a hole.
- Everything happens at once outside Play Mode, so authoring in the editor shows the final layout.

## 5. Reward flights ("coins fly into the counter")

The flight is the reward. Rules:

- **Fly on the screen that shows the counter.** A reward earned on a popup that is about to close
  (Win, Gift) is *queued* and played when the destination screen opens (after its own entrance,
  ~0.35 s). Flying into a counter that is being hidden looks like the coins vanished.
- **The counter starts at the old balance and ticks per arrival**, landing exactly on the real
  balance. Write the balance to the save immediately; only the display is deferred.
- Cap the number of flying items (≈12 coins, 5 hints); big rewards count up in bigger steps.
- Items shrink to ~0.3 as they land and the target icon gets a small punch per arrival — arrivals
  melt into the counter instead of piling on it.
- Fly from the thing that produced the reward (the claimed pin, the daily banner, the button), or
  from the middle of the screen when there is none.
- A collected world object (a coin pin on a map) disappears **and stays gone**: persist the claim
  before the animation, and verify by reopening the screen that it does not come back.
- Tools: NeoxiderTools `AnimationFly` (`Neo.UI`), or `UIParticleAttractor` from
  `com.coffee.ui-particle` for a particle-based version.

## 6. Tween hygiene

- Raise DOTween capacity at startup before the first burst
  (`DOTween.SetTweensCapacity(500, 200)` from a `RuntimeInitializeOnLoadMethod(BeforeSceneLoad)`):
  auto-growth mid-animation logs a warning and hitches on the frame of the first big entrance.
- `SetLink` every infinite tween (`SetLoops(-1)`), or it outlives its page.
- `SetUpdate(true)` for anything that must move while the game is paused.

## 7. What to verify (and how)

- Drive the page open, then **hold time** (`Time.timeScale = 0` or pause the editor) at 0.1 s,
  0.5 s, 1.0 s and 2.0 s and capture each: the order is visible only across frames. A screenshot
  after the animation finished proves nothing (see [playmode-qa-automation.md](playmode-qa-automation.md)).
- Tap each button at its centre *during* the entrance through `EventSystem.RaycastAll`: an invisible
  item must not be hit.
- Press a button, switch pages while holding, come back: its scale must be exactly the rest scale.
- Collect a reward, reopen the screen, restart the app: the balance matches and nothing respawns.
