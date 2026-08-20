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

## Sprite import mode: Single, always

Import every standalone sprite as **Sprite Mode = Single**. Reserve `Multiple` for genuine sprite
sheets and atlases — a texture that really does contain several frames.

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

## Mockup fidelity

Mockups contain mistakes. Fix them in the product and record the deviation instead of copying them:

- Typos in legal or brand text (a mis-spelled provider name, a garbled consent sentence) must be
  corrected — the mockup is not the authority on a real brand's spelling.
- Frames exported at reduced opacity, or a stray logo the designer already disowned, are not targets.

Keep a short "intentional deviations" list in the QA document so the reviewer does not spend time on
them.
