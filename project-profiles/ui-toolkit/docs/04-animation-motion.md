# 04 — Анимации в UITK 6.5: USS, C#, schedule, что лучше

## Короткий ответ

Для большинства UI-анимаций используй USS transitions. C# должен включать/выключать классы. C# tween/schedule нужен, когда анимация зависит от логики игры, последовательности, времени, easing-функций или runtime значений.

```text
USS = visual state animation
C#  = scenario/state orchestration
```

## Таблица выбора

| Задача | Лучший вариант | Пример |
|---|---|---|
| Hover button | USS `:hover` + transition | scale/opacity |
| Popup open/close | C# toggles `is-open`, USS animates | opacity + translate |
| Selected item | `EnableInClassList("is-selected")` | background/tint |
| Health bar smooth | C# tween value/width cautiously | `schedule` |
| Damage flash | C# class + scheduled remove | `is-hit` 120ms |
| Tooltip delay | C# schedule + USS show | delay controlled by logic |
| Full sequence | C# coroutine/scheduler + classes | modal in → items stagger |
| Blur pause background | USS filter transition | blur/grayscale |
| Complex shader effect | material/filter param from C# | dissolve/swirl |

## USS transition pattern

```css
.toast {
    opacity: 0;
    translate: 0 16px;
    transition-property: opacity, translate;
    transition-duration: 120ms, 180ms;
    transition-timing-function: ease-out, ease-out;
}

.toast.is-visible {
    opacity: 1;
    translate: 0 0;
}
```

```csharp
private VisualElement toast;

public void ShowToast(string message)
{
    toast.Q<Label>("message").text = message;

    // Если элемент только что создан/добавлен, дай UITK один кадр,
    // чтобы был previous style. Иначе transition может не стартовать.
    toast.schedule.Execute(() => toast.AddToClassList("is-visible"));
}

public void HideToast()
{
    toast.RemoveFromClassList("is-visible");
}
```

## Важный лайфхак: transition на базовом class

Плохо:

```css
.button:hover {
    transition-property: scale;
    transition-duration: 120ms;
    scale: 1.04;
}
```

Переход назад может не сработать как ожидается.

Хорошо:

```css
.button {
    scale: 1;
    transition-property: scale;
    transition-duration: 120ms;
}

.button:hover {
    scale: 1.04;
}
```

## Не анимируй layout без причины

Лучшие свойства:

```css
opacity
translate
scale
rotate
```

Осторожно:

```css
width
height
left
top
margin
padding
flex-grow
flex-basis
```

Почему: layout-свойства вызывают layout recalculation. На одном popup это нормально, на списке из 200 элементов — боль.

## `display: none` и enter-анимация

`display: none` удаляет элемент из UI. У него нет previous rendered state, поэтому enter transition легко ломается.

Для popup:

```css
.popup {
    visibility: hidden;
    opacity: 0;
    translate: 0 12px;
    transition-property: opacity, translate;
    transition-duration: 120ms, 160ms;
}

.popup.is-open {
    visibility: visible;
    opacity: 1;
    translate: 0 0;
}
```

C#:

```csharp
public void Open()
{
    popup.AddToClassList("is-open");
}

public void Close()
{
    popup.RemoveFromClassList("is-open");
}
```

Если нужно после close отключить layout:

```csharp
public void CloseAndRemoveFromLayout()
{
    popup.RemoveFromClassList("is-open");
    popup.schedule.Execute(() => popup.style.display = DisplayStyle.None).StartingIn(180);
}

public void OpenFromLayout()
{
    popup.style.display = DisplayStyle.Flex;
    popup.schedule.Execute(() => popup.AddToClassList("is-open"));
}
```

## C# schedule tween

Когда USS не хватает, используй `schedule`. Пример tween opacity:

```csharp
using System;
using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Animation
{
    public static class UITween
    {
        public static IVisualElementScheduledItem TweenOpacity(
            this VisualElement element,
            float from,
            float to,
            int durationMs,
            Action onComplete = null)
        {
            var start = Time.realtimeSinceStartup;
            IVisualElementScheduledItem item = null;

            item = element.schedule.Execute(() =>
            {
                var elapsedMs = (Time.realtimeSinceStartup - start) * 1000f;
                var t = Mathf.Clamp01(elapsedMs / durationMs);
                var eased = 1f - Mathf.Pow(1f - t, 3f); // easeOutCubic

                element.style.opacity = Mathf.Lerp(from, to, eased);

                if (t >= 1f)
                {
                    item.Pause();
                    onComplete?.Invoke();
                }
            }).Every(16);

            return item;
        }
    }
}
```

Usage:

```csharp
panel.TweenOpacity(0f, 1f, 180);
```

## Stagger animation через classes

USS:

```css
.reward-row {
    opacity: 0;
    translate: 0 8px;
    transition-property: opacity, translate;
    transition-duration: 140ms, 180ms;
}

.reward-row.is-visible {
    opacity: 1;
    translate: 0 0;
}
```

C#:

```csharp
for (var i = 0; i < rows.Count; i++)
{
    var row = rows[i];
    row.RemoveFromClassList("is-visible");
    row.schedule.Execute(() => row.AddToClassList("is-visible")).StartingIn(i * 35);
}
```

## Transition events

Используй события transition, когда после анимации нужно сделать cleanup:

```csharp
panel.RegisterCallback<TransitionEndEvent>(OnTransitionEnd);

private void OnTransitionEnd(TransitionEndEvent evt)
{
    if (evt.stylePropertyNames.Contains("opacity") && !panel.ClassListContains("is-open"))
        panel.style.display = DisplayStyle.None;
}
```

## Filter transitions

Для filters порядок и типы функций должны совпадать, если хочешь плавный transition.

Хорошо:

```css
.card {
    filter: blur(0px) grayscale(0%);
    transition-property: filter;
    transition-duration: 220ms;
}

.card.is-disabled {
    filter: blur(2px) grayscale(100%);
}
```

Плохо:

```css
.card { filter: blur(0px); }
.card.is-disabled { filter: grayscale(100%) blur(2px); }
```

## Документация

- USS transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Transitions.html
- USS filter transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter-transitions.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
