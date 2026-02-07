# UI Builder (UI Toolkit) — рекомендации

UI Builder — визуальный редактор UXML/USS для UI Toolkit. По скиллу **весь интерфейс делается только через UI Builder** (Canvas/uGUI не используются).

**Документация Unity (актуальная):**
- [UI Toolkit](https://docs.unity3d.com/Manual/UIElements.html) — введение, UXML, USS, события, runtime.
- [UI Builder](https://docs.unity3d.com/Manual/UIBuilder.html) — визуальный редактор UXML/USS.
- [Get started with UI Toolkit](https://docs.unity3d.com/Manual/UIE-simple-ui-toolkit-workflow.html) — быстрый старт.

---

## Когда использовать

- **Всегда:** UI делается **только** через UI Builder (UXML, USS, UIDocument). Canvas/uGUI не использовать.
- **Проверка:** Unity 2021.1+ — UI Builder встроен (Window → UI Toolkit → UI Builder); 2020.x / 2019.4 — пакет `com.unity.ui.builder`. Если окно открывается — использовать.

---

## Правила структуры

- **Один UXML на экран/панель — предпочтительно.** Отдельные файлы: MainMenu.uxml, GameHUD.uxml, SettingsPanel.uxml, ShopScreen.uxml и т.д. Переключение экранов — смена `sourceAsset` у UIDocument или показ/скрытие контейнеров.
- **Допустим один корневой UXML с панелями**, если экранов мало (3–5) и переключение частое: один Root.uxml с контейнерами (main-menu, game-panel, settings-panel…), видимость через класс `visible` и `display: none` / `flex`. Каждая логическая панель — отдельный дочерний контейнер с именем.
- **USS:** общие стили — в `common.uss`. Для каждого экранного UXML желательно свой USS (MainMenu.uxml → MainMenu.uss); для простых экранов или одного Root.uxml достаточно общего common.uss.
- **Повторяющиеся элементы** (кнопка с текстом/иконкой, карточка магазина, строка списка) — при необходимости выносить в отдельный UXML+USS и подключать как Template или клонировать из кода. В малых проектах допустимо дублировать разметку в одном UXML.

---

## Рекомендации

- **Изображения в UI:** в UI Builder для иконок, кнопок, фонов и прочих картинок **обычно использовать спрайты (Sprite)**, а не сырые текстуры (Texture2D). Спрайты дают корректные UV, поддержку slice/9-slice и лучше подходят для UI. Импорт текстур для UI — Texture Type: Sprite (2D and UI), **Sprite Mode: Single** (если не атлас; для атласа — Multiple).
- **Имена:** осмысленные имена элементам (name или class) для выборки из кода: `root.Q<Button>("play-button")`, `root.Q<Label>("money-label")`.
- **Данные и тексты:** по возможности из ScriptableObject (UiData и т.д.) — не хардкодить в UXML/USS то, что меняется по настройкам или локализации.
- **Рантайм:** UXML подключать к UIDocument; логику (клики, подписки) — в C# (MonoBehaviour или presenter), не в UXML.
- **Вёрстка:** Flex по умолчанию, при необходимости Absolute. Для адаптивности — % или flex-grow, не только жёсткие пиксели.

---

## Паттерны

- **Один UXML — один экран** либо **один Root.uxml с панелями** и переключение через `display` / класс `visible`.
- **Классы для вариантов:** общие стили через классы (.button-primary, .panel-modal), переиспользовать в разных экранах.
- **Q() и UQueryBuilder:** получать элементы по имени или классу; кэшировать ссылки при инициализации.
- **События:** подписываться на click/focus в C#, не вешать логику в UXML (кроме простых случаев по договорённости).

---

## Анти-паттерны

- **Не использовать Canvas/uGUI** — весь UI только через UI Builder (UIDocument + UXML/USS).
- **Не использовать сырые Texture2D для UI-картинок по умолчанию** — для иконок, кнопок, фонов в UI Builder обычно нужны спрайты (Sprite); текстуры импортировать как Sprite (2D and UI), Sprite Mode: Single (для атласа — Multiple).
- **Не смешивать все экраны в одном UXML без структуры** — если один файл, то чёткие контейнеры-панели с именами и переключением по display, а не «всё в куче».
- **Не оставлять сложный UXML без USS** — либо свой USS для экрана, либо стили в common.uss.
- **Не дублировать одни и те же стили** в каждом USS — выносить в общий USS.
- **Не хардкодить длинные тексты** в UXML — брать из SO или локализации.
- **Не искать элементы по индексу** в иерархии — давать имена/классы и искать по ним.

---

## Версии Unity

| Версия   | UI Builder |
|----------|------------|
| 2021.1+  | Встроен (Window → UI Toolkit → UI Builder) |
| 2020.x   | Пакет в Package Manager |
| 2019.4   | Пакет preview `com.unity.ui.builder` |

Если версия не поддерживает UI Builder — зафиксировать в DEV_STATE/AGENT_MEMORY причину.

---

## Связь с другими инструментами

- **Figma:** при включённом Figma макеты приходят из Figma; реализация в проекте — через UI Builder (UXML/USS).
- **MCP:** создание/правка UXML и USS через файлы (IDE); сцена, UIDocument — через Unity MCP при необходимости.
- **ScriptableObject:** тексты, цвета, размеры UI — из SO (UiData и т.д.), см. [code-writing.md](code-writing.md).
