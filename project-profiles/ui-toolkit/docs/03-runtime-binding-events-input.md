# 03 — Runtime binding, events, input and reload lifecycle

## The main rule

`PanelRenderer` gives you `root` via `RegisterUIReloadCallback`. All elements must be found and subscribed inside that callback.

```csharp
panelRenderer.RegisterUIReloadCallback(OnUIReload);
```

The callback fires immediately if the UI already exists, and on each subsequent UI reload.

## Robust binding pattern

> In Unity 6.5 `RegisterUIReloadCallback` has **two overloads** (the compiler picks by the method
> signature): `UIReloadCallback` → `(PanelRenderer, VisualElement)` and `VersionedUIReloadCallback` →
> `(PanelRenderer, VisualElement, int version)`. By default take the 2-arg one + an idempotent `Unwire()`
> before each bind — that is more reliable than dedup-by-version (duplicate subscriptions are always
> excluded). The 3-arg `version` form is needed only if you explicitly want to skip re-binding on the
> same version. Unsure — verify via reflection (see `docs/08-verification.md`).

```csharp
private Button saveButton;
private SliderInt volumeSlider;
private bool wired;

private void OnUIReload(PanelRenderer renderer, VisualElement root)
{
    // Each reload may return a new visual tree, so the cache and subscriptions may be stale.
    // Unwire() makes re-binding idempotent (no duplicate handlers).
    Unwire();

    saveButton = root.Q<Button>("save-button");
    volumeSlider = root.Q<SliderInt>("volume-slider");

    Require(saveButton, "save-button");
    Require(volumeSlider, "volume-slider");

    saveButton.clicked += Save;
    volumeSlider.RegisterValueChangedCallback(OnVolumeChanged);

    wired = true;
}

private void Unwire()
{
    if (saveButton != null)
        saveButton.clicked -= Save;

    if (volumeSlider != null)
        volumeSlider.UnregisterValueChangedCallback(OnVolumeChanged);

    saveButton = null;
    volumeSlider = null;
    wired = false;
}

private static void Require(VisualElement element, string name)
{
    if (element == null)
        throw new MissingReferenceException($"Missing UI element #{name}");
}
```

## Events

### Click

```csharp
button.clicked += OnClicked;
button.clicked -= OnClicked;
```

### Value changed

```csharp
slider.RegisterValueChangedCallback(OnChanged);
slider.UnregisterValueChangedCallback(OnChanged);

private void OnChanged(ChangeEvent<float> evt)
{
    Debug.Log($"{evt.previousValue} -> {evt.newValue}");
}
```

### Pointer events

```csharp
element.RegisterCallback<PointerEnterEvent>(OnPointerEnter);
element.RegisterCallback<PointerLeaveEvent>(OnPointerLeave);
```

For simple hover prefer USS `:hover` over C#.

## State classes instead of manual styles

Bad:

```csharp
panel.style.display = DisplayStyle.Flex;
panel.style.opacity = 1;
panel.style.translate = new Translate(0, 0);
```

Good:

```csharp
panel.EnableInClassList("is-open", isOpen);
```

```css
.panel {
    display: none;
    opacity: 0;
}

.panel.is-open {
    display: flex;
    opacity: 1;
}
```

Important nuance: `display: none` removes the element from layout and can break an enter-transition. For an animated open it's often better to:

```css
.popup {
    visibility: hidden;
    opacity: 0;
    translate: 0 12px;
    transition-property: opacity, translate;
    transition-duration: 140ms, 180ms;
}

.popup.is-open {
    visibility: visible;
    opacity: 1;
    translate: 0 0;
}
```

And after close you can set `display: none` via C# schedule if you need to remove it from layout.

## Input system

Runtime UI Toolkit has an event system for active panels. If the project has uGUI/EventSystem or the new Input System, check:

- Project Settings → Player → Active Input Handling;
- presence of an EventSystem if you mix uGUI and UITK;
- `PanelRaycaster`/`PanelEventHandler` bridges for working together;
- focus may need a 1-frame delay when switching input manually.

## Screen router pattern

For multiple screens keep routing separate from the visual tree:

```csharp
public enum UiScreen
{
    MainMenu,
    Settings,
    Inventory
}

public sealed class ScreenRouter
{
    private readonly Dictionary<UiScreen, VisualElement> screens = new();

    public void Register(UiScreen id, VisualElement element)
    {
        screens[id] = element;
    }

    public void Show(UiScreen id)
    {
        foreach (var pair in screens)
            pair.Value.EnableInClassList("is-open", pair.Key == id);
    }
}
```

## Data binding: a practical approach

For gameplay UI an explicit update is often simpler:

```csharp
public void SetHealth(int current, int max)
{
    if (lastHealth == current && lastMaxHealth == max)
        return;

    lastHealth = current;
    lastMaxHealth = max;

    healthLabel.text = $"{current}/{max}";
    healthBar.value = max <= 0 ? 0 : (float)current / max;
}
```

For editor-like forms and settings you can use binding, but don't mix binding with `AttributeOverrides` as a data mechanism.

## Documentation

- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
- Runtime event system: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Event-System.html
- FAQ event/input: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-faq-event-and-input-system.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
