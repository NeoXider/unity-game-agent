# Agent task template — UITK 6.5

## Input

- Screen/effect name:
- Runtime or Editor UI:
- Screen-space or world-space:
- Needs animation:
- Needs shaders/filters:
- Needs templates/custom controls:
- Data source:

## Required output

1. Architecture summary.
2. UXML.
3. USS.
4. C# Presenter / custom control.
5. Inspector setup for PanelRenderer/PanelSettings.
6. Best practices and gotchas.
7. Official docs links.

## Constraints

- Use `PanelRenderer` for Unity 6.5 runtime UI.
- Use `RegisterUIReloadCallback`.
- Do not use `UIDocument.rootVisualElement` unless maintaining old code.
- Use USS classes for states.
- Prefer USS transitions for visual states.
- Avoid layout animation in performance-sensitive UI.
- Separate material shader effects from USS filters.
