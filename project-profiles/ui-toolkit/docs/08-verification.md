# 08 — API verification and code checking

Skill rule: **don't assert a method signature, a property's existence, or API behavior from memory.**
UITK changes actively between Unity versions (especially `UIDocument` → `PanelRenderer` in 6.5), and
training data is often stale. Before writing or reviewing code — verify.

Trust order of sources (most reliable first):

1. **Reflection against the live editor** (if Unity MCP is connected) — reflects exactly the Unity version the user has.
2. **Compiling project code** — if the project builds, its signatures are correct for its Unity version.
3. **Official 6000.5 documentation** (`docs/references.md`).
4. Memory/training data — **only as a hypothesis**, requiring confirmation from 1–3.

## Verify via Unity MCP (reflection)

If Unity MCP is available (`mcp__UnityMCP__unity_reflect`):

```text
unity_reflect action=get_member
  class_name=UnityEngine.UIElements.PanelRenderer
  member_name=RegisterUIReloadCallback
```

This confirms the actual delegate type. As of Unity 6.5 the method has **two overloads** (verified by
reflection in a live 6000.5.0f1 editor):

```csharp
// overload 1 — delegate PanelRenderer.UIReloadCallback
public void RegisterUIReloadCallback(UIReloadCallback callback);
//   void Invoke(PanelRenderer panelRenderer, VisualElement rootElement)

// overload 2 — delegate PanelRenderer.VersionedUIReloadCallback
public void RegisterUIReloadCallback(VersionedUIReloadCallback callback);
//   void Invoke(PanelRenderer panelRenderer, VisualElement rootElement, int version)
```

The compiler picks the overload by your handler method's signature. By default — 2-arg
(`UIReloadCallback`) + an idempotent `Unwire()`. The 3-arg (`VersionedUIReloadCallback`) — if you really
need dedup "same `version` → skip re-binding".

> This point is a clear lesson from the skill itself: an early conclusion that "the 3-arg doesn't exist"
> was made from a single usage example in a project (which used the 2-arg overload) and turned out wrong.
> Reflection in the live editor showed both overloads. Always verify rather than extrapolate from one example.

Useful `PanelRenderer` properties (verify on the spot): `panelSettings`, `visualTree`,
`worldSpaceSize`, `worldSpaceSizeMode`. On `PanelSettings`: `renderMode` (`PanelRenderMode.WorldSpace`
/ overlay), scale mode, sorting order, dynamic atlas.

Other reflection actions:

```text
unity_reflect action=get_type   class_name=UnityEngine.UIElements.PanelSettings   # member list
unity_reflect action=search     query=PanelRenderer scope=unity                   # find a type
```

## Verify via the project itself

If the editor isn't running but the project builds — its code is the source of truth for its Unity version:

- find an existing call to the disputed API (`RegisterUIReloadCallback`, `worldSpaceSize`, …) in the
  codebase and look at the handler's actual signature;
- don't introduce a new pattern that contradicts what already compiles.

## Verify after writing code

1. Save/sync scripts, let domain reload finish.
2. Check the console for compile errors (Unity MCP `read_console`, filter by error) — **before** using the new types/components.
3. Run EditMode tests for UITK logic where it's covered (Unity MCP `run_tests`).
4. UI Toolkit Debugger — confirm the USS rule actually applied (see `docs/06`).

## Checklist "I didn't invent the API"

- [ ] Confirmed the method signature by reflection / docs / project code, not memory.
- [ ] The property/enum exists in the target Unity version (6000.5), not only in an older/newer one.
- [ ] No compile errors in the console after the change.
- [ ] Covered tests are green.

## Documentation

- Unity MCP (reflection/tests/console): tools `unity_reflect`, `run_tests`, `read_console`.
- Scripting API PanelRenderer: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.html
- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
