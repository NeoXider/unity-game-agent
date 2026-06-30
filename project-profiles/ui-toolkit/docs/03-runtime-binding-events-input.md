# 03 — Runtime binding, events, input и reload lifecycle

## Главное правило

`PanelRenderer` даёт тебе `root` через `RegisterUIReloadCallback`. Все элементы нужно искать и подписывать внутри этого callback.

```csharp
panelRenderer.RegisterUIReloadCallback(OnUIReload);
```

Callback вызывается сразу, если UI уже создан, и при следующих UI reload.

## Robust binding pattern

> В Unity 6.5 `RegisterUIReloadCallback` имеет **два overload'а** (компилятор выбирает по сигнатуре
> метода): `UIReloadCallback` → `(PanelRenderer, VisualElement)` и `VersionedUIReloadCallback` →
> `(PanelRenderer, VisualElement, int version)`. По умолчанию бери 2-арг + идемпотентный `Unwire()`
> перед каждой привязкой — это надёжнее dedup'а по version (дубли подписок исключены всегда).
> 3-арг с `version` нужен, только если хочешь явно пропускать повторную привязку при том же version.
> Сомневаешься — проверь рефлексией (см. `docs/08-verification.md`).

```csharp
private Button saveButton;
private SliderInt volumeSlider;
private bool wired;

private void OnUIReload(PanelRenderer renderer, VisualElement root)
{
    // Каждый reload может вернуть новый visual tree, поэтому кэш и подписки могли устареть.
    // Unwire() делает повторную привязку идемпотентной (без дублей обработчиков).
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

## События

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

Для simple hover чаще используй USS `:hover`, а не C#.

## State classes вместо ручных стилей

Плохо:

```csharp
panel.style.display = DisplayStyle.Flex;
panel.style.opacity = 1;
panel.style.translate = new Translate(0, 0);
```

Хорошо:

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

Важный нюанс: `display: none` убирает элемент из layout и может мешать enter-transition. Для animated open часто лучше:

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

А после close можно через C# schedule поставить `display: none`, если нужно убрать из layout.

## Input system

Runtime UI Toolkit имеет event system для активных panels. Если в проекте есть uGUI/EventSystem или новая Input System, проверь:

- Project Settings → Player → Active Input Handling;
- наличие EventSystem, если смешиваешь uGUI и UITK;
- `PanelRaycaster`/`PanelEventHandler` bridges для совместной работы;
- focus может требовать 1 frame delay при ручном переключении input.

## Screen router pattern

Для нескольких экранов держи routing отдельно от visual tree:

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

## Data binding: практичный подход

Для gameplay UI часто проще явный update:

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

Для editor-like forms и настроек можно использовать binding, но не смешивай binding с `AttributeOverrides` как механизмом данных.

## Документация

- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
- Runtime event system: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Event-System.html
- FAQ event/input: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-faq-event-and-input-system.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
