# Unity MCP — usage recommendations

Unity MCP (plugin **MCP For Unity** + MCP server, sometimes referred to as `unity-mcp` / `mcp-for-unity`) — tools to control Unity Editor from Cursor.

Practical rule for this project:
- before any editor actions read `mcpforunity://custom-tools` (which tools are actually available),
- with multiple Unity instances read `mcpforunity://instances` and select active instance if needed.

---

## Key tools

| Category | Tools | Purpose |
|----------|-------|---------|
| **Resources** | `mcpforunity://editor/state`, `mcpforunity://editor/selection`, `mcpforunity://project/info`, `mcpforunity://instances`, `mcpforunity://custom-tools` | Read editor/project state, selection, instances, available tools |
| **Scene** | `manage_scene` | Create/load/save scenes, refresh assets |
| **Objects** | `manage_gameobject` | Create, delete, move, rename GameObject |
| **Components** | `manage_components` | Add/remove/configure components |
| **Prefabs** | `manage_prefabs` | Create and manage prefabs |
| **Scripts** | `manage_script`, `create_script`, `apply_text_edits`, `validate_script` | Create/edit C#, validate compilation |
| **Materials** | `manage_material` | Create and configure materials |
| **Console** | `read_console` | Read Unity logs |
| **Batch** | `batch_execute` | Multiple operations in one call |

---

## Common patterns

### After writing code

```
1. manage_scene → refresh assets (or validate_script)
2. read_console → check errors (during Play Mode — check console periodically during and after check).
3. If errors — fix → repeat
4. editor_state → verify objects in place
```

### Creating an object in scene

```
1. manage_gameobject → create (name, position)
2. manage_components → add (SpriteRenderer / Rigidbody / script)
3. editor_state → confirm object in hierarchy
4. manage_scene → action=save — save scene (required or changes are lost)
```

After any scene changes via MCP (objects, components, hierarchy) — **always save scene** (`manage_scene` action=save).

### Screenshot for DEV_STATE

```
1. manage_scene → screenshot (set screenshot_file_name). Final location — **only Docs/Screenshots/** (subfolders iter-01, iter-02, ...). If MCP saves elsewhere (e.g. Assets/Screenshots) — copy file to Docs/Screenshots/iter-NN/.
2. **Always review the screenshot** — open the image and check content. Agent must review every screenshot. Image must show expected (game in Play Mode, correct screen, UI). If not — do not consider task done; note discrepancy, retake screenshot or fix scene.
3. Update Docs/DEV_STATE.md — add link to screenshot (Docs/Screenshots/...).
```

**Anti-pattern:** take screenshot and report "implementation complete" without checking image. If the shot is empty or wrong view — the report is misleading.

### Batch operations (batch_execute)

When 3+ operations in a row — use `batch_execute` instead of separate calls. Faster and more reliable.

```
batch_execute:
  - manage_gameobject: create "Enemy"
  - manage_components: add SpriteRenderer to "Enemy"
  - manage_components: add Rigidbody2D to "Enemy"
  - manage_components: add BoxCollider2D to "Enemy"
```

---

## Usage by mode

### Prototype

- **Minimal MCP.** Main work via files.
- Refresh assets after code changes.
- `read_console` — only when something fails.
- Screenshot — **once at the end** for DEV_STATE (if used).
- `batch_execute` — not needed (few operations).

### Standard

- **Per feature (agent must self-check):**
  1. Write code → refresh assets.
  2. `read_console` → check errors.
  3. Start Play Mode → **during check** call `read_console` for errors → take screenshots of **game** (Game view), try to play (buttons, flow). After exiting Play Mode check console again.
  4. Screenshot to Docs/Screenshots → review content → add link in Docs/DEV_STATE.
- `manage_gameobject` / `manage_components` — for scene setup when faster via MCP than manually.
- `batch_execute` — when creating several objects at once.

### Fast

- **Refresh and console as you go** — do not wait for the end.
- `editor_state` — periodically, not after every small step.
- Screenshot — **at end of stage/block**, not after every feature.
- `manage_gameobject` / `manage_components` — use actively for speed.
- `batch_execute` — **recommended** (multiple features at once).

### Pro

- **Full MCP use every step:**
  1. Before task: `editor_state` → note initial state.
  2. After task: `read_console` + `editor_state` + screenshot.
  3. After feature: full check + screenshot for DEV_STATE.
- `validate_script` — after each edit (strict compile check).
- `batch_execute` — for complex ops (creating object systems).
- `manage_prefabs` — create prefabs immediately.
- `manage_material` — configure materials via MCP.

---

## When NOT to use MCP

- Editing `.cs` files — faster in Cursor directly (MCP for create/validate, not for editing large files).
- MCP server not running or unreachable — ask user to help set up or proceed without MCP (files/code). Do not block development.
- Simple single-file ops — MCP overhead not justified.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| MCP tools not visible in Cursor | Unity open? → Window → MCP for Unity → Start Server. Cursor: Settings → MCP → check status. |
| `read_console` empty | Refresh assets (manage_scene) — errors may appear after recompile. |
| Object created but not visible | `editor_state` → check position, scale, active. Camera looking at object? |
| batch_execute fails | Split into separate calls, find failing op. |
| `editor_state` says `ready_for_tools=false` / `stale_status` | Wait and re-read `mcpforunity://editor/state` (see `advice.recommended_retry_after_ms`). Optionally refresh (`refresh_unity`) and retry. |
