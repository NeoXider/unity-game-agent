# Shaders and VFX for uGUI games

Order of preference: **a package that already does it → a material preset on a shared shader → a
small project shader**. Custom UI shaders are cheap to write and expensive to get right across
masks, atlases, builds, and pause screens; the checklist in §3 is what "right" means.

## 1. Recommended libraries

| Need | First choice | Notes |
|---|---|---|
| Shine / glow / outline / dissolve / hologram on sprites and UI | **Sprite Shaders Ultimate** (paid, `Assets/Plugins/Sprite Shaders Ultimate`) | One family for `Image` (`GUI SSU`), `SpriteRenderer`, meshes, TMP. Check `Assets/` for it — Asset Store packages are not in `manifest.json`. Details: [../project-profiles/plain-ugui.md](../project-profiles/plain-ugui.md) |
| UI filters, transitions, gradients, blur (free) | **UIEffect** `com.coffee.ui-effect` | MIT. Register shader variants or it breaks in the build. |
| Particles inside a Canvas, coin attractors | **ParticleEffectForUGUI** `com.coffee.ui-particle` | No extra camera/RT. `UIParticleAttractor` = "coins fly to the counter". |
| Soft masks, tutorial spotlight cut-outs | **SoftMaskForUGUI** `com.coffee.softmask-for-ugui` | `MaskingShape` for "dim everything but this button". |
| Ready particle prefabs (hits, sparkles, confetti bursts) | **Epic Toon FX** (paid) or the project's own VFX pack | Re-parent under `UIParticle` for Canvas use; restyle colours to the palette. |
| Tweened feedback (punch, breathe, fade) | **DOTween** | Not a shader — often all a "glow" request needs. |

Before writing any effect shader, search the project for these, then the external reuse gate
([external-solution-reuse.md](external-solution-reuse.md)).

## 2. When a custom shader is the right call

A custom shader earns its place when the look is **data-driven and game-specific**: puzzle paths,
board cells, a progress fill with a special edge, a map fog. Proven recipe from a Flow-style puzzle
("neon paths"):

- **Encode state in a tiny texture, draw with one quad.** One texel per board cell: RGB = the path
  colour, alpha = a bit mask of connections (1 up, 2 right, 4 down, 8 left, 16 = endpoint dot).
  `RawImage` with `FilterMode.Point`, `TextureWrapMode.Clamp`; update with `SetPixels32` + `Apply`
  when the model changes. One draw call for the whole board instead of hundreds of `Image`s.
- **Shade by signed distance.** For each fragment, evaluate the segment SDF against the arms of the
  3×3 neighbourhood cells, union with `min` (a smooth-min for rounded inner corners), then build the
  look from the distance: a hot white core, the colour body, an exponential glow falloff. Cut the
  endpoint dot out of the line so the dot art stays on top.
- **Keep art where art is better.** Dots, frames and icons stay sprites; the shader only draws what
  changes every frame.
- **Iterate with the owner on screenshots.** A "better" physically-motivated tube shader was rejected
  as worse than the flat neon line — the reference game's look wins over technical ambition. Keep
  the previous version one toggle away until the owner approves.

## 3. Checklist for any UI shader or material

- **Mask support:** include `UNITY_UI_CLIP_RECT` + `_ClipRect` (for `RectMask2D`) and the stencil
  properties (`_Stencil`, `_StencilComp`, …) for `Mask`. Start from Unity's `UI/Default` source.
- **Vertex colour and alpha:** multiply by `IN.color` so `Graphic.color`, `CanvasGroup.alpha` and
  fades keep working.
- **`[PerRendererData] _MainTex`**, and do not assume UV 0..1 covers the sprite:
  - **Sprite atlases move a sprite into a sub-rect**, so an effect that uses UV as "position inside
    the sprite" (a shine sweep, a radial fill, an SDF dot) is squeezed or offset. Either pass the
    sprite's outer UV rect to the shader (`DataUtility.GetOuterUV(sprite)` → `_UVRect`, then
    `uv = (uv - rect.xy) / rect.zw`), or **exclude those sprites from atlases**.
  - Before creating atlases, list every `Image` whose material is not the default UI material, plus
    every graphic that receives a material at runtime (shine/attention components), and keep their
    sprites out of the atlases. Also exclude sprites swapped into those images at runtime
    (locked/unlocked banners).
- **Per-graphic material instances** (`new Material(shared)`) break batching and leak unless
  destroyed. Own them in one component: create on enable, restore the original and `Destroy` on
  disable/destroy. Never animate a shared material asset — every button using it will animate, and
  the edit persists into the asset in the editor.
- **Unscaled time** for anything shown on paused screens.
- **Builds:** keywords used only by materials created at runtime get stripped. Keep a material asset
  with each keyword combination referenced from a scene, or add the shader to *Always Included
  Shaders* / a preloaded `ShaderVariantCollection`. Verify in a device build, not only in Play Mode.
- **Mobile precision:** `half` for colour, `float` for UV and SDF distances (half-precision distances
  band visibly on large boards).

## 4. VFX verification

Effects must be captured across their lifetime (see
[playmode-qa-automation.md](playmode-qa-automation.md) "Effects and Feel"): freeze time at several
points, capture, compare against the reference. Check that the effect draws above the intended UI
(sibling order / nested Canvas `Override Sorting`), stops immediately when the page closes, and does
not leave particles on the next screen.
