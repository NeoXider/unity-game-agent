# 00 — Быстрая матрица решений UITK 6.5

## Что выбирать

| Ситуация | Делай | Не делай | Лайфхак |
|---|---|---|---|
| Новый runtime UI | `PanelRenderer` + `PanelSettings` | Новый код на `UI Document` | Заведи prefab `UIRoot_PanelRenderer` |
| Нужно найти элементы в C# | Через `RegisterUIReloadCallback` | `Q` в `Awake` без проверки reload | Сбрасывай cached references в `Unwire()` |
| Экран меню | UXML + USS + Presenter | Всё в C# | Один Presenter на один экран |
| HUD меняется часто | C# обновляет только изменённые поля | Пересоздавать весь root | Храни last-value и не сетай тот же текст каждый frame |
| Повторяемая карточка | UXML template или custom control | Копипастить UXML 20 раз | Template — для вида, custom control — для API/логики |
| Popup open/close | USS class `is-open` + transition | C# Update с alpha | Переключай class после первого frame через `schedule` |
| Hover/selected/focus | USS псевдоклассы/classes | C# на каждый pointer event | Transition ставь на базовый class, не на `:hover` |
| Gameplay tween | C# `schedule` / tween wrapper | Сложная логика через USS delays | USS пусть отвечает за визуал, C# — за сценарий |
| Blur backdrop | USS filter `blur(...)` | Скриншот сцены вручную | Не blur-ь огромные full-screen subtree без проверки профайлера |
| Hologram/dissolve | UI Shader Graph material + `-unity-material` | Custom filter, если нужен только material look | Материал наследуется детьми — сбрасывай `-unity-material: none` |
| Swirl/shockwave subtree | Custom USS filter | UI Shader Graph на каждом child | Custom filter работает как post-process по subtree |
| 500 item inventory | `ListView` | 500 кнопок вручную | Reuse visual tree in `makeItem/bindItem` |
| Маски | `overflow: hidden`, stencil-aware | Много nested rounded masks | Для mask-heavy контейнера проверь `UsageHints.MaskContainer` |
| Адаптивность | PanelSettings scale mode + USS flex | Ручные пиксели везде | Сначала mobile reference resolution, потом desktop overrides |
| Debug UI | UI Toolkit Debugger + Profiler markers | Гадать по коду | Смотри `UpdateStyle`, `UpdateLayout`, `DrawChain` |

---

## Самый частый правильный pipeline

```text
1. UI Builder создаёт UXML/USS.
2. GameObject получает PanelRenderer.
3. PanelRenderer указывает Source Asset = экран.uxml.
4. PanelRenderer указывает Panel Settings.
5. Presenter подписывается через RegisterUIReloadCallback.
6. Presenter кэширует элементы и callbacks.
7. Состояния включаются через AddToClassList/EnableInClassList.
8. USS делает transitions/filter/material look.
```

---

## Мини-словарь

| Термин | Значение |
|---|---|
| `VisualElement` | Лёгкий retained-mode элемент UI tree |
| Visual tree | Иерархия `VisualElement`, созданная из UXML и C# |
| UXML | XML-структура UI |
| USS | Unity Style Sheets: стили, flex, states, transitions, filters |
| Panel | Контейнер, который рендерит visual tree |
| Panel Settings | Asset с настройками рендера, scale, atlas, sorting |
| PanelRenderer | Component на GameObject, связывает UXML + Panel Settings + Scene |
| Runtime binding | Связь данных и UI в runtime |
| Template | UXML-файл, который можно инстанцировать в другом UXML |
| AttributeOverrides | Переопределение атрибутов внутри template instance |
| Custom control | C# класс `VisualElement` с UXML-атрибутами |
| USS filter | Постэффект над элементом и его children |
| `-unity-material` | Custom material на UI element mesh |
