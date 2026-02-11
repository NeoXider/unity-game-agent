# Unity Editor — workflow recommendations

Recommendations for working effectively in Unity Editor when developing games with an AI agent.

---

## Key windows

| Window | Purpose | Shortcut |
|--------|---------|----------|
| **Scene** | Visual scene editing | — |
| **Game** | Game preview (Play Mode). **Aspect ratio** should match target (Docs/DEV_CONFIG: resolution, orientation). Do not leave Free Aspect if fixed resolution is set (e.g. 1920×1080). If MCP cannot set it — add manual check to checklist. | — |
| **Hierarchy** | Scene object tree | — |
| **Inspector** | Selected object properties | — |
| **Project** | Project files (Assets/) | — |
| **Console** | Logs, errors, warnings | Ctrl+Shift+C |
| **Profiler** | Performance analysis | Ctrl+7 |
| **Animation** | Animations and Animator | Ctrl+6 |

---

## Project setup

### First-time setup

- **Content structure (required):** create `Assets/_source/` and keep **all agent/user-created content** only there.  
  Reason: `Assets/` is usually cluttered with packages; `_source` gives stable paths and clear navigation.

  Recommended minimum:

  ```
  Assets/
    _source/
      Scripts/
      Editor/
      Data/        # ScriptableObject assets
      Prefabs/
      Scenes/
      Materials/
      Textures/
      Audio/
      UI/
      Resources/   # Unity Resources (if needed)
  ```

- **Player Settings** (Edit → Project Settings → Player): Company Name, Product Name, resolution, fullscreen, target platform.
- **Quality Settings** — quality levels.
- **Physics / Physics 2D** — gravity, Layer Collision Matrix.
- **Input System** — if using new Input System, install package and set Active Input Handling in Player Settings.
- **Tags & Layers** — add tags and layers for collision filtering.

### Scene structure

| Scene | Content |
|-------|---------|
| **MainMenu** | Menu UI, background, buttons |
| **Gameplay** | Game world, characters, camera, HUD |
| **Loading** | Loading screen (optional) |
| **Settings** | Settings screen (or overlay in Gameplay) |

Add all scenes to **Build Settings** (File → Build Settings → Add Open Scenes).

---

## Usage by mode

### Prototype

- **Minimal editor work:** one scene; create objects via code or MCP; Play Mode → check → stop; tune via SO in Inspector.
- **Do not touch:** Quality Settings, Profiler, complex settings.
- **Console:** only when errors occur.

### Standard

- **Standard workflow:** 2–3 scenes in Build Settings; prefabs for repeated objects; Inspector for SO tuning; Console after each feature; **Tags & Layers** for collisions.
- **Recommended:** organize Hierarchy with empty containers (`--- Environment ---`, `--- UI ---`, `--- Managers ---`).

### Fast

- **Practical workflow:** objects and components via MCP or code (whichever is faster); Play Mode — check periodically, not after every small change; prefabs when object repeats 3+ times; Console in background.
- **Batch:** several changes → one Play Mode check.

### Pro

- **Full editor use:** all scenes in Build Settings; prefix organization in Hierarchy; **Profiler** for performance (CPU: Update-heavy scripts; Memory: leaks, GC alloc; Rendering: draw calls, batching); **Frame Debugger**; **Physics Debugger**; custom Editor scripts for SO if needed; fix Warnings too, not only errors.

---

## Practices

### Hierarchy organization

```
--- Managers ---
  GameManager
  AudioManager
  UIManager
--- Environment ---
  Ground
  Platform_1
  Platform_2
--- Characters ---
  Player
  Enemy_1
--- UI ---
  UIDocument (UI Builder: UXML/USS)
    MainMenu / GameHUD / PauseMenu (separate UXML, switch via sourceAsset)
--- Cameras ---
  Main Camera
```

### Shortcuts (must-know)

| Action | Key |
|--------|-----|
| Play / Stop | Ctrl+P |
| Pause | Ctrl+Shift+P |
| Step | Ctrl+Alt+P |
| Duplicate object | Ctrl+D |
| Delete object | Delete |
| Focus on object | F (in Scene view) |
| Rename | F2 |
| Refresh Assets | Ctrl+R |
| Save scene | Ctrl+S |

### Play Mode tips

- **Changes in Play Mode are NOT saved!** You can tune SO in Play Mode for testing, but values reset. If you find good values — write them down and apply after exiting Play Mode.
- **Console during Play Mode:** check console (via MCP: `read_console`) for errors during and after the session. On errors — fix, exit Play Mode, fix, re-check.
- Use `[Header]` and `[Tooltip]` on SO for Inspector. Use `[Range(min, max)]` for sliders.

---

## Stage completion checklist

- [ ] Console clean (no errors, minimal warnings).
- [ ] Play Mode works (no crash).
- [ ] SO assets configured (not default values).
- [ ] **Scenes saved** — when using MCP call `manage_scene` action=save after scene changes; manually — Ctrl+S.
- [ ] All scenes in Build Settings.
- [ ] Screenshot in **Docs/Screenshots/** (iter-NN/), **reviewed by agent** — image shows expected (game in Play Mode, correct screen). If not — stage not complete.
- [ ] **Game view:** aspect/resolution per Docs/DEV_CONFIG (not Free Aspect if fixed). If MCP cannot change — check manually and note in report.
