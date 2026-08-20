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
| Runtime driver/input | scenario runner, input injection, UI automation, or custom QA tools |
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
| Gameplay/system in standard/pro | Play Mode run, console checked during play, declared runtime driver/tests executed, changed behavior verified |
| Pro mode | relevant tests when available |
| Build/platform/package/settings | lightweight build validation when practical |

If verification cannot run, report the exact missing capability or project limitation.

For interactive behavior, screenshot-only verification is not a pass. Use a PlayMode test, scenario runner, input injection, UI automation, custom MCP tool, or mark the result degraded and create an automation-gap task.

## Field-Tested Gotchas

Provider-agnostic Unity Editor automation traps (each verified in production):

| Symptom | Cause / fix |
|---|---|
| Screenshot shows scene but no UI | Camera-render screenshot paths skip Screen Space Overlay canvases → capture via code-execution capability: focus the Game View + `ScreenCapture.CaptureScreenshot` in the same call |
| Frames/screenshots frozen (`Time.frameCount` static) | `EditorApplication.isPaused == true` or editor lost OS focus → unpause via code, activate the Unity window |
| `onClick.Invoke()` does nothing | Handler implements `IPointerClickHandler` (0 persistent listeners) → simulate the click via `ExecuteEvents.Execute(...pointerClickHandler)` (recipe in [playmode-qa-automation.md](playmode-qa-automation.md)) |
| `GameObject.Find` returns null | Target is inactive → `transform.Find(path)` from an active root or `GetComponentInChildren<T>(true)` |
| Code-execution tool rejects valid-looking C# | Legacy compiler backends are C# 6: no string interpolation, no `using` in the body, qualify `UnityEngine.Object` explicitly |
| Relaunch after editor crash exits instantly | Stale `Temp/UnityLockfile` → delete it and relaunch |
| Mutation tool answers "cannot be used during play mode" | Editor is in Play Mode → read editor state first; edits applied in Play Mode are discarded on exit, and `SaveScene` is refused outright |
| Scene edit silently reverts | The scene was open and dirty in the editor while you patched the YAML on disk → check loaded scenes and `isDirty` before any file-level scene edit |
| Tracked files change without you touching them | A build or editor restart flipped `UnityConnectSettings` analytics `0 → 1`, cleared a TMP fallback list, changed `EditorSettings.m_EnterPlayModeOptions`, or dropped `.slnx`/`.vsconfig` → audit `git status` after every build/restart and revert what nobody asked for |
| Test assemblies end up in the player build | Missing `defineConstraints: ["UNITY_INCLUDE_TESTS"]` in the test asmdef |
| Code-execution call times out with no result | The eval channel has a hard timeout (≈30 s on common adapters) → never run a whole-project `AssetDatabase.FindAssets("t:Prefab")`/`t:Scene` sweep inside it; scope the search to a folder, page it, or grep the files on disk instead |
| Two `EventSystem` warnings that do not reproduce in a build | Two scenes are open additively in the editor → the build loads the scene in `Single` mode and has one. Check `list_open_scenes` before filing it as a defect |
| Property set on a prefab instance disappears after reload | Instance property edits need `PrefabUtility.RecordPrefabInstancePropertyModifications(component)`. Sibling-order changes made **inside the prefab asset** do propagate to instances on their own — reorder in the asset, do not patch each instance |

## Unity CLI / Batch Mode

Batch mode fails in ways that look like project defects:

- **`-quit` together with `-runTests` kills the run before the tests start.** Use `-runTests` with
  `-batchmode` and let the test runner exit on its own; add `-quit` only to non-test invocations.
- **A stale `Temp/UnityLockfile` from a crashed or still-open editor makes batch mode exit 1 with
  almost no output.** Before blaming the project: check for a running Unity process, then delete the
  lockfile and retry. Exit code 1 with an empty log is this, not a compile error.
- Always pass `-logFile -` (or a file you then read) — the default log location makes a failed batch
  run indistinguishable from a hung one.

## File-Only Fallback

If MCP is unavailable:

- First try manifest installation when the project is a Unity project and `auto_install_mcp_in_manifest` is enabled.
- Continue only with file-level work: scripts, docs, templates, config edits.
- Do not claim scene objects, component wiring, Play Mode, console, or screenshot verification happened.
- Tell the user what must be completed manually in Unity.
- Mark final status as degraded when Unity-side verification was required but unavailable.
