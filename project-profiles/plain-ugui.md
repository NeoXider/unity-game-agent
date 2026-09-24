# Project Profile: Plain uGUI

Use this preset when the project uses Unity Canvas/uGUI and no external page framework is mandatory.

## Detection hints
- `Canvas`, `GraphicRaycaster`, `EventSystem` usage is primary.
- No hard dependency on third-party UI page managers.

## Default decisions
- UI stack: `uGUI`.
- Keep UI architecture simple: screen controllers + explicit references.
- Reuse Unity built-in components first.

## Mandatory checks before custom code
- Verify Unity built-in UI flow covers requirements.
- Record if/why extra package is required.

---

## Ready uGUI effect packages — check these three before writing your own

**Rule: before hand-writing any uGUI visual effect (confetti, sparks, explosions, soft/feathered masks,
tutorial spotlight cut-outs, glow, outline, blur, dissolve, gradient), evaluate the mob-sakai packages
below and record the decision.** All three are MIT, actively maintained, installable from OpenUPM
(`openupm add <package-id>`) or by git URL as documented in each repo README (`?path=Packages/src` for
SoftMask and UIEffect). Only after they are rejected for a concrete reason does the
[external solution reuse gate](../tools/external-solution-reuse.md) allow custom code.

| Need | Package | Id |
|---|---|---|
| Particles inside a Canvas | [ParticleEffectForUGUI](https://github.com/mob-sakai/ParticleEffectForUGUI) | `com.coffee.ui-particle` |
| Soft / feathered / shaped masks | [SoftMaskForUGUI](https://github.com/mob-sakai/SoftMaskForUGUI) | `com.coffee.softmask-for-ugui` |
| Shadow, outline, glow, blur, dissolve, gradient | [UIEffect](https://github.com/mob-sakai/UIEffect) | `com.coffee.ui-effect` |

**UIParticle (`com.coffee.ui-particle`, 4.13.x, Unity 2018.3+).** Renders a real `ParticleSystem`
through the `CanvasRenderer` using `MeshBake`/`MeshTrailBake` — **no extra Camera, no RenderTexture, no
extra Canvas**. Components: `UIParticle` (wraps the system and its children), `UIParticleAttractor`
(pull particles to a target — the "coins fly into the counter" effect), `ParticleSystemPreviewer`.
Particles are maskable by `Mask`/`RectMask2D` and sort by sibling index like any other Graphic.
Limits: 65,535 vertices per render; UI shaders only (`UI/Default`, `UI/Additive`) — built-in particle
shaders are unsupported; some overhead versus a bare `ParticleSystem`. **Several different sprites in
one system** come from the `Texture Sheet Animation` module in **Sprites** mode, not from several
systems or a custom spawner.

**SoftMaskForUGUI (`com.coffee.softmask-for-ugui`, 3.2.x, Unity 2019.4+).** `SoftMask` (soft /
anti-aliased / normal modes), `SoftMaskable` (auto-added to children), `MaskingShape` (additive or
subtractive regions — this is the tutorial "dim everything except this button" cut-out),
`RectTransformFitter`. Nests up to 4 levels; works with TextMeshPro and Spine. Limits: needs an
alpha-capable texture format (Android RGB ETC1 will not work — use RGBA ETC2); alpha hit test needs
readable, non-crunched textures; shader variants must be registered in Project Settings for runtime;
known issues with DynamicResolution and URP RenderScale.

**UIEffect (`com.coffee.ui-effect`, 5.9.x, Unity 2020.3+).** `UIEffect` (the effect itself),
`UIEffectTweener` (animates an effect without an AnimationClip), `UIEffectReplica` (shares one effect
setup across many graphics). Covers tone filters (grayscale, sepia, nega, retro, posterize), color
filters, sampling filters (blur, pixelation, RGB shift, edge), transitions (fade, cutoff, dissolve,
shiny, melt, burn, blaze, pattern), shadow/outline/mirror, and gradation. Limits: register shader
variants in Project Settings or effects break in a build; TMP blur falls back to the Fast variant;
only uGUI `Graphic` and `TextMeshProUGUI` targets.

### "Particles are not visible in my canvas" is not a reason to write your own effect

A world-space `ParticleSystem` can never draw over a **Screen Space - Overlay** canvas. Under
**Screen Space - Camera** it can, and the order is decided by sorting layer / order in layer and by
distance to the canvas plane. When the problem is ordering, the fix is a **nested Canvas with
`Override Sorting` and an explicit `Sorting Order`** around the affected subtree, or `UIParticle`.
Hand-rolling an `Image`-based confetti/explosion component because "particles do not work in uGUI" is
a false premise and costs both the effect quality and the maintenance.

---

## Sprite Shaders Ultimate

A paid Asset Store shader family (Ekin Cantas, <https://ekincantas.com/sprite-shaders-ultimate/>).
Not something to buy on the agent's initiative — but when a project already ships it under `Assets/`,
it is usually the shortest route to any per-pixel effect, and it is easy to miss because asset-store
packages do not appear in `Packages/manifest.json`.

**Why it is worth checking first: one shader family covers every surface.**

| Surface | Shader |
|---|---|
| uGUI `Image`, buttons | `GUI SSU`, `Additive GUI SSU` |
| `SpriteRenderer` | `Standard SSU`, `Additive SSU`, `Multiplicative SSU` |
| 2D lights (URP) | `2D Lit URP SSU` |
| Meshes | `3D Lit BuiltIn/URP SSU` (+ Cutout variants) |
| Text / TextMeshPro | any of the above with `_ISTEXT_ON` / `_ISTEXTMESHPRO_ON` |

Roughly 113 shader keywords, grouped: tint and colour replace, hue/saturation/contrast/brightness,
inner/outer/pixel outline, drop shadow, shine, sine and ping-pong glow, four dissolve modes, status
looks (frozen, flame, poison, burn, hologram, glitch, smoke, metal, camouflage), UV scroll/rotate/
scale/distort, wiggle, vibrate, squeeze, wind with parallax, gaussian blur, sharpen, pixelate,
halftone, and two extra texture layers with sprite-sheet playback.

Two things that matter in practice:

- **`_TOGGLEUNSCALEDTIME_ON` and the `UnscaledTimeSSU` component** keep animated effects running at
  `Time.timeScale = 0`. Pause and game-over screens freeze time, and a monetisation button that
  stops shimmering there is the one place the effect was bought for.
- **Whitening a sprite is a built-in toggle** (`_ENABLESTRONGTINT_ON`, `_ENABLECOLORREPLACE_ON`).
  `SpriteRenderer.color` multiplies the texture and cannot do it — see
  [../tools/code-writing.md](../tools/code-writing.md) — so this is the standard reason teams reach
  for a custom shader. Check for SSU before writing one.

Helper components: `ImageSSU` (Image subclass for UI), `MaterialInstancerSSU` (per-renderer material
instances without duplicating assets), `ShaderFaderSSU` (animate properties), `SpriteSheetSSU`,
`UnscaledTimeSSU`, plus `InteractiveWindSSU` / `WindManagerSSU` / `WindParallaxSSU` /
`InteractiveSquishSSU`.

## RectTransform geometry rules

### `sizeDelta` is not the size

With stretching anchors (`anchorMin != anchorMax` on an axis), `sizeDelta` is the **difference from the
parent's size on that axis**, not the size. Writing `sizeDelta = (640, 116)` onto a rect stretched
across a 640-wide parent produces a 1280-wide element — this shipped once as a boss timer bar at
1280 x 232 instead of 640 x 116.

**Rule: after setting a size through MCP or code, read back `rectTransform.rect.width/height` — never
`sizeDelta` — and compare with the intended value.** To set an absolute size, either collapse the
anchors first (`anchorMin = anchorMax`) or use `SetSizeWithCurrentAnchors`.

### Pivot decides what rotation and scale do

Rotation, scale, and tween punches all happen around the pivot. A weapon icon rotated 45° flew outside
its card because the pivot was at the top-centre, not the middle. **Before rotating or scaling an
element, read its pivot**; if the intent is "spin in place", the pivot must be `(0.5, 0.5)`, and moving
the pivot also moves the element unless the anchored position is compensated.

### Draw order and input order are sibling order

uGUI draws children in hierarchy order — later siblings paint over earlier ones, and raycasts hit the
topmost first. Three separate defects from one cause:

- popups rendered underneath the pages they belonged to;
- a day number hidden behind its own highlight image;
- a full-screen invisible "skip the animation" button placed last, swallowing every tap on `CLAIM`.

**Rule: verify input order by querying it, not by looking at the screen.** Run
`EventSystem.current.RaycastAll(pointerEventDataAtButtonCentre, results)` at the button's screen
position and assert the intended object is `results[0]`. A full-screen transparent catcher must be
gated (disabled when not needed) or placed below the interactive layer, never "last so it is on top".
For layering, prefer explicit `SetSiblingIndex` / a nested Canvas with `Override Sorting` over
depending on creation order.

## Adaptivity canon (mobile portrait)

These are defaults, not suggestions. Deviating requires a recorded reason.

### CanvasScaler

Every `CanvasScaler` in the project — scenes **and** prefabs, including per-page canvases with an
overridden sorting order:

| Field | Value |
|---|---|
| `UI Scale Mode` | `Scale With Screen Size` |
| `Reference Resolution` | one project-wide value (e.g. `1080 x 1920` portrait) |
| `Screen Match Mode` | **`Expand`** |

`Expand` is the only mode that never crops: on an unexpected aspect ratio the content gains slack
instead of losing edges. `Match Width Or Height` and `Shrink` cut off interface edges on phones whose
proportions differ from the reference, and the loss is invisible in the editor Game view at the
authoring aspect ratio.

Do **not** author a second reference resolution to match a mockup's device (a `390 x 844` iPhone
frame, for example). Keep one reference and let `Expand` do the work — a mockup-sized reference makes
every hand-typed coordinate wrong on real hardware.

Keep a guard test that walks every `CanvasScaler` in all scenes and prefabs and asserts the three
values above. This regresses silently and often: a single prefab override or a scene merge is enough.

### Top safe area (notches, capsules, punch-holes)

Top-most UI elements keep a hard inset from the top edge:

- **100 px** when the element is positioned from a **top pivot/anchor** (measurement starts at its own
  top edge).
- **150 px** when it is not. A smaller inset is not enough: a modern phone's real top inset is around
  **141 px** (iPhone 12/13 at `1170 x 2532`), so a nominal "100 px" element still slides under the
  cutout.

Implement with anchors plus `Screen.safeArea`, never with absolute coordinates — the inset must hold
at every target resolution, not just the one you authored in.

**The resulting top row sits lower than the mockup. That is intended.** Designers routinely place the
top HUD row at `y = 34`, straight under the cutout. Record this once as an accepted deviation and stop
re-reporting it in every QA round.

### Full-bleed art, painted maps, and scrolling

A painted background or map page (1290×2796 art on a 19.5:9 mockup) meets screens from 16:9 to 4:3.
Decide per surface, explicitly:

| Surface | Fit | Why |
|---|---|---|
| Decorative background | **cover** (`AspectRatioFitter` Envelope Parent) | edges may crop, nothing important lives there |
| Map / progress page with markers on the art | **fit to height** (page as tall as the view); on wider screens the page background shows beside it | every marker stays visible; nothing can be dragged vertically |
| Long scrolling list | scroll on one axis only | the other axis is locked in the `ScrollRect` |

- **An unintended scroll axis is a bug.** Cover-fitting a map on a 16:9 phone makes the page taller
  than the view, and the player can drag it up and down — reported by the owner as a defect. Turn
  the axis off in the `ScrollRect` *and* make the layout never overflow on it (drive the content's
  anchored position on that axis to 0).
- Horizontal pages that are separate paintings (districts, chapters) are pages, not one continuous
  strip: snap by swipe share or flick, with side arrows; show a collectible hint (coin) on the arrow
  only when the neighbouring page actually has one.
- Markers on painted art are anchored by **fractions of the painting** (`anchorMin = anchorMax =
  (x / 1290, 1 - y / 2796)`), so they stay glued to it at any scale.

### Design frame inside the safe area

For HUDs authored on a fixed mockup frame, fit a `1290×2796` design frame into the safe area and
scale it uniformly (a `DesignFrameFitter`-style component), instead of re-anchoring every element.
Record which screens use the frame and which use free anchoring.

### Resolution matrix for every UI QA round

| Size | Represents |
|---|---|
| 1290×2796 | reference / mockup (19.5:9, iPhone Pro Max class) |
| 1080×2400 | common Android (20:9) |
| 1080×1920 | 16:9 — the tallest-art / widest-screen stress case |
| 1536×2048 | 4:3 tablet |

Set it from automation with `UnityEditor.PlayModeWindow.SetCustomRenderingResolution(w, h, name)`
and restore the owner's resolution afterwards.

### Priority

Adaptivity outranks pixel-perfect mockup matching. A few pixels of difference and varying text-line
widths are not defects. Cropped content, overlapping text, and elements under the cutout are.

## Layout defects worth checking explicitly

Cheap to verify by measurement, and all of them were shipped-and-missed at least once:

- **Text overlap under auto-size.** Compare rendered glyph bounds (`ForceMeshUpdate` + `textBounds`),
  not the `RectTransform`. A rect can overlap while the glyphs do not, and vice versa — a label whose
  text grows will silently print over its neighbour.
- **Content wider than its viewport.** Measure the element's screen rect against `Screen.width` /
  `Screen.height` rather than trusting the Game view.
- **Masks sized off the item pitch.** A 4-row window must be exactly `4 x itemPitch`; a leftover
  dozen pixels shows a slice of the next item at the top of the window.
- **Edge-hugging labels.** Anything at `x ≈ 0` or flush to the right edge is a missing margin.
- **Disabled state that only exists in logic.** If a control is gated, verify the `ColorBlock`
  disabled tint actually reaches the visible graphic — a gated button that still looks enabled reads
  as a broken button.

## Sprite import mode: Single for one image, Multiple for a sheet

Import every standalone sprite as **Sprite Mode = Single**. Use `Multiple` for genuine sprite
sheets — a designer UI kit, an icon sheet, animation frames — and slice them **inside Unity** (next
section), not into separate files.

A single-image texture imported as `Multiple` gets a sliced sub-rect trimmed to its opaque content.
Two icons drawn on the same canvas size then arrive with *different* sprite rects and different
internal padding, so identical `RectTransform` boxes no longer render identically — especially with
`preserveAspect`, where the fitted size follows the sprite's aspect, not the box. The result is a
row of buttons that measure equal and look unequal, and the cause is invisible in the Inspector's
transform values.

Concrete case: two menu icons, both in a 255 x 255 box at mirrored offsets with scale 1, still looked
mismatched — the sliced rects were 94 x 88 and 92 x 92, so `preserveAspect` rendered them 255 x 238.7
and 255 x 255. Re-importing as `Single` makes both the full texture, and they line up exactly.

Check this before chasing layout numbers: `grep -rl "spriteMode: 2" --include=*.png.meta` over the art
folder. If the count is high, the convention was never enforced and other alignment bugs are queued
behind it.

**This applies to sprites you import, not to settings a human already tuned.** Import settings are
authoring decisions: `maxTextureSize`, compression, `Sprite Mode`, pixels-per-unit, and mesh type are
frequently set deliberately per asset. Do not "fix" them as collateral work — an agent silently
normalising `maxTextureSize` and `Sprite Mode` on the customer's art was a regression, not a cleanup.
Report the suspicious asset and the concrete visual defect it causes, and change it only when the task
is that defect or the user agrees.

### Designer kits and sheets: slice in Unity, do not cut files

Unity already slices a sheet into named sub-sprites and stores the names, rects, pivots and 9-slice
borders in the texture's `.meta`. **Do not cut a kit into separate PNG files** with an external script:
it duplicates the art, loses the link to the source sheet, and a re-export of the kit then needs the
whole cut repeated.

**1. Decide.** Keep the sheet and slice it — that is the default. The usual objection, "the sheet is
mostly empty space", is not a reason to cut: once its sub-sprites are in a **sprite atlas**, the build
contains only the packed pieces and the sheet's empty space never ships. Cut into files only when:

- the project has no atlases and will not get them, and the sheet is sparse or much larger than the
  pieces the game uses (say why in the task notes);
- a piece needs import settings the rest of the sheet must not have (a different compression or max
  size that an atlas cannot give it);
- the sheet is not really a sheet (one illustration with a few overlays) — then it is `Single`.

**2. Slice.** Humans: Sprite Editor → Slice → **Automatic**, method **Smart** when sprites already exist
(it keeps existing names and IDs), **Delete Existing** only on a fresh sheet. Agents: the same through
the Sprite Editor's data provider from an editor eval — no project tool needed (package
`com.unity.2d.sprite`; in Unity 6 the types are `UnityEditor.SpriteRect`,
`UnityEditor.SpriteNameFileIdPair`, `UnityEngine.GUID`):

```csharp
var imp = (TextureImporter)AssetImporter.GetAtPath(path);
imp.textureType = TextureImporterType.Sprite;
imp.spriteImportMode = SpriteImportMode.Multiple;
imp.SaveAndReimport();

var factory = new UnityEditor.U2D.Sprites.SpriteDataProviderFactories(); factory.Init();
var dp = factory.GetSpriteEditorDataProviderFromObject(imp);
dp.InitSpriteEditorDataProvider();
Texture2D readable = dp.GetDataProvider<UnityEditor.U2D.Sprites.ITextureDataProvider>().GetReadableTexture2D();
Rect[] rects = UnityEditorInternal.InternalSpriteUtility.GenerateAutomaticSpriteRectangles(readable, 12, 0); // = Slice > Automatic

SpriteRect[] sprites = rects.Select((r, i) => new SpriteRect {
    name = NameFor(i, r),                 // meaningful names: btn_next, card_progress, bar_fill...
    rect = r, alignment = SpriteAlignment.Center, pivot = new Vector2(0.5f, 0.5f),
    border = BorderFor(i, r),             // 9-slice per sub-sprite (L, B, R, T)
    spriteID = GUID.Generate() }).ToArray();
dp.SetSpriteRects(sprites);
dp.GetDataProvider<UnityEditor.U2D.Sprites.ISpriteNameFileIdDataProvider>()
  .SetNameFileIdPairs(sprites.Select(s => new SpriteNameFileIdPair(s.name, s.spriteID)));
dp.Apply();
imp.SaveAndReimport();
```

Automatic slicing is a first draft. Check it before naming: a glow or drop shadow separated from its
button (raise the alpha threshold's reach by padding the rect, or merge the two rects), two pieces that
touch merged into one (split the rect by hand), tiny specks (raise `minRectSize`).

**3. Name, pivot, border.** Render a numbered contact sheet of the rects (index drawn on each), write the
index → name table from what each piece is on the mockup (`btn_next`, `card_progress`, `bar_fill_gold`),
then apply names, pivots (centre for UI) and 9-slice borders (measured from the alpha silhouette, next
section) in one pass. Names describe the role, not the kit position. The `.meta` is the record
afterwards; the table only lives in the task notes while working.

**4. Keep IDs stable.** References in scenes and prefabs point at a sub-sprite's `spriteID`, not its
name or file.

- **Renaming is safe** when the existing `spriteID` is kept: `GetSpriteRects()`, change `name`/`border`,
  `SetSpriteRects`, update the name/ID pairs, `Apply`.
- **Re-slicing is not:** fresh `GUID.Generate()` IDs orphan every reference. When the designer
  re-exports the kit **over the same file** (keep the file name — the `.meta` and its old rects stay),
  read the old rects first, auto-slice the new art, match each new rect to the old one with the largest
  overlap (IoU ≥ 0.5; the same name if pieces moved far), and carry over `spriteID`, name, pivot and
  border. New pieces get new IDs and names; old pieces with no match are reported, not silently dropped.

**5. Verify.** Sprite count equals the table; a contact sheet rendered from the imported sub-sprites
(not from your rects) shows every name on the right piece with no clipped glow; every scene/prefab
reference to the sheet still resolves (no missing sprites); stretchable pieces render cleanly at 2–3×
their width through `Image.Type.Sliced`.

**6. Build.** Put the sheet (or its folder) into the screen's sprite atlas. Sub-sprites drawn with a
UV-dependent shader effect stay out of atlases (see [../tools/shaders-and-vfx.md](../tools/shaders-and-vfx.md)).

### Renaming sprite files

Sliced sprite names live inside the `.png.meta` (`internalIDToNameTable` `second:` entries and
`sprites[].name`), so renaming the file keeps the old sprite names and silently breaks name-based
lookups and parsers. Rewrite both meta fields to the new base name and keep each `internalID`.
Non-ASCII sprite names are stored as quoted `\uXXXX` escape strings — match the whole quoted line.

### 9-slice borders measured from the art

When borders must come from the art itself (bulk import, many sub-sprites), measure the corner radius from the
**alpha silhouette thresholded at alpha ≥ 250**, not by scanning for uniform rows/columns: modern UI art
has gradients and glow, so no two adjacent lines are equal, and a looser tolerance produces garbage. The
high threshold also ignores soft drop shadows, which otherwise inflate the border to half the sprite.
Force opposing borders symmetric when one exceeds ~2× the other (a shadow lip skews one edge), and zero
a border per axis — a pill-shaped button keeps its horizontal border.

## Mockup fidelity

Mockups contain mistakes. Fix them in the product and record the deviation instead of copying them:

- Typos in legal or brand text (a mis-spelled provider name, a garbled consent sentence) must be
  corrected — the mockup is not the authority on a real brand's spelling.
- Frames exported at reduced opacity, or a stray logo the designer already disowned, are not targets.

Keep a short "intentional deviations" list in the QA document so the reviewer does not spend time on
them.
