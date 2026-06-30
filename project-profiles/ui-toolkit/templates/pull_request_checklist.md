# UITK 6.5 Pull Request checklist

## Runtime lifecycle

- [ ] Uses `PanelRenderer` for new runtime UI.
- [ ] Uses `RegisterUIReloadCallback`.
- [ ] Unregisters callback on disable/destroy.
- [ ] Unwires button/value/pointer callbacks.
- [ ] No stale visual element references after reload.

## Structure

- [ ] UXML is structure-only.
- [ ] USS contains visual style and states.
- [ ] Presenter contains UI logic.
- [ ] No large inline styles.
- [ ] Names/classes follow convention.

## Templates/custom controls

- [ ] Templates use `AttributeOverrides` only for supported attributes.
- [ ] Custom controls have `[UxmlElement]`, `partial`, namespace.
- [ ] Public attributes are `[UxmlAttribute]`.
- [ ] Internal children not leaked unless intentional.

## Animation

- [ ] Transitions are explicit, not `all`.
- [ ] Transitions live on base class.
- [ ] Layout properties are not animated in hot paths.
- [ ] C# schedule/tween tasks are cancelled or allowed to finish safely.

## Shaders/filters

- [ ] Uses `-unity-material` for material effects.
- [ ] Uses `filter` for subtree post-effects.
- [ ] Filters are not applied to huge root without profiling.
- [ ] Material inheritance checked.

## Performance

- [ ] No per-frame `Q(...)`.
- [ ] No per-frame tree rebuild.
- [ ] Large lists use virtualization.
- [ ] Profiler markers checked if UI is complex.
