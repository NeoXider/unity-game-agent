# 08 — Верификация API и проверка кода

Правило skill: **не утверждай сигнатуру метода, наличие свойства или поведение API по памяти.**
UITK активно меняется между версиями Unity (особенно `UIDocument` → `PanelRenderer` в 6.5), и
тренировочные данные часто устаревшие. Прежде чем писать или ревьюить код — проверь.

Порядок доверия источникам (от самого надёжного):

1. **Рефлексия по живому редактору** (если подключён Unity MCP) — отражает ровно ту версию Unity,
   что стоит у пользователя.
2. **Компилирующийся код проекта** — если проект собирается, его сигнатуры верны для его версии Unity.
3. **Официальная документация 6000.5** (`docs/references.md`).
4. Память/тренировочные данные — **только как гипотеза**, требующая подтверждения 1–3.

## Проверка через Unity MCP (рефлексия)

Если доступен Unity MCP (`mcp__UnityMCP__unity_reflect`):

```text
unity_reflect action=get_member
  class_name=UnityEngine.UIElements.PanelRenderer
  member_name=RegisterUIReloadCallback
```

Так подтверждается реальный тип делегата. На момент Unity 6.5 у метода **два overload'а** (проверено
рефлексией в живом редакторе 6000.5.0f1):

```csharp
// overload 1 — делегат PanelRenderer.UIReloadCallback
public void RegisterUIReloadCallback(UIReloadCallback callback);
//   void Invoke(PanelRenderer panelRenderer, VisualElement rootElement)

// overload 2 — делегат PanelRenderer.VersionedUIReloadCallback
public void RegisterUIReloadCallback(VersionedUIReloadCallback callback);
//   void Invoke(PanelRenderer panelRenderer, VisualElement rootElement, int version)
```

Компилятор выбирает overload по сигнатуре твоего метода-обработчика. По умолчанию — 2-арг
(`UIReloadCallback`) + идемпотентный `Unwire()`. 3-арг (`VersionedUIReloadCallback`) — если реально
нужен dedup «тот же `version` → пропустить повторную привязку».

> Этот пункт — наглядный урок самого skill: ранний вывод «3-арг не существует» был сделан по
> единственному примеру использования в проекте (там брали 2-арг overload) и оказался неверным.
> Рефлексия в живом редакторе показала оба overload'а. Всегда проверяй, а не достраивай по одному примеру.

Полезные свойства `PanelRenderer` (проверяй по месту): `panelSettings`, `visualTree`,
`worldSpaceSize`, `worldSpaceSizeMode`. У `PanelSettings`: `renderMode` (`PanelRenderMode.WorldSpace`
/ overlay), scale mode, sorting order, dynamic atlas.

Прочие действия рефлексии:

```text
unity_reflect action=get_type   class_name=UnityEngine.UIElements.PanelSettings   # список членов
unity_reflect action=search     query=PanelRenderer scope=unity                   # найти тип
```

## Проверка через сам проект

Если редактор не запущен, а проект собирается — его код это источник истины для его версии Unity:

- найди существующий вызов спорного API (`RegisterUIReloadCallback`, `worldSpaceSize`, …) в кодовой
  базе и посмотри фактическую сигнатуру обработчика;
- не вводи новый паттерн, противоречащий тому, что уже компилируется.

## Проверка после написания кода

1. Сохрани/синкни скрипты, дай домен-релоаду пройти.
2. Проверь консоль на ошибки компиляции (Unity MCP `read_console`, фильтр по error) — **до** того, как
   использовать новые типы/компоненты.
3. Прогон EditMode-тестов на UITK-логику там, где она покрыта (Unity MCP `run_tests`).
4. UI Toolkit Debugger — убедиться, что USS-правило реально применилось (см. `docs/06`).

## Чеклист «я не выдумал API»

- [ ] Сигнатуру метода подтвердил рефлексией / доками / кодом проекта, не памятью.
- [ ] Свойство/enum существует в целевой версии Unity (6000.5), а не только в старой/новой.
- [ ] После правки нет ошибок компиляции в консоли.
- [ ] Покрытые тесты зелёные.

## Документация

- Unity MCP (рефлексия/тесты/консоль): инструменты `unity_reflect`, `run_tests`, `read_console`.
- Scripting API PanelRenderer: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.html
- RegisterUIReloadCallback: https://docs.unity3d.com/6000.5/Documentation/ScriptReference/UIElements.PanelRenderer.RegisterUIReloadCallback.html
