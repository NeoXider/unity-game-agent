# Scene skeleton (reference)

This is what a finished casual scene looks like. **Everything static already sits here and is wired in
the inspector** — a new project is assembled to the same skeleton, without bootstraps. Reference:
Match-3 (`Gem3`); the same skeleton appears in `lotto`, `matchamadness`, and others.

```text
EventSystem            // input (InputSystemUIInputModule)
Main Camera            // + AudioListener, URP data
Particles              // container for dynamic particles
PinnedStorage          // utility
-AM   {AM, AMSettings}             // audio manager
  Efx   {AudioSource}              //   SFX source
  Music {AudioSource}              //   music
Canvas bg   {Canvas, CanvasScaler, GraphicRaycaster}
  bg  {Image}                      // background under everything
-System--                          // ALL singleton managers (empty grouping root)
  GM            {GM}               // state machine
  EM            {EM}               // event hub
  Score         {ScoreManager}
  Money         {Money}
  Level         {LevelManager}     // level/stage progress (Neo.Level)
  --Other                          // separator
  SaveManager   {SaveManager}
  Unscaled      {UnscaledTimeSSU}  // unscaled time (timers during pause)
  GameManager   {GameManager}      // this game's bridge logic (listens to G.On*)
  SwipeController {SwipeController} // swipe input (if needed)
  Pole / Board  {<board game logic>}      // game field/board
    Cells       // permanent cells (Cell_x_y), live in the scene
    Field       {SpriteRenderer}   // field frame background
    Pieces      // container for dynamic pieces (created during play)
  Sprite Mask   {SpriteMask}       // mask cropping pieces to the field (if needed)
PM   {PM, Canvas, CanvasScaler, GraphicRaycaster}   // screen manager
  Game Page  {UIPage, DOTweenAnimation}
  Menu Page  {UIPage}
  Pause Page {UIPage, DOTweenAnimation}
  Win Page   {UIPage, DOTweenAnimation}
  Lose Page  {UIPage, DOTweenAnimation}
  End Page   {UIPage, DOTweenAnimation}
```

## Principles from the hierarchy

- **`-System--`** — single grouping root for all `Singleton<T>` managers. One object per manager, no
  nesting. The game's `<Game>Manager` bridge goes here too. Visible, easy to toggle and replace.
- **`Pole`/`Board`** — the board logic holds **permanent `Cells` in the scene** (built by an editor
  button), a separate `Field` sprite, and a `Pieces` container for dynamics. The field is **not created
  at Play** — it is already in the scene; at Play only pieces spawn into `Pieces`.
- **`PM`** — separate Canvas, children = pages. One active; the rest `inactive`.
- Game world (field/piece sprites) — in world space under `Main Camera`; UI — in `PM`/`Canvas bg`.
- **Editor builders** that assembled scene statics (cells, frames) are **one-shot**, deleted afterward.

## Screens: NeoxiderPages (PM / UIPage)

- A screen = GameObject with `UIPage` + a `PageId` asset. All `UIPage`s are **children of the `PM` object**.
- Standard set: **Menu / Game / Pause / Win / Lose / End**
  (`Tools -> Neoxider -> Pages -> Generate Default PageIds`).
- Create a page (no code): screen UI -> `UIPage` on the root -> **Generate** section -> name ->
  **Generate & Assign**. The page sits next to `PM`.
- Switching:
  - By button — **`BtnChangePage`**: `Action = OpenPage` + `targetPageId` (or `Cancel`/`CloseCurrent`),
    optional `GameState.State` (Start/Restart/Pause/Resume).
  - By code — `UIKit.ShowPage(pageId)` / `PM.I.ChangePage(pageId)` / `PM.I.ChangePageByName("Game")`.
  - React — `PM.I.OnPageChanged(UIPage)`.
- A `popup` opens on top (`ActivePage`); a normal page opens exclusively (`SetPage`).
  `Ignore On Exclusive Change` — don't close on exclusive transitions.

## Game Page — already-assembled top bar (reuse, don't rebuild)

```text
Game Page {UIPage}
  game {Image}                         // full-screen game-content container
    Top {Image}                        // HUD top strip
      frame_cash_amount {Image}
        money {TextMeshProUGUI, TextMoney}   // wallet — auto-output from Money
          Coin {Image}
      button_setting {Button, BtnChangePage, PlayAudioBtn}  // -> Pause Page
      Level {TextMeshProUGUI, TextLevel}     // level number — auto-output from LevelManager
      frame_score {Image}
        Score {TextMeshProUGUI, TextScore}   // points — auto-output from ScoreManager
```

In the Game Page the **score/money/level/settings button already exist and are bound** via Neo
components (`TextScore`, `TextMoney`, `TextLevel`, `BtnChangePage`). Don't rebuild them — add only what
is missing (level timer, goals panel). All new Game-screen content goes **inside `game`/`Top`**, not in
a new Canvas.

> "Value -> UI" binding is done by the Neo component itself: `TextLevel` reads `LevelManager`,
> `TextScore` reads `ScoreManager`, `TextMoney` reads `Money`. No custom code to update those texts.

## Project structure

```text
Assets/_source/
  Scripts/Runtime/   gameplay scripts   (>10 files -> functional folders Gameplay/ Config/ UI/)
  Scripts/Editor/    editor tools       (one-shot builders deleted afterward)
  Prefabs/  Sprites/  Audio/  TTF/  Docs/
  Settings/          game SO configs
Assets/Scenes/SampleScene.unity
```
