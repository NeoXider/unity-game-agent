# Asset Restyle To An Approved Mockup

How to replace a game's art with an approved design and prove the result matches it. Distilled from the
Block Puzzle MVP restyle (2026-11-20): five worker rounds, the first three judged by eye and rejected by the
owner, the last two measured and accepted. Follow the measured path from the start.

## 1. Pick and freeze one reference

- Generate variants from a real game screenshot (ChatGPT Images through the Web Search Neo macro
  `chatgpt_images.py`, all variants in ONE chat, prompt starts with "Use ONLY the newly attached
  screenshot as the base image"). Keep layout and block positions identical across variants so they
  compare cleanly; put prompts next to the images.
- The owner approves exactly one image. Save it in the repo (e.g. `Docs/Screenshots/<Design>/approved-game.png`)
  and link it from the spec. Features drawn on the mockup but not implemented (boosters, banner) are
  decided explicitly: hidden, or shown disabled (dimmed, count 0, not interactable).
- The approved image is the acceptance standard. "Similar style" is not acceptance; the owner will
  reject look-alikes (round 1-3 here: right palette, wrong frame, flat brass, no shadows, wrong font).

## 2. Measure, do not eyeball

Use [design-diff.py](design-diff.py) on a capture whose game state equals the mockup state (same board,
tray, scores, progress). Make the capture fixture reproduce that state before anything else.

```bash
python tools/design-diff.py Docs/Screenshots/Restyle/after/game.png \
  --ref Docs/Screenshots/MVPDesign/approved-game.png --regions regions.json --skip boosters
```

- Per region: shift (template match), MAE and SSIM. Pass = shift <= 3 px, MAE <= 14, SSIM >= 0.80.
  It also writes a 50/50 blend, a heatmap and `reference | shot` crops per region.
- Regions cover every element: plaques, buttons, progress, frame top/left/bottom, cells, tray, and three
  background strips. Without regions you only get one blurry global number.
- Self-check: the reference against itself must PASS; the old art must FAIL everywhere. Record both
  tables ("before" vs "after") in the comparison doc.
- Freeze the tool and thresholds; workers may read it, not edit it. The coordinator reruns it on the
  final capture independently of the worker's report.
- The metric covers only screens that have a mockup. Every other page gets 100 % crops (step 6).

Numbers from the restyle: drawn look-alikes reached SSIM 0.37-0.62; assets cut from the mockup reached
0.84-0.99 with 0 px shift.

## 3. Cut the assets from the mockup itself

If the mockup is the owner's own art and its resolution is close to the target viewport (941x1672 for a
900x1600 target here), slicing it beats any redraw:

- Normalise the mockup to the target viewport once and cut from that copy: board frame (9-slice),
  empty cell, filled tile with its contact shadow, tray tile with its drop shadow, plaques, buttons,
  progress groove, icons, background.
- Erase baked digits and labels by cloning the surrounding brushed metal / slate / wood; real text stays
  TMP. Never bake text into a texture.
- Stage palettes: recolour the one cut tile, so bevel, grain and shadow stay identical across stages.
  Check every stage against the empty cells and the background (a grey "walnut" vanished in the tray).
- Font: shortlist OFL fonts with Cyrillic/needed scripts, render the mockup's digits with each, pick by
  SSIM on the plaque regions (Bitter ExtraBold won here at 0.918 / 0.965). Check the license file: a
  candidate that turned out Apache was dropped under an OFL-only rule. Add the notice to the project's
  third-party file. Keep CJK fallbacks.
- Small round icons (medals, badges) cut from the mockup are only ~140 px and look muddy when shown at
  ~170 px, with remnants of whatever icon was erased. Render them procedurally at 4x supersampling
  (512 px final): ring with bevel and directional light, dark face with fine grain, vector glyph on top.
- Mockup resolution caps sharpness on 1080x2400 screens (~1.4x upscale). Note it; upscale with a proper
  upscaler later rather than repainting.

## 4. Background plates cut from the mockup leave ghosts

The game background is the mockup with the UI removed. Areas under elements that never change are
harmless, but anything under DYNAMIC content (tray pieces, counters) shows the inpaint patches as soon as
the content differs from the mockup state. The diff will not catch this, because in the reference state
the same pieces cover the patches.

- Check by capturing a different game state and boosting contrast (x2.2) on the tray band.
- Fix with [plate-patch.py](plate-patch.py): replace only the footprints of the mockup's dynamic items
  (bounding boxes + padding, plus the drop-shadow offset) with tone-matched clean texture, keeping the
  mockup's low-frequency shading, feathered edges.
- There is a tension with the metric: wider patches hide ghosts better but change grain and lower the
  tray SSIM (pad 30 -> 0.79 fail, pad 20 -> 0.825 pass, steps gone). Sweep the padding and take the
  smallest that removes visible steps while still passing.

## 5. Shadows

- Big UI (plaques, buttons, panels, frame, cards): a blurred runtime shadow. mob-sakai UIEffect v5
  (`com.coffee.ui-effect`, MIT, git URL `...UIEffect.git?path=Packages/src#<tag>`) is the vetted choice; the
  paid True Shadow is not needed.
- Many repeated elements (64 board cells, tray blocks): bake the contact shadow into the tile art or use one
  pre-blurred shadow sprite; per-element runtime blur on dozens of images is not worth it on 2 GB phones.
  The dragged piece gets a larger offset/blur (lifted).
- Verify a shadow darkens: compare the same pixels with the effect on and off. Here a colour-space mistake
  made UIEffect shadows LIGHTEN slate, so "shadows were added" while nothing was visible.
- Judge at 100 % next to the mockup (warm black ~#140A05, 75-85 % core, 4-8 px offset at 900x1600).
  Thumbnails hid that the shadows were too weak; the owner caught it, the coordinator did not.
- Remove runtime shadows that duplicate shadows already baked into cut assets.
- UIEffect adds its settings asset to Player Settings > Preloaded Assets on import. Keep that entry (it
  carries the shader variants into the build); if ProjectSettings.asset has the owner's uncommitted edits,
  ask before touching it. Confirm the build log compiles `Hidden/UI/Default (UIEffect)` for the target API.

## 6. Popups and every other page

- Every Image that is not drawn at its sprite's native aspect must be Sliced (or Tiled for texture fills)
  with borders that fully contain corner plates and rivets. "Sliced" with zero borders stretches exactly like
  Simple; it was the cause of oval rivets and smeared slate here.
- Run the editor audit [ImageSliceAudit.cs](ImageSliceAudit.cs) (copy into an `Editor` folder, set the art
  root): it lists Images on the art root whose rect aspect differs from the sprite by >2 % without real
  borders, compressed borders, and textures that must tile. Acceptance is an empty list in Edit and Play Mode.
- Replacing a texture with a different size: if the sprite is `spriteMode: 2` (Multiple), the `.meta` keeps
  the old explicit rect (144x144 kept showing only a corner of a 512 texture). Update the rect or the sprite.
- Popups share one frame language with the main screen (same thick rail and corner plates as the board
  frame), polished brass buttons from the plaque material, serif titles and button labels.
- Content keeps >= 16-24 px from the inner frame; titles auto-size or wrap and never run under the close
  button; one close-button rule for all popups; a stacked popup hides or dims the panel under it.
- Coordinator review: 100 % crops of every popup's corners and buttons, all pages in one pass, one
  consolidated defect list to the worker. Piecemeal fixes from the owner's screenshots are a review failure.

## 7. Device check before handing over an APK

- Batchmode build with a static method (`BuildPipeline.BuildPlayer`, scenes from `EditorBuildSettings`,
  `buildAppBundle = false`, non-development so no watermark); see [mobile-build-and-size.md](mobile-build-and-size.md).
- Memory: one Unity Editor at a time; an IL2CPP build and a ~4 GB emulator together crashed both here.
  Close the emulator during the build.
- Clean install (`adb uninstall` first) to see first-launch behaviour: default language, onboarding.
- Walk the real flow: onboarding, tutorial skip, game, a real drag (on Android 9 BlueStacks chained swipes
  lift the finger; use one long `swipe` for drags), settings, end game, letter, result.
- Rerun the diff on a device frame for regions that do not depend on the game state (frame, background,
  settings button).

## 8. Orchestration that kept the pace

- One worker in one session for the whole restyle (resume, never restart); the coordinator owns review,
  metrics, docs and git. A Codex `gpt-6.2-sol` `ultra` worker used ~1-2 % of a weekly limit per round.
- Every round's brief names: the measure and its pass line, owned files, files that must keep their SHA-256
  (owner's uncommitted edits), "no commit", and the evidence to return (diff table, audit list, crops).
- Keep a notes file updated after every step so a crash (it happened: `0xC0000409` under memory pressure)
  resumes without loss.
- Deliverables: `Docs/RESTYLE_COMPARISON.md` with before/after per page, the diff tables, stage palettes,
  close-ups, checks run and not run, open risks; screenshots in `Docs/Screenshots/Restyle/{before,after,review,diff}`.
