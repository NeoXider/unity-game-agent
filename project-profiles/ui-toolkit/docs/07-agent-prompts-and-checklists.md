# 07 — Agent instructions and checklists

## System setup for the agent

When writing Unity UI Toolkit 6.5 runtime UI:

1. Assume `PanelRenderer` unless the user says otherwise.
2. Don't use the old `UIDocument.rootVisualElement` in new runtime examples.
3. Always do reload-safe binding via `RegisterUIReloadCallback`.
4. Keep the UXML/USS/C# split.
5. Express states as classes, not scattered inline styles.
6. USS transitions are the default for visual state animation.
7. C# animation is only for the scenario, dynamic values, and complex synchronization.
8. For shaders, distinguish `-unity-material` from `filter`.
9. For large lists suggest `ListView`/virtualization.
10. **Before asserting an API signature or that a property exists — verify** (reflection via
    Unity MCP `unity_reflect`, the 6000.5 docs, or existing compiling project code). Don't rely on
    memory: e.g. `RegisterUIReloadCallback` has **two** overloads — the 2-arg `UIReloadCallback` and the
    3-arg `VersionedUIReloadCallback` with `int version`; both are valid.
11. End the answer with links to the official docs, but don't force the user to read docs for a basic implementation.

## Answer template for "build a screen"

```text
1. Short: architecture and files.
2. UXML.
3. USS.
4. Presenter C#.
5. How to wire PanelRenderer in the Inspector.
6. Best practices / gotchas.
7. Documentation.
```

## Answer template for "build a custom control"

```text
1. When this control is justified.
2. C# VisualElement with [UxmlElement] and [UxmlAttribute].
3. UXML usage with namespace.
4. USS styling.
5. Public API methods.
6. Limitations and performance.
7. Docs links.
```

## Answer template for "animation"

```text
1. Choice: USS or C#.
2. USS states/classes.
3. C# only toggles classes.
4. If needed — schedule/tween.
5. Performance notes: transform/opacity, no layout animation.
6. Docs links.
```

## Answer template for "shader/effect"

```text
1. Is it a material effect or a subtree post-effect?
2. If material: UI Shader Graph + -unity-material.
3. If post-effect: USS filter/custom filter.
4. USS example.
5. Shader/material setup checklist.
6. Performance caveats.
7. Docs links.
```

## Code review checklist

### Panel lifecycle

- [ ] `PanelRenderer` is used in runtime Unity 6.5.
- [ ] `RegisterUIReloadCallback` — the correct overload is chosen (2-arg `UIReloadCallback` by default; 3-arg `VersionedUIReloadCallback` only if dedup-by-version is needed).
- [ ] `UnregisterUIReloadCallback` is present (symmetric, same handler method).
- [ ] `Unwire()` removes callbacks and is called at the start of each reload (idempotency).
- [ ] The reload boilerplate is not duplicated in every screen (factored into a base class/binder).

### UXML/USS

- [ ] UXML doesn't contain much inline style.
- [ ] Elements have stable `name`s for C#.
- [ ] Classes are semantic.
- [ ] Templates don't try to override `class/name/style`.
- [ ] Custom controls have a namespace.

### Animations

- [ ] Transitions are set on the base class.
- [ ] No `transition-property: all`.
- [ ] An enter animation doesn't rely on `display: none` alone.
- [ ] Layout properties aren't animated in loops/large lists.

### Shaders/filters

- [ ] `-unity-material` isn't accidentally applied to all children.
- [ ] Filters aren't on a huge root without need.
- [ ] Filter transition functions match in type and order.
- [ ] A custom filter has margins if the effect extends beyond bounds.

### Performance

- [ ] No per-frame `Q(...)`.
- [ ] No mass element creation every frame.
- [ ] Lists are virtualized.
- [ ] Scheduled tasks don't linger after removal.
- [ ] Profiling markers checked for disputed spots.
