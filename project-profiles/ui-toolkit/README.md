# Project Profile: UI Toolkit (runtime, Unity 6.5 / PanelRenderer)

Use this profile when the project uses UI Toolkit, or when UI Toolkit is chosen for a new project
(the universal default UI stack). For **runtime** UI on Unity 6.5+ this profile targets the
**`PanelRenderer`** component (introduced in Unity 6.5 / 6000.5 as the evolution of `UIDocument`),
including USS transitions, custom `VisualElement` controls, USS filters, and `-unity-material` /
UI Shader Graph for per-element shader looks.

> Vendored from the standalone `uitk-6-5` skill (author: Neoxider, target Unity 6.5 / 6000.5). The
> deep `docs/` and `examples/` are kept in their original Russian prose with language-neutral code;
> this entry is the English router into them.

## Detection hints

- UXML/USS assets present; UI Toolkit runtime code in the project.
- Unity 6.5+: a `PanelRenderer` component on a GameObject (new runtime path).
- Unity 6.4 and earlier: a `UIDocument` component (legacy runtime path — keep using it on those versions).

## Mental model

```text
UXML          = screen structure
USS           = style, layout, states, transitions, filters, material
C# (Presenter)= behavior, events, data, lifecycle, procedural animation
PanelSettings = render mode, scale, sorting, atlas, target texture
PanelRenderer = component on a GameObject: loads UXML and renders the visual tree
```

On Unity 6.5 choose **`PanelRenderer`** for new runtime UI, not legacy `UIDocument`.

## Decision matrix (router into docs/)

| Task | Default choice | More |
|---|---|---|
| New runtime screen | `PanelRenderer + PanelSettings + UXML + USS + Presenter` | `docs/01` |
| Find/bind elements in C# | `RegisterUIReloadCallback` + cache + `Unwire()` | `docs/01`, `docs/03` |
| Base for any presenter (clean arch OR direct) | `PanelViewBase` + `BindUi`/`Unwire`; styles A/B | `docs/01` |
| View — component or plain class? | owns `PanelRenderer` → `MonoBehaviour`; page section / nested template → plain sub-view class | `docs/01` |
| Repeatable block without logic | UXML template + `Instance` + `AttributeOverrides` | `docs/02` |
| Repeatable block with logic/API | custom `VisualElement` + `[UxmlElement]`/`[UxmlAttribute]` | `docs/02` |
| hover/show/hide/selected | USS class (`is-open`…) + transition; C# only toggles the class | `docs/03`, `docs/04` |
| Sequences, realtime values | C# `schedule`/tween toggles classes | `docs/04` |
| Per-element shader look (hologram/dissolve) | UI Shader Graph material + `-unity-material` | `docs/05` |
| Post-effect over a subtree (blur/grayscale/swirl) | USS `filter` / custom filter | `docs/05` |
| 100+ rows (incl. varying height) | `ListView` (`makeItem`/`bindItem`; varying height → `virtualizationMethod = DynamicHeight`) | `docs/06` |
| Perf spike (Update*/DrawChain) | Profiler markers + checklist | `docs/06` |
| Unsure about an API signature | verify via reflection/docs before asserting | `docs/08` |

## Critical lifecycle rule (do not break)

`PanelRenderer` can recreate the visual tree, so **all** `Q<>()` queries and subscriptions go inside the
reload callback, not in `Awake`. Default to the 2-arg `UIReloadCallback` overload + an idempotent
`Unwire()`:

```csharp
private void OnEnable()  => panelRenderer.RegisterUIReloadCallback(OnReload);
private void OnDisable() { panelRenderer.UnregisterUIReloadCallback(OnReload); Unwire(); }

private void OnReload(PanelRenderer renderer, VisualElement root)
{
    Unwire();        // makes re-binding idempotent (no duplicate subscriptions)
    BindUi(root);    // Q<>() + subscriptions
}
```

Factor this lifecycle into a base class once (`PanelViewBase`); concrete presenters override only
`BindUi`/`Unwire`. Full skeleton and rationale: `docs/01` + `examples/runtime_panel_renderer/`.

## Scope: view layer only

The Presenter here is a View/Presenter, not a home for business logic. DI containers and event buses are
not part of UITK — the view exposes data/events via plain methods (`SetHealth(...)`, `event Action
PlayClicked`); how they're supplied is a project decision. Inside the view, prefer `VisualElement.schedule`
over `await` for delays/animation.

## Mandatory checks before custom code

- Verify existing UXML/USS structure can be extended; declare needed elements in UXML (`name`/`class`),
  don't build the main layout as a tree in C#.
- States via USS classes (`is-open`/`is-selected`/`is-disabled`), not inline styles.
- Animations don't touch layout (`width/height/top/left/flex`) without need; no `transition-property: all`.
- Custom controls: `[UxmlElement]`, `partial`, namespace, `[UxmlAttribute]`.
- `filter` (post-effect) vs `-unity-material` (mesh) — pick the right path.
- No per-frame `Q`, no mass element creation, callbacks unregistered.
- Verify a disputed API (`docs/08`) instead of trusting memory.
- Record the reuse decision in the plan/docs (Reuse Decision Matrix).

## docs/ map

(The matrix above cites docs by number — `docs/01` means the file below.)

- [docs/00-quick-decision-matrix.md](docs/00-quick-decision-matrix.md) — extended decision matrix and mini-glossary.
- [docs/01-architecture-panel-renderer.md](docs/01-architecture-panel-renderer.md) — `PanelRenderer` architecture, presenter skeleton, world-space, common mistakes.
- [docs/02-uxml-uss-templates-custom-controls.md](docs/02-uxml-uss-templates-custom-controls.md) — UXML/USS, templates, custom controls, `AttributeOverrides`.
- [docs/03-runtime-binding-events-input.md](docs/03-runtime-binding-events-input.md) — binding, events, input, reload lifecycle, state classes, screen router.
- [docs/04-animation-motion.md](docs/04-animation-motion.md) — animation: USS transitions, C# `schedule`/tween, `display:none` nuances.
- [docs/05-shaders-materials-filters.md](docs/05-shaders-materials-filters.md) — `-unity-material`, UI Shader Graph, built-in/custom USS filters.
- [docs/06-performance-debugging-gotchas.md](docs/06-performance-debugging-gotchas.md) — performance, Profiler markers, atlas, masks, `ListView`, pooling.
- [docs/07-agent-prompts-and-checklists.md](docs/07-agent-prompts-and-checklists.md) — agent answer templates and code-review checklists.
- [docs/08-verification.md](docs/08-verification.md) — API verification (reflection/tests) before asserting.
- [docs/references.md](docs/references.md) — links to official 6000.5 documentation.

`examples/` mirrors these topics (runtime_panel_renderer, custom_control, animations,
filters_and_shaders, performance); `templates/` holds agent task / screen spec / PR checklist templates.
