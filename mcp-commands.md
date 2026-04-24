# Unity MCP — Full Command Catalog

**Package:** `com.coplaydev.unity-mcp`  
**Install:** `https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity`  
**Version:** v9.6+ (beta)  
**Server:** Unity → Window → MCP for Unity → Start Server (localhost:8080)

---

## First Steps (every session)

```
1. Read mcpforunity://editor/state    → check Unity is ready
2. Read mcpforunity://custom-tools    → see available tools
3. Read mcpforunity://instances       → if multiple Unity instances, select one
4. Read mcpforunity://project/info    → project name, Unity version, packages
```

---

## Resources (read-only data)

| Resource URI | Returns |
|---|---|
| `mcpforunity://editor/state` | Editor state: play mode, scene, ready_for_tools, advice |
| `mcpforunity://editor/selection` | Currently selected objects |
| `mcpforunity://project/info` | Project name, Unity version, render pipeline, packages |
| `mcpforunity://instances` | Running Unity instances (for multi-instance routing) |
| `mcpforunity://custom-tools` | All available MCP tools for current session |
| `mcpforunity://cameras` | Scene cameras (including Cinemachine) |
| `mcpforunity://volumes` | Post-processing volumes |
| `mcpforunity://rendering_stats` | Draw calls, triangles, batching |
| `mcpforunity://renderer_features` | URP renderer feature list |

---

## Tools — Scene & Objects

### manage_scene
Control scenes: create, load, save, screenshot, play mode.

| Action | What it does |
|---|---|
| `save` | **Save current scene** (ALWAYS after changes) |
| `load` | Load scene by path |
| `create` | Create new scene |
| `screenshot` | Take screenshot (set `screenshot_file_name`) |
| `play` | Enter Play Mode |
| `stop` | Exit Play Mode |
| `pause` | Pause Play Mode |
| `refresh` | Refresh AssetDatabase |
| `additive_load` | Load scene additively |
| `close` | Close additively loaded scene |
| `set_active` | Set active scene (multi-scene) |
| `move_to_scene` | Move GO between scenes |
| `validate` | Validate scene (with auto-repair) |
| `create_from_template` | Create from template (3d_basic, 2d_basic, etc.) |

### manage_gameobject
CRUD for GameObjects.

| Action | What it does |
|---|---|
| `create` | Create GameObject (name, position, rotation, scale, parent) |
| `delete` | Delete by name or path |
| `move` | Set position/rotation/scale |
| `rename` | Rename |
| `set_parent` | Reparent |
| `set_active` | Enable/disable |
| `duplicate` | Duplicate |

### find_gameobjects
Find objects by name, tag, layer, component type. Returns hierarchy paths.

### manage_components
Add, remove, configure components.

| Action | What it does |
|---|---|
| `add` | Add component by type name |
| `remove` | Remove component |
| `configure` | Set component field values (serialized properties) |
| `get` | Read component data |

### manage_prefabs
Create and manage prefabs.

| Action | What it does |
|---|---|
| `create` | Create prefab from scene object |
| `instantiate` | Instantiate prefab in scene |
| `apply` | Apply overrides |
| `revert` | Revert to prefab state |

---

## Tools — Scripts & Code

### create_script
Create a new C# script file. Specify path and initial content.

### manage_script
Read, list, search scripts.

| Action | What it does |
|---|---|
| `read` | Read script content |
| `list` | List scripts in folder |
| `search` | Find scripts by pattern |

### apply_text_edits / script_apply_edits
Apply targeted text edits to existing scripts (find-replace with context).

### validate_script
Compile-check scripts. Returns errors/warnings without needing Play Mode.

### delete_script
Delete a script file.

### manage_script_capabilities
Query what script operations are available.

### find_in_file
Search inside files by text pattern.

---

## Tools — Materials & Graphics

### manage_material
Create and configure materials.

| Action | What it does |
|---|---|
| `create` | Create material with shader |
| `configure` | Set material properties (color, texture, float, etc.) |
| `list` | List materials |

### manage_shader
Inspect and manage shaders.

### manage_texture
Manage texture assets and import settings.

### manage_graphics (33 actions!)
Full rendering pipeline control.

| Action group | Examples |
|---|---|
| **Volume/Post-processing** | Create/configure volumes, add effects |
| **Light baking** | Bake lighting, configure lightmaps |
| **Rendering stats** | Get draw calls, triangles, batching info |
| **Pipeline settings** | Configure URP/HDRP settings |
| **Renderer features** | Add/configure URP renderer features |

### manage_vfx
Visual Effect Graph control.

---

## Tools — Physics

### manage_physics (21 actions!)
Full physics system control — 3D and 2D.

| Action group | Examples |
|---|---|
| **Settings** | Gravity, timestep, solver iterations |
| **Layer collision** | Get/set layer collision matrix |
| **Physics materials** | Create/configure physic materials |
| **Joints** | Create joints (Fixed, Hinge, Spring, Configurable, Character — 3D; Distance, Fixed, Friction, Hinge, Relative, Slider, Spring, Target, Wheel — 2D) |
| **Queries** | Raycast, raycast_all, linecast, shapecast, overlap |
| **Forces** | AddForce, AddTorque, AddExplosionForce |
| **Rigidbody** | Configure mass, drag, constraints |
| **Validation** | Scene-wide physics validation |
| **Simulation** | Edit-mode physics simulation |

---

## Tools — Animation & Camera

### manage_animation
Create and manage animations, animator controllers, animation clips.

### manage_camera
Camera control with Cinemachine support.

| Action | What it does |
|---|---|
| `configure` | Configure camera properties |
| `create_virtual` | Create Cinemachine virtual camera |
| `set_priority` | Set camera priority |
| `add_noise` | Add camera shake/noise |
| `configure_blending` | Set camera blending |
| `add_extension` | Add Cinemachine extensions |

---

## Tools — Editor & Workflow

### manage_editor
Editor control.

| Action | What it does |
|---|---|
| `undo` | Undo last operation |
| `redo` | Redo |
| `select` | Select object in editor |
| `focus` | Focus on object in Scene view |

### execute_menu_item
Execute any Unity menu item by path (e.g., `"Edit/Play"`, `"Assets/Refresh"`).

### refresh_unity
Force refresh AssetDatabase and recompile.

### read_console
Read Unity console logs (errors, warnings, info). **Critical for verification.**

### manage_tools
Toggle MCP tools on/off at runtime.

### set_active_instance
Select which Unity instance to control (multi-instance).

### debug_request_context
Debug MCP request context.

---

## Tools — Assets & Packages

### manage_asset
General asset management (import, move, rename, delete assets).

### manage_packages
Package Manager control.

| Action | What it does |
|---|---|
| `install` | Install package (UPM, git URL, local) |
| `remove` | Remove package (with dependency check) |
| `search` | Search registry |
| `list` | List installed packages |
| `add_registry` | Add scoped registry |

### manage_scriptable_object
Create and configure ScriptableObject assets.

---

## Tools — Build & Test

### manage_build
Build pipeline control.

| Action | What it does |
|---|---|
| `build` | Trigger player build |
| `switch_platform` | Switch build platform |
| `configure` | Configure player settings |
| `manage_scenes` | Add/remove scenes from build |
| `profiles` | Manage build profiles (Unity 6+) |
| `batch` | Multi-platform batch builds |

### run_tests
Run EditMode/PlayMode tests and get results.

### get_test_job
Poll async test job status.

---

## Tools — Reflection & Docs

### unity_reflect
Inspect live C# APIs via reflection — check class members, method signatures, inheritance.

### unity_docs
Fetch official Unity documentation (ScriptReference, Manual, package docs).

---

## Tools — Special

### manage_probuilder
ProBuilder mesh editing (create, modify geometry).

### manage_profiler (14 actions!)
Profiler control.

| Action group | Examples |
|---|---|
| **Session** | Start/stop profiling, get status, set areas |
| **Frame timing** | Read frame time, counters |
| **Memory** | Object memory queries, take/list/compare snapshots |
| **Frame Debugger** | Enable/disable, get draw events |

### manage_ui
UI Toolkit operations from editor.

### batch_execute
Execute multiple MCP operations in a single call. **Use when 3+ operations in a row.**

```json
{
  "operations": [
    {"tool": "manage_gameobject", "arguments": {"action": "create", "name": "Player", "position": {"x": 0, "y": 1, "z": 0}}},
    {"tool": "manage_components", "arguments": {"action": "add", "gameobject": "Player", "component": "Rigidbody"}},
    {"tool": "manage_components", "arguments": {"action": "add", "gameobject": "Player", "component": "CapsuleCollider"}}
  ]
}
```

### execute_custom_tool
Run project-specific custom tools registered via the MCP custom tool API.

### get_sha
Get file hash for change detection.

---

## Common Patterns

### After writing code
```
1. refresh_unity (or validate_script for quick check)
2. read_console → fix errors if any
3. manage_scene action=save
```

### Creating a complete game object
```
1. manage_gameobject action=create name="Enemy" position={...}
2. manage_components action=add component="SpriteRenderer"
3. manage_components action=add component="Rigidbody2D"
4. manage_components action=add component="BoxCollider2D"
5. manage_components action=add component="EnemyController" (your script)
6. manage_components action=configure component="EnemyController" fields={data: "EnemyData_Goblin"}
7. manage_scene action=save
```

### Full verification cycle
```
1. refresh_unity
2. read_console → must be clean
3. manage_scene action=play
4. read_console → check during play
5. manage_scene action=screenshot screenshot_file_name="check_feature_X"
6. read_console → check after play
7. manage_scene action=stop
8. Review screenshot → confirm visual correctness
```

### Setting up scene from scratch
```
batch_execute:
  - manage_scene action=create name="Gameplay"
  - manage_gameobject action=create name="--- Managers ---"
  - manage_gameobject action=create name="GameManager" parent="--- Managers ---"
  - manage_gameobject action=create name="--- Environment ---"
  - manage_gameobject action=create name="--- Characters ---"
  - manage_gameobject action=create name="Player" parent="--- Characters ---"
  - manage_components action=add gameobject="Player" component="Rigidbody2D"
  - manage_scene action=save
```

### Installing a package
```
manage_packages action=install package="com.cysharp.unitask" source="git" url="https://github.com/Cysharp/UniTask.git?path=src/UniTask/Assets/Plugins/UniTask"
```

### Running tests
```
1. run_tests mode="EditMode" filter="ShopManagerTests"
2. get_test_job id=<returned_id>  (poll until done)
3. Review results
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| Tools not visible | Unity open? Window → MCP for Unity → Start Server. Check Cursor MCP settings. |
| `read_console` empty | Run `refresh_unity` first — errors appear after recompile. |
| `ready_for_tools=false` | Wait and re-read `mcpforunity://editor/state` (check `advice.recommended_retry_after_ms`). |
| Object created but invisible | Check position, scale, camera. Use `find_gameobjects`. |
| `batch_execute` fails | Split into separate calls to find the failing operation. |
| Script compilation stuck | `refresh_unity` then `read_console`. |
