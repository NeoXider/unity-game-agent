# ComfyUI — usage recommendations

ComfyUI MCP (`http://127.0.0.1:9000/mcp`) — visual asset generation: sprites, textures, backgrounds, UI icons.

---

## Prerequisites

- ComfyUI running (usually `:8188`).
- comfyui-mcp-server running on `:9000`.
- In `.cursor/mcp.json`: `"comfyui": { "url": "http://127.0.0.1:9000/mcp" }`.

---

## Typical workflow

```
1. Decide what is needed (sprite, background, icon)
2. Build prompt (description + style + size)
3. Call ComfyUI MCP
4. Check result
5. Save to Assets/Art/[subfolder]/
6. Set Import Settings in Unity (Sprite Mode, PPU, Filter Mode)
7. Refresh Assets via Unity MCP
```

---

## Prompt rules

### General

- **One style per project** — decide style at start and use same prefix for all prompts.
- **Be specific** — e.g. "knight in blue armor, side view, pixel art, 64x64" instead of "nice character".
- **Background** — for sprites/icons always specify `transparent background` (or a color).
- **Size** — explicit: `64x64`, `128x128`, `256x256`, `512x512`.

### Prompt templates

**Character sprite:**
```
[character description], [pose/view: side view / front view / idle pose],
[style: pixel art / cartoon / hand-drawn / low-poly],
[size: 64x64 / 128x128], transparent background
```

**Background / environment:**
```
[description: forest background / dungeon tileset / sky gradient],
[style], [seamless tileable] (if tile needed),
[size: 512x512 / 1920x1080], [palette: warm / cold / neon]
```

**UI icon:**
```
[description: sword icon / health potion / coin],
flat icon, simple, [style],
[size: 32x32 / 48x48 / 64x64], transparent background
```

**Tile set:**
```
tileset for [type: platformer / top-down RPG / dungeon],
[style], [content: grass, dirt, stone, water],
each tile [size: 32x32 / 64x64], transparent background
```

### Style prefixes (examples)

| Style       | Prompt prefix |
|------------|----------------|
| Pixel art  | `pixel art, retro, limited color palette, crisp edges` |
| Cartoon   | `cartoon style, bold outlines, vibrant colors, cel-shaded` |
| Minimal   | `minimalist, flat design, simple shapes, pastel colors` |
| Hand-drawn| `hand-drawn, sketch style, watercolor, organic lines` |
| Low-poly 3D | `low-poly 3D render, isometric, soft lighting, minimal textures` |

---

## Usage by mode

### Prototype

- **Not needed.** Use placeholders (colored quads, Unity primitives).
- Optional: 1–2 assets for mood.
- Do not spend time on style tuning.

### Standard

- **Optional.** Generate key assets: character sprite, basic enemies, background.
- Set style prefix at start — use for all assets.
- UI icons if time allows.
- **When:** after implementing a feature, before next (or separate “Art” stage).

### Fast

- **Optional.** If assets needed — generate in batch. Placeholders ok until final polish.
- First acceptable result = ok; no long iteration.

### Pro

- **Full use recommended.** All visual assets via generation.
- Define style guide at start: prompt prefix, color palette, sizes by asset type.
- Iterate: several variants, pick best. Separate “Art” stage in plan. Document prompts in DEV_STATE for regeneration.

---

## Import Settings in Unity

After saving asset to `Assets/Art/` — set:

| Parameter   | Sprite | Background | UI icon |
|------------|--------|------------|---------|
| Texture Type | Sprite (2D and UI) | Sprite or Default | Sprite (2D and UI) |
| Sprite Mode | Single | Single | Single |
| Pixels Per Unit | 64 (pixel art) / 100 | 100 | 100 |
| Filter Mode | Point (pixel art) / Bilinear | Bilinear | Bilinear |
| Compression | None (pixel art) / Normal | Normal | None |

---

## Fallback when unavailable

If ComfyUI is not running or not generating:

1. Use **placeholders** — colored sprites, Unity primitives (quad, circle).
2. Continue development — art does not block code.
3. Return to generation later when ComfyUI is available.
4. Note in DEV_STATE: “Art: placeholders, replace with generated when ready.”
