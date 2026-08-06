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

## Mockup fidelity

Mockups contain mistakes. Fix them in the product and record the deviation instead of copying them:

- Typos in legal or brand text (a mis-spelled provider name, a garbled consent sentence) must be
  corrected — the mockup is not the authority on a real brand's spelling.
- Frames exported at reduced opacity, or a stray logo the designer already disowned, are not targets.

Keep a short "intentional deviations" list in the QA document so the reviewer does not spend time on
them.
