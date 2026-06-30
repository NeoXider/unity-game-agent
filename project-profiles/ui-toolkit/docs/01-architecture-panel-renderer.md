# 01 — UI Toolkit 6.5 architecture and PanelRenderer

## How it all fits together

```text
GameObject
└─ PanelRenderer
   ├─ Source Asset: MainMenu.uxml
   ├─ Panel Settings: RuntimePanelSettings.asset
   └─ runtime-created visual tree
      ├─ VisualElement .main-menu
      ├─ Button #play-button
      └─ Label #title-label
```

`PanelRenderer` is the bridge between the Unity scene and the UXML. It should not be your UI controller. It is responsible for loading the visual tree and rendering it through `PanelSettings`.

`PanelSettings` is responsible for:

- render mode: screen overlay or world-space;
- scale mode and reference resolution;
- sorting order;
- target texture;
- theme style sheet and text settings;
- dynamic atlas;
- buffer/vertex budget.

## Why not `Awake -> root.Q(...)`

In Unity 6.5 the visual tree can be created and recreated at times you don't expect. A reload happens on component creation, `PanelSettings` change, `VisualTreeAsset` change, component enable, and dirty-reload.

So the best lifecycle is:

```csharp
private void OnEnable()
{
    panelRenderer.RegisterUIReloadCallback(OnUIReload);
}

private void OnDisable()
{
    panelRenderer.UnregisterUIReloadCallback(OnUIReload);
    Unwire();
}

// Unity 6.5: RegisterUIReloadCallback has two overloads (see docs/08). This method's signature is
// (PanelRenderer, VisualElement) → the UIReloadCallback overload is chosen (2-arg, default).
private void OnUIReload(PanelRenderer renderer, VisualElement root)
{
    Unwire();
    CacheElements(root);
    WireEvents();
}
```

## Correct file roles

| File | Responsibility |
|---|---|
| `.uxml` | Structure, element names, template instances |
| `.uss` | Layout, spacing, colors, states, transitions, filters/materials |
| `Presenter.cs` | Find elements, subscribe to events, update state/classes |
| `Model.cs` | Domain data and rules |
| `PanelSettings.asset` | Render/scale/input/atlas settings |

## Presenter vs Controller vs ViewModel

For a game a simple Presenter is the most convenient:

```text
Game systems -> Presenter -> VisualElements
VisualElements events -> Presenter -> Game systems
```

The Presenter must not know how the button is drawn inside a template. It knows the public names: `#play-button`, `#settings-button`, `#volume-slider`.

## A paradigm-neutral base (any presenter on top of it)

The lifecycle (`RegisterUIReloadCallback`/`Unwire`/`Require`) is the same for every screen — factor it out once into a base `MonoBehaviour`, and the subclass implements only `BindUi` and `Unwire`. The base does **not** impose a paradigm: on it you build a "direct" screen (the subclass changes the UI/game itself) and a "passive view" for Clean Architecture (the subclass only exposes `event`/`Set*`, logic lives outside) exactly the same way.

```csharp
using System;
using UnityEngine;
using UnityEngine.UIElements;

[RequireComponent(typeof(PanelRenderer))]
public abstract class PanelViewBase : MonoBehaviour
{
    [SerializeField] protected PanelRenderer panelRenderer;
    protected VisualElement Root { get; private set; }

    protected virtual void Reset() => panelRenderer = GetComponent<PanelRenderer>();

    protected virtual void OnEnable()
    {
        if (panelRenderer == null) panelRenderer = GetComponent<PanelRenderer>();
        panelRenderer.RegisterUIReloadCallback(OnUIReload); // 2-arg overload (see docs/08)
    }

    protected virtual void OnDisable()
    {
        if (panelRenderer != null) panelRenderer.UnregisterUIReloadCallback(OnUIReload);
        Unwire();
        Root = null;
    }

    private void OnUIReload(PanelRenderer renderer, VisualElement root)
    {
        Unwire();        // idempotent: no duplicate subscriptions on any path
        Root = root;
        BindUi(root);    // Q<>() + subscriptions + initial state render
    }

    /// <summary>Find elements and subscribe. Called on EVERY reload.</summary>
    protected abstract void BindUi(VisualElement root);

    /// <summary>Remove subscriptions and clear the cache. Must be idempotent (null-safe).</summary>
    protected abstract void Unwire();

    protected static T Require<T>(VisualElement root, string name) where T : VisualElement
    {
        var e = root.Q<T>(name);
        if (e == null) throw new MissingReferenceException($"Missing #{name} ({typeof(T).Name})");
        return e;
    }
}
```

### Style A — "direct" (the subclass does everything)

```csharp
public sealed class PauseMenuView : PanelViewBase
{
    private Button resume;

    protected override void BindUi(VisualElement root)
    {
        resume = Require<Button>(root, "resume");
        resume.clicked += OnResume;
    }

    protected override void Unwire()
    {
        if (resume != null) resume.clicked -= OnResume;
        resume = null;
    }

    private void OnResume() => Time.timeScale = 1f; // change the game/UI right here
}
```

### Style B — passive view for Clean Architecture (logic outside)

The view doesn't know the domain: it exposes an `event` and receives data via `Set*`. Subscribe to a **method** (not a lambda), otherwise you can't unsubscribe in `Unwire`.

```csharp
public sealed class HudView : PanelViewBase
{
    public event Action HealClicked;

    private Button heal;
    private Label hp;
    private float lastHealth = 1f;          // cache: re-applied after reload

    protected override void BindUi(VisualElement root)
    {
        heal = Require<Button>(root, "heal");
        hp = Require<Label>(root, "hp");
        heal.clicked += RaiseHeal;
        ApplyHealth(lastHealth);            // the new tree immediately shows the current value
    }

    protected override void Unwire()
    {
        if (heal != null) heal.clicked -= RaiseHeal;
        heal = null; hp = null;
    }

    private void RaiseHeal() => HealClicked?.Invoke();

    public void SetHealth(float normalized)
    {
        lastHealth = Mathf.Clamp01(normalized);
        ApplyHealth(lastHealth);
    }

    private void ApplyHealth(float n)
    {
        if (hp == null) return;
        hp.text = $"{Mathf.RoundToInt(n * 100f)}%";
    }
}
```

The presenter is a plain class (no `MonoBehaviour`), lives in the application layer; how it is created and who provides `IHealthService` is the project's decision (composition root / DI / manual wiring) and is unrelated to UITK:

```csharp
public sealed class HudPresenter : IDisposable
{
    private readonly HudView view;
    private readonly IHealthService health;

    public HudPresenter(HudView view, IHealthService health)
    {
        this.view = view; this.health = health;
        view.HealClicked += health.Heal;        // view input → domain
        health.Changed += view.SetHealth;       // domain → view
        view.SetHealth(health.Normalized);
    }

    public void Dispose()
    {
        view.HealClicked -= health.Heal;
        health.Changed -= view.SetHealth;
    }
}
```

The same `HudView`, without a single edit, works both "directly" (someone calls `view.SetHealth(...)` /
`view.HealClicked`) and in Clean Architecture (through `HudPresenter`). The base is one — the paradigm is
chosen by the subclass and the assembly point.

## Component-view vs plain class (sub-view) — which should be which

A view **does not have to** be a `MonoBehaviour`. There are two kinds, and the kind is chosen by whether the element **owns its `PanelRenderer`**:

| What it is | C# type | Why |
|---|---|---|
| Root screen — on a GameObject with `PanelRenderer` | `MonoBehaviour : PanelViewBase` | owns the `PanelRenderer`, needs the reload-lifecycle, attached in the inspector |
| A page section / nested `ui:Instance` template / logical section | **plain class** (sub-view) | the sub-branch has no `PanelRenderer`; you can't put a `MonoBehaviour` on a `VisualElement`; the parent binds it |
| Reusable element with UXML attributes and its own behavior | custom `VisualElement` `[UxmlElement]` | it is a `VisualElement` itself, authored directly in UXML (`docs/02`) |

Default rule (the agent decides by it): **owns `PanelRenderer` → component; lives inside someone else's
visual tree / is a nested template → plain class.** Never put a `MonoBehaviour` on a sub-branch.

A sub-view is a plain class that the parent binds to a **sub-branch** of an already-loaded tree. It has no lifecycle of its own: the parent calls its `Bind(subRoot)` from its `BindUi` and `Unwire()` from its `Unwire`.

```csharp
// Sub-view: no MonoBehaviour and no PanelRenderer. Bound to a SUB-BRANCH.
public interface IUiSection
{
    void Bind(VisualElement sectionRoot); // Q<>() + subscriptions within its sub-branch
    void Unwire();                        // idempotent
}

public sealed class HudProgressSection : IUiSection
{
    private ProgressBar bar;
    private Label label;

    public void Bind(VisualElement root)
    {
        bar = root.Q<ProgressBar>("hud-progress-bar");
        label = root.Q<Label>("hud-progress-label");
    }

    public void Unwire() { bar = null; label = null; }

    public void SetProgress(float normalized)
    {
        if (bar == null) return;
        bar.value = Mathf.Clamp01(normalized) * 100f;
    }
}
```

The parent — the only component-view (one `PanelRenderer`) — composes the sections. This is the case of a page with nested `ui:Instance` templates (like `GameHudPanel.uxml` → `HudProgress`/`HudCrystals`):

```csharp
public sealed class GameHudView : PanelViewBase
{
    private readonly HudProgressSection progress = new();
    private readonly HudCrystalsSection crystals = new();

    protected override void BindUi(VisualElement root)
    {
        // sub-branches from nested ui:Instance: find by name/class and hand to the sub-view
        progress.Bind(root.Q<VisualElement>(className: "hud-progress-slot"));
        crystals.Bind(root.Q<VisualElement>(className: "hud-crystals-slot"));
    }

    protected override void Unwire()
    {
        progress.Unwire();
        crystals.Unwire();
    }

    public void SetProgress(float n) => progress.SetProgress(n);
}
```

Why so: a `PanelRenderer` is one per screen and owns the whole tree; nested templates are its sub-branches,
not separate panels. So sections are plain classes bound by the parent, and they automatically re-bind on
each reload (the parent hands them fresh sub-roots again in `BindUi`).

## Declare a screen's required fields in UXML, don't build a tree in C\#

All elements a screen needs (input fields, buttons, placeholder labels, section slots) are **declared in the
`.uxml` itself with `name`/`class`**, and C# only finds them by name and binds them — like in `CoreAiChat.uxml`
(`coreai-chat-input`, `coreai-chat-send`, header-title, scroll, typing-indicator) or settings panels. The
screen is self-describing: the designer sees the structure in UXML, not in code.

- Static values (text/tooltip/placeholder) are set as attributes in UXML.
- Values configurable from UXML for a section/control → custom control with `[UxmlAttribute]` or instance
  `AttributeOverrides` (`docs/02`).
- Don't build the main layout via `new VisualElement()` in C# — that's only for dynamic lists (`ListView`/pool,
  `docs/06`). If a field is "required", let UXML guarantee its presence and let `Require<T>()` in `BindUi`
  fail loudly if the element was forgotten.

## Multi-panel

Several `PanelRenderer`s can share one `PanelSettings`, but think about:

- sorting order;
- focus navigation;
- input routing;
- target display/texture;
- world-space overlap.

Tip: for most runtime projects make 1 screen-space panel for the global UI and separate world-space panels only where you really need UI in the scene.

## World Space UI

For world-space UI consider:

- physical dimensions in `PanelRenderer`;
- sorting layer/order or coupling with the render pipeline;
- event camera/raycast bridge;
- text scale and reference resolution;
- masks and filters can be more expensive on a large surface.

## Default prefab pattern

Create a prefab:

```text
UIRoot_RuntimePanel
├─ PanelRenderer
├─ MainMenuPresenter / HudPresenter / ScreenRouter
└─ Optional: AudioSource for UI sounds
```

Inspector:

```text
PanelRenderer.Source Asset = Assets/UI/Screens/MainMenu/MainMenu.uxml
PanelRenderer.Panel Settings = Assets/UI/RuntimePanelSettings.asset
```

Tip: keep `PanelSettings` separate from the scene so all screens share the same scale mode and atlas policy.

## Common mistakes

### 1. Duplicate subscriptions

Bad:

```csharp
private void OnUIReload(PanelRenderer r, VisualElement root)
{
    root.Q<Button>("play-button").clicked += OnPlayClicked;
}
```

Good:

```csharp
private void OnUIReload(PanelRenderer r, VisualElement root)
{
    Unwire();
    playButton = root.Q<Button>("play-button");
    playButton.clicked += OnPlayClicked;
}
```

### 2. References to old VisualElements

After a reload the old `Button` may no longer be part of the current visual tree. Treat any cached element as valid only until the next reload.

### 3. Logic inside a custom control instead of the Presenter

A custom control should encapsulate the element's local behavior. Screen flow, navigation, settings persistence, and scenes are the Presenter/Service.

## Documentation

- Panel Renderer component: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/panel-renderer-component.html
- Configure runtime UI: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-get-started-with-runtime-ui.html
- Create a panel: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-create-panel.html
- Panel Settings: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Panel-Settings.html
- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
