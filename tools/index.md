# Tools and recommendations

Recommendations for using tools during Unity game development. Depth and frequency depend on the chosen [dev mode](../MODE_CHOICE.md).

---

## Tools overview

| Tool | Purpose | File |
|------|---------|------|
| **Unity MCP** | Control Unity Editor from Cursor: scene, objects, scripts, screenshots, console | [unity-mcp.md](unity-mcp.md) |
| **ComfyUI** | Visual asset generation: sprites, textures, backgrounds, icons | [comfyui.md](comfyui.md) |
| **Design refs** | UI reference source (screenshots/mockups/style guide; Figma export if available) | [ui-builder.md](ui-builder.md) |
| **Unity Editor** | Editor workflow: scenes, inspector, profiler, project settings | [unity-editor.md](unity-editor.md) |
| **UI Builder** | UI Toolkit path (UXML/USS) when selected by project/mode | [ui-builder.md](ui-builder.md) |
| **Architecture by mode** | Architecture levels, scene hierarchy template, when bootstrap/DI/ServiceLocator is acceptable | [architecture-by-mode.md](architecture-by-mode.md) |
| **C# / Code** | Code style: patterns, SO, async (UniTask), common packages, architecture — varies by mode | [code-writing.md](code-writing.md) |
| **Core mechanics** | Core mechanics (input, movement, health, combat) for reusability and quick iteration without full rewrites | [core-mechanics.md](core-mechanics.md) |
| **Libraries setup** | How to add UniTask, DOTween, Newtonsoft.Json, Unity Localization (UPM, Git URL, Asset Store) | [libraries-setup.md](libraries-setup.md) |
| **Bootstrap** | `setup_project.bat`: _source, Docs/*, DEV_*/ARCHITECTURE/UI_BRIEF (DEV_STATE with emoji), first iteration | Skill root: `setup_project.bat` |
| **Complete task** | `dev_complete_task.ps1`: append to DEV_LOG + update DEV_STATE (progress, "In progress" with emoji) | `scripts/dev_complete_task.ps1` |

---

## Bootstrap & doc auto-update

- **From scratch:** run `setup_project.bat` from skill folder (repo root = 3 levels up). Creates `Assets/_source`, `Docs/`, all templates (**DEV_STATE** with 🧭📈⚙️⏭️⚠️📸📊), `Docs/DEV_LOG/iteration-01-YYYYMMDD-HHMM.md`, `Docs/Screenshots/iter-01/`.
- **On task done:** `powershell -File .cursor\skills\unity-game-agent\scripts\dev_complete_task.ps1 -TaskTitle "Title" -Description "Done" -ProgressProject "2/10"` (optional: `-Files`, `-Result`, `-Screenshot`, `-NextTask`, `-NextTaskDesc`, `-DocsPath`). Updates current iteration file and **DEV_STATE.md**.

---

## Tool usage by mode

| Tool | Prototype | Standard | Fast | Pro | NoUI |
|------|-----------|----------|------|-----|------|
| **Unity MCP** | Batch: Play Mode + console + screenshot at stage end/before handoff | Per feature: state, Play Mode, screenshot, console | Per feature blocks: Play/console/screenshot + before handoff | Full: per task/feature, batch_execute + pre-handoff check | Per feature/block checks, no UI pipeline |
| **ComfyUI** | Not needed (placeholders) | Optional: sprites for final | Optional | Full: all assets via generation | Optional |
| **Design refs** | Minimal: 1–2 screen refs | Prefer: key screen mockups | Minimal: structure and target UX | Required: full UI kit/mockups | Not required by default |
| **Unity Editor** | Minimal: scene + Play | Standard: scene, inspector, Play | Standard | Full: profiler, analysis, settings | Standard |
| **UI Builder** | If UI Toolkit selected | If UI Toolkit selected | If UI Toolkit selected | If UI Toolkit selected | Skipped by default |
| **C# / Code** | Hardcode + SO | Moderate: components + SO | Components + SO | Architecture + SO + tests + interfaces | Components + SO, no UI tasks |
| **Core mechanics** | When laying core: SO + separate components | When extending: events, input/damage interfaces | Same | Full contracts (IInput, IDamageReceiver), Core game-agnostic | Primary focus |

---

## When to use a tool

> **Use a tool only if it speeds up the outcome in the current mode.** UI stack must follow project/mode policy (including `no_ui`). Do not skip autotests in Pro.

Details in each tool’s file.
