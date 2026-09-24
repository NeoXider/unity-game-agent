# Mobile build, texture size, and sprite atlases

Measured on a portrait casual game with 1290×2796 art: **APK 166 MB → 64 MB** from compression and
atlases alone, no art removed. Do this before the first build handed to the owner.

## 1. Measure first

List every texture with its runtime size on the active build target (switch to Android first):

```csharp
foreach (var g in AssetDatabase.FindAssets("t:Texture2D", new[] { "Assets/_source" })) {
    var p = AssetDatabase.GUIDToAssetPath(g);
    var t = AssetDatabase.LoadAssetAtPath<Texture2D>(p);
    long bytes = UnityEngine.Profiling.Profiler.GetRuntimeMemorySizeLong(t);
    // log bytes, t.width x t.height, t.format, importer max size / platform override
}
```

Sort by size. Any `RGBA32` / `RGB24` in the list is uncompressed and is the first target.

## 2. Why art ends up uncompressed: ETC2 needs multiples of 4

Designer art at phone resolution (1290×2796, 1289×2796, 1109×314 …) is not a multiple of 4. With
the default Android format (ETC2) such textures **silently fall back to RGBA32** — 32 bits per pixel,
13.8 MB for one full-screen background. In the measured project 187 of 224 textures were stored raw.

Fix with platform overrides (Android and iOS), not by resizing the art:

| Texture | Override |
|---|---|
| Full-screen backgrounds, map paintings (≥ 2000 px) | **ASTC 6×6** (3.56 bpp) |
| UI panels, cards, banners, sprite sheets | **ASTC 5×5** (5.12 bpp) |
| Small icons, dots, glyph-like art (≤ 256 px) | ASTC 4×4 (8 bpp) |

ASTC handles any size, keeps alpha, and is supported by every Android device that runs a Unity 6
game and by all iPhones since A8. Keep `maxTextureSize` at the value the art needs (≥ 2796 means
4096). Batch the importer changes inside `AssetDatabase.StartAssetEditing()` / `StopAssetEditing()`.

This is a size/memory task the owner asked for; unrequested normalisation of import settings a human
tuned is still forbidden (see SKILL.md guardrails).

## 3. Sprite atlases

Group small and medium UI sprites **per screen** (one atlas per sprite folder: Common, Gameplay,
Shop, Win …) so a page loads one texture and batches its draw calls.

- Check the packer mode first: `EditorSettings.spritePackerMode` — `AlwaysOnAtlas`/`BuildTimeAtlas`
  use V1 `.spriteatlas` (`SpriteAtlas` + `SpriteAtlasExtensions`), `SpriteAtlasV2` uses
  `.spriteatlasv2` (`SpriteAtlasAsset` + `SpriteAtlasImporter`). Do not mix.
- Packing for uGUI: **tight packing off, rotation off**, padding 4, alpha dilation on. Tight packing
  and rotation assume sprite meshes; `Image` draws the rect and shows neighbours' pixels.
- Add textures/sprites explicitly rather than whole folders when some sprites must stay out.
- **Keep out of atlases:** full-screen backgrounds and anything > ~1300 px (they just waste a page),
  multi-sprite sheets that are already 2048², and every sprite drawn with a custom material or a
  shader effect that reads UV as "position inside the sprite" (shine sweeps, SDF dots, radial
  fills) — list them from the scenes/prefabs and runtime material owners first. See
  [shaders-and-vfx.md](shaders-and-vfx.md) §3.
- Atlas platform settings: max 4096, ASTC 5×5 on Android/iOS. Pack
  (`SpriteAtlasUtility.PackAllAtlases(BuildTarget.Android)`) and read the page sizes back: a
  4096 page where 2048 would do means padding or a stray large sprite.
- First Play Mode after creating atlases packs them and can block the editor for a minute; MCP evals
  time out meanwhile — wait and retry, do not interrupt.

## 4. Player settings audit before a build

- Compare the editor's live values with git **before** saving anything: company, product name,
  bundle id, version, splash, icons. If they differ, the owner likely changed them in the editor —
  ask, never overwrite them from git.
- Active Input Handling: Input System only on mobile ([input-system.md](input-system.md)).
- Orientation matches the game (portrait-only games: auto-rotation off).
- Scenes in build: the loading/boot scene is index 0.
- Test assemblies excluded (`defineConstraints: ["UNITY_INCLUDE_TESTS"]`), unused plugins and demo
  content removed (a broken debug-console plugin threw on every editor start and was deleted).
- A release to a store needs a real keystore; a debug-signed APK is only for sideloading.

## 5. Building from automation

- `EditorUserBuildSettings.buildAppBundle = false` for an APK, `true` for an AAB.
- Builds take 3–15 minutes; poll the output file or the build status, and never read the full build
  report into context (it can be a megabyte) — extract result, size, errors, warnings.
- A build can re-dirty generated assets (TMP fallback font atlases). Revert those before committing.
- Report the APK path, size, result, and what was not tested on a device.

## 6. Pushing a repository with heavy QA evidence

Dozens of commits carrying full-resolution screenshots can exceed what the git host accepts in one
push (`HTTP 500`, `RPC failed`, "remote end hung up") even with a large `http.postBuffer`. Push in
batches of ~10 commits: `git push origin <sha>:refs/heads/<branch>` for successive SHAs, then the
branch. Keep QA screenshots compressed (JPEG crops) where possible.
