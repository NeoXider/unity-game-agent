# 01 — Архитектура UI Toolkit 6.5 и PanelRenderer

## Как всё устроено

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

`PanelRenderer` — bridge между сценой Unity и UXML. Он не должен быть твоим UI-controller. Он отвечает за загрузку visual tree и рендер через `PanelSettings`.

`PanelSettings` отвечает за:

- render mode: screen overlay или world-space;
- scale mode и reference resolution;
- sorting order;
- target texture;
- theme style sheet и text settings;
- dynamic atlas;
- buffer/vertex budget.

## Почему не `Awake -> root.Q(...)`

В Unity 6.5 visual tree может быть создан и пересоздан не тогда, когда ты ожидаешь. Reload происходит при создании компонента, изменении `PanelSettings`, изменении `VisualTreeAsset`, включении компонента и dirty-reload.

Поэтому лучший lifecycle такой:

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

// Unity 6.5: у RegisterUIReloadCallback два overload'а (см. docs/08). Этот метод имеет сигнатуру
// (PanelRenderer, VisualElement) → выбирается overload UIReloadCallback (2-арг, дефолт).
private void OnUIReload(PanelRenderer renderer, VisualElement root)
{
    Unwire();
    CacheElements(root);
    WireEvents();
}
```

## Правильные роли файлов

| Файл | Ответственность |
|---|---|
| `.uxml` | Структура, имена элементов, template instances |
| `.uss` | Layout, spacing, colors, states, transitions, filters/materials |
| `Presenter.cs` | Найти элементы, подписаться на события, обновлять state/classes |
| `Model.cs` | Данные и правила предметной области |
| `PanelSettings.asset` | Render/scale/input/atlas settings |

## Presenter vs Controller vs ViewModel

Для игры удобнее всего простой Presenter:

```text
Game systems -> Presenter -> VisualElements
VisualElements events -> Presenter -> Game systems
```

Presenter не должен знать, как именно нарисована кнопка внутри template. Он знает публичные имена: `#play-button`, `#settings-button`, `#volume-slider`.

## База, нейтральная к парадигме (любой презентер на ней)

Lifecycle (`RegisterUIReloadCallback`/`Unwire`/`Require`) одинаков у всех экранов — вынеси его один раз
в базовый `MonoBehaviour`, а наследник реализует только `BindUi` и `Unwire`. База **не навязывает**
парадигму: на ней одинаково делается и «прямой» экран (наследник сам меняет UI/игру), и «passive view»
для Clean Architecture (наследник только отдаёт `event`/`Set*`, логика снаружи).

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
        panelRenderer.RegisterUIReloadCallback(OnUIReload); // 2-арг overload (см. docs/08)
    }

    protected virtual void OnDisable()
    {
        if (panelRenderer != null) panelRenderer.UnregisterUIReloadCallback(OnUIReload);
        Unwire();
        Root = null;
    }

    private void OnUIReload(PanelRenderer renderer, VisualElement root)
    {
        Unwire();        // идемпотентно: дублей подписок нет ни на одном пути
        Root = root;
        BindUi(root);    // Q<>() + подписки + первичная отрисовка состояния
    }

    /// <summary>Найти элементы и подписаться. Вызывается на КАЖДЫЙ reload.</summary>
    protected abstract void BindUi(VisualElement root);

    /// <summary>Снять подписки и обнулить кэш. Должен быть идемпотентным (null-safe).</summary>
    protected abstract void Unwire();

    protected static T Require<T>(VisualElement root, string name) where T : VisualElement
    {
        var e = root.Q<T>(name);
        if (e == null) throw new MissingReferenceException($"Missing #{name} ({typeof(T).Name})");
        return e;
    }
}
```

### Способ A — «прямой» (наследник сам всё делает)

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

    private void OnResume() => Time.timeScale = 1f; // меняем игру/UI прямо здесь
}
```

### Способ B — passive view для Clean Architecture (логика снаружи)

View не знает домена: отдаёт `event` наружу и принимает данные через `Set*`. Подписку делай на
**метод** (не лямбду), иначе её нельзя снять в `Unwire`.

```csharp
public sealed class HudView : PanelViewBase
{
    public event Action HealClicked;

    private Button heal;
    private Label hp;
    private float lastHealth = 1f;          // кэш: переприменяем после reload

    protected override void BindUi(VisualElement root)
    {
        heal = Require<Button>(root, "heal");
        hp = Require<Label>(root, "hp");
        heal.clicked += RaiseHeal;
        ApplyHealth(lastHealth);            // новый tree сразу показывает актуальное значение
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

Презентер — обычный класс (без `MonoBehaviour`), живёт в application-слое; как его создают и кто даёт
`IHealthService` — решает проект (composition root / DI / ручная сборка), к UITK это не относится:

```csharp
public sealed class HudPresenter : IDisposable
{
    private readonly HudView view;
    private readonly IHealthService health;

    public HudPresenter(HudView view, IHealthService health)
    {
        this.view = view; this.health = health;
        view.HealClicked += health.Heal;        // ввод view → домен
        health.Changed += view.SetHealth;       // домен → view
        view.SetHealth(health.Normalized);
    }

    public void Dispose()
    {
        view.HealClicked -= health.Heal;
        health.Changed -= view.SetHealth;
    }
}
```

Тот же `HudView` без единой правки работает и «напрямую» (кто-то зовёт `view.SetHealth(...)` /
`view.HealClicked`), и в Clean Architecture (через `HudPresenter`). База одна — парадигму выбирает
наследник и точка сборки.

## Component-view vs обычный класс (sub-view) — кто чем должен быть

View **не обязана** быть `MonoBehaviour`. Есть два типа, и тип выбирается по тому, **владеет ли элемент
своим `PanelRenderer`**:

| Что это | Тип в C# | Почему |
|---|---|---|
| Корневой экран — на GameObject с `PanelRenderer` | `MonoBehaviour : PanelViewBase` | владеет `PanelRenderer`, нужен reload-lifecycle, вешается в инспекторе |
| Кусок страницы / вложенный `ui:Instance` темплейт / логическая секция | **обычный класс** (sub-view) | у под-ветки нет своего `PanelRenderer`; `MonoBehaviour` на `VisualElement` не повесить; его привязывает родитель |
| Переиспользуемый элемент с атрибутами из UXML и своим поведением | custom `VisualElement` `[UxmlElement]` | сам по себе `VisualElement`, авторится прямо в UXML (`docs/02`) |

Правило по умолчанию (агент решает по нему): **владеет `PanelRenderer` → компонент; живёт внутри чужого
visual tree / это вложенный темплейт → обычный класс.** Никогда не вешай `MonoBehaviour` на под-ветку.

Sub-view — обычный класс, который родитель привязывает к **под-ветке** уже загруженного дерева. Своего
lifecycle у него нет: родитель зовёт его `Bind(subRoot)` из своего `BindUi` и `Unwire()` из своего
`Unwire`.

```csharp
// Sub-view: без MonoBehaviour и без PanelRenderer. Привязывается к ПОД-ВЕТКЕ.
public interface IUiSection
{
    void Bind(VisualElement sectionRoot); // Q<>() + подписки в пределах своей под-ветки
    void Unwire();                        // идемпотентно
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

Родитель — единственный component-view (один `PanelRenderer`) — композирует секции. Это и есть кейс
страницы с вложенными `ui:Instance` темплейтами (как `GameHudPanel.uxml` → `HudProgress`/`HudCrystals`):

```csharp
public sealed class GameHudView : PanelViewBase
{
    private readonly HudProgressSection progress = new();
    private readonly HudCrystalsSection crystals = new();

    protected override void BindUi(VisualElement root)
    {
        // под-ветки от вложенных ui:Instance находим по name/class и отдаём sub-view
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

Почему так: `PanelRenderer` один на экран и владеет деревом целиком; вложенные темплейты — это его под-ветки,
а не отдельные панели. Поэтому секции — обычные классы, повязанные родителем, и они автоматически
переподвязываются на каждый reload (родитель в `BindUi` снова раздаёт им свежие под-корни).

## Необходимые поля экрана объявляй в UXML, а не строй деревом в C\#

Все элементы, которые экрану нужны (поля ввода, кнопки, плейсхолдеры-лейблы, слоты под секции),
**объявляются в самом `.uxml` с `name`/`class`**, а C# только находит их по имени и привязывает — как в
`CoreAiChat.uxml` (`coreai-chat-input`, `coreai-chat-send`, header-title, scroll, typing-indicator) или
settings-панелях. Экран самоописателен: дизайнер видит структуру в UXML, а не в коде.

- Статичные значения (text/tooltip/placeholder) задавай атрибутами в UXML.
- Настраиваемые из UXML значения секции/контрола → custom control с `[UxmlAttribute]` или
  `AttributeOverrides` инстанса (`docs/02`).
- Не строй основной layout через `new VisualElement()` в C# — это только для динамических списков
  (`ListView`/пул, `docs/06`). Если поле «обязательное» — пусть его наличие гарантирует UXML, а
  `Require<T>()` в `BindUi` упадёт явно, если элемент забыли.

## Multi-panel

Несколько `PanelRenderer` могут делить один `PanelSettings`, но думай о:

- sorting order;
- focus navigation;
- input routing;
- target display/texture;
- world-space overlap.

Лайфхак: для большинства runtime проектов делай 1 screen-space panel для глобального UI и отдельные world-space panels только там, где реально нужен UI в сцене.

## World Space UI

Для world-space UI учитывай:

- physical dimensions в `PanelRenderer`;
- sorting layer/order или сцепление с render pipeline;
- event camera/raycast bridge;
- масштаб текста и reference resolution;
- маски и фильтры могут быть дороже, если большая поверхность.

## Default prefab pattern

Создай prefab:

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

Лайфхак: храни `PanelSettings` отдельно от сцены, чтобы все экраны имели одинаковый scale mode и atlas policy.

## Частые ошибки

### 1. Дубли подписок

Плохо:

```csharp
private void OnUIReload(PanelRenderer r, VisualElement root)
{
    root.Q<Button>("play-button").clicked += OnPlayClicked;
}
```

Хорошо:

```csharp
private void OnUIReload(PanelRenderer r, VisualElement root)
{
    Unwire();
    playButton = root.Q<Button>("play-button");
    playButton.clicked += OnPlayClicked;
}
```

### 2. Ссылки на старые VisualElement

После reload старый `Button` может больше не быть частью текущего visual tree. Любой cached element нужно считать валидным только до следующего reload.

### 3. Логика внутри custom control вместо Presenter

Custom control должен инкапсулировать локальное поведение элемента. Screen flow, навигация, сохранение настроек и сцены — это Presenter/Service.

## Документация

- Panel Renderer component: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/panel-renderer-component.html
- Configure runtime UI: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-get-started-with-runtime-ui.html
- Create a panel: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-create-panel.html
- Panel Settings: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Panel-Settings.html
- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
