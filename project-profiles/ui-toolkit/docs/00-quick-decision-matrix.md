# 00 — UITK 6.5 quick decision matrix

## What to choose

| Situation | Do | Don't | Tip |
|---|---|---|---|
| New runtime UI | `PanelRenderer` + `PanelSettings` | New code on `UIDocument` | Make a `UIRoot_PanelRenderer` prefab |
| Need to find elements in C# | Via `RegisterUIReloadCallback` | `Q` in `Awake` without reload handling | Reset cached references in `Unwire()` |
| Menu screen | UXML + USS + Presenter | Everything in C# | One Presenter per screen |
| HUD changes often | C# updates only changed fields | Recreate the whole root | Keep last-value and don't set the same text every frame |
| Repeatable card | UXML template or custom control | Copy-paste UXML 20 times | Template for looks, custom control for API/logic |
| Popup open/close | USS class `is-open` + transition | C# Update with alpha | Toggle the class after the first frame via `schedule` |
| Hover/selected/focus | USS pseudo-classes/classes | C# on every pointer event | Put the transition on the base class, not on `:hover` |
| Gameplay tween | C# `schedule` / tween wrapper | Complex logic via USS delays | Let USS own the visual, C# the scenario |
| Blur backdrop | USS filter `blur(...)` | Screenshot the scene manually | Don't blur a huge full-screen subtree without a profiler check |
| Hologram/dissolve | UI Shader Graph material + `-unity-material` | Custom filter if you only need a material look | Material is inherited by children — reset with `-unity-material: none` |
| Swirl/shockwave subtree | Custom USS filter | UI Shader Graph on every child | A custom filter works as a post-process over the subtree |
| 500-item inventory | `ListView` | 500 buttons by hand | Reuse the visual tree in `makeItem/bindItem` |
| Masks | `overflow: hidden`, stencil-aware | Many nested rounded masks | For a mask-heavy container check `UsageHints.MaskContainer` |
| Responsiveness | PanelSettings scale mode + USS flex | Hand pixels everywhere | Mobile reference resolution first, then desktop overrides |
| Debug UI | UI Toolkit Debugger + Profiler markers | Guess from code | Watch `UpdateStyle`, `UpdateLayout`, `DrawChain` |

---

## The most common correct pipeline

```text
1. UI Builder creates UXML/USS.
2. A GameObject gets a PanelRenderer.
3. PanelRenderer.Source Asset = screen.uxml.
4. PanelRenderer points to a Panel Settings.
5. Presenter subscribes via RegisterUIReloadCallback.
6. Presenter caches elements and callbacks.
7. States toggle via AddToClassList/EnableInClassList.
8. USS does transitions/filter/material look.
```

---

## Mini-glossary

| Term | Meaning |
|---|---|
| `VisualElement` | Lightweight retained-mode UI tree element |
| Visual tree | Hierarchy of `VisualElement`s built from UXML and C# |
| UXML | XML structure of the UI |
| USS | Unity Style Sheets: styles, flex, states, transitions, filters |
| Panel | Container that renders a visual tree |
| Panel Settings | Asset with render/scale/atlas/sorting settings |
| PanelRenderer | Component on a GameObject linking UXML + Panel Settings + Scene |
| Runtime binding | Data-to-UI link at runtime |
| Template | UXML file that can be instanced inside another UXML |
| AttributeOverrides | Override attributes inside a template instance |
| Custom control | A C# `VisualElement` class with UXML attributes |
| USS filter | Post-effect over an element and its children |
| `-unity-material` | Custom material on the UI element mesh |
