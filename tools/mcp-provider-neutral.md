# Provider-Neutral Unity MCP Workflow

Use this file when a Unity task can be driven through MCP, but the exact MCP server/tool names may differ. Treat CoplayDev/unity-mcp commands as one adapter, not as the only possible implementation.

## Capability Map

Map the active MCP server to these capabilities before acting:

| Capability | Needed for |
|---|---|
| Editor readiness | compile/import/domain reload state, blocking reasons |
| Instance routing | multiple Unity Editor instances |
| Scene control | active scene, load/create/save, Play Mode |
| Object graph | find/create/modify GameObjects and components |
| Asset operations | folders, prefabs, materials, ScriptableObjects |
| Script/file editing | create/edit scripts, snapshot/hash, validate |
| Console | baseline and post-change errors/warnings |
| Packages/project info | UI/input/render/test/build capability discovery |
| Camera/screenshot | visual verification |
| Tests/build | final verification for pro/build-impacting work |

If a capability is missing, do not fake the result. Use file-only fallback or report the skipped verification.

## Missing MCP Installation

If MCP is unavailable in a Unity project and `auto_install_mcp_in_manifest` is true:

```text
1. Verify the project root has Packages/manifest.json.
2. Read and parse manifest.json as JSON.
3. Add the active adapter dependency if it is missing.
4. Write manifest.json through a JSON-aware edit path; do not use blind string insertion.
5. Preserve existing dependencies and formatting as much as practical.
6. Do not manually edit Packages/packages-lock.json; Unity updates it during package resolution.
7. Let Unity resolve/import packages, then retry MCP detection.
8. Use file-only fallback only if install/resolve/retry fails or the user disabled MCP.
```

For the CoplayDev adapter, add:

```json
"com.coplaydev.unity-mcp": "https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity"
```

Do not add MCP to a non-Unity folder, a package subfolder, or a project without `Packages/manifest.json`.

## Mandatory Preflight

Run before Unity mutations when strict preflight is enabled.

```text
1. Identify active Unity Editor instance.
2. Read editor readiness and wait if compiling/importing/reloading.
3. Resolve target scene:
   - use active scene if the task targets it;
   - load/create/switch if the task clearly implies the target;
   - ask only if the target is ambiguous.
4. Read console baseline before changes.
5. Discover task-relevant capabilities and installed packages.
6. Classify state: READY, BUSY, BLOCKED, DEGRADED.
```

Classification:

| Status | Meaning | Action |
|---|---|---|
| READY | Tools are available, no blocking editor state | Proceed |
| BUSY | Compile/import/domain reload in progress | Wait and retry |
| BLOCKED | Ambiguous instance/scene or required capability missing | Resolve or ask |
| DEGRADED | Pre-existing errors or missing noncritical capability | Continue only if safe and report |

## C# Script Workflow

Use with any script-capable toolset:

```text
1. Snapshot file identity if supported: hash, SHA, timestamp, or version.
2. Prefer structured/semantic script edits.
3. Use text patch edits only when structured edits are unavailable.
4. Validate syntax/script structure when available.
5. Trigger or wait for Unity import/compile.
6. Poll readiness until compile/import/domain reload completes.
7. Compare console with baseline.
8. Fix new errors before using or attaching the script.
```

Never overwrite user edits after a stale snapshot. Re-read and merge.

## Scene And Visual Workflow

For visual changes:

```text
1. Locate target object(s) and camera/scene context.
2. Apply changes in the smallest batch that remains understandable.
3. Save the scene if scene state changed and the MCP supports saving.
4. Capture screenshot or equivalent visual output.
5. Review the image: nonblank, correct target, UI readable, expected mechanic visible.
6. Retake from scene view or positioned camera if the first capture is not useful.
```

Use screenshots for UI, camera, material, lighting, prefab, animation, VFX, and level layout changes when `visual_verification` is enabled.

## Final Verification

Before closing a task:

| Change type | Required verification |
|---|---|
| C# script | compile/import complete, no new console errors |
| Scene/prefab/material/UI/camera | screenshot reviewed, scene saved if modified |
| Gameplay/system in standard/pro | Play Mode run, console checked during play, changed behavior verified |
| Pro mode | relevant tests when available |
| Build/platform/package/settings | lightweight build validation when practical |

If verification cannot run, report the exact missing capability or project limitation.

## File-Only Fallback

If MCP is unavailable:

- First try manifest installation when the project is a Unity project and `auto_install_mcp_in_manifest` is enabled.
- Continue only with file-level work: scripts, docs, templates, config edits.
- Do not claim scene objects, component wiring, Play Mode, console, or screenshot verification happened.
- Tell the user what must be completed manually in Unity.
- Mark final status as degraded when Unity-side verification was required but unavailable.
