# 04 — Animation in UITK 6.5: USS, C#, schedule, what's best

## Short answer

For most UI animation use USS transitions. C# should toggle classes on/off. A C# tween/schedule is needed when the animation depends on game logic, sequencing, time, easing functions, or runtime values.

```text
USS = visual state animation
C#  = scenario/state orchestration
```

## Choice table

| Task | Best option | Example |
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

    // If the element was just created/added, give UITK one frame so it has a previous style.
    // Otherwise the transition may not start.
    toast.schedule.Execute(() => toast.AddToClassList("is-visible"));
}

public void HideToast()
{
    toast.RemoveFromClassList("is-visible");
}
```

## Important tip: put the transition on the base class

Bad:

```css
.button:hover {
    transition-property: scale;
    transition-duration: 120ms;
    scale: 1.04;
}
```

The transition back may not work as expected.

Good:

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

## Don't animate layout without reason

Best properties:

```css
opacity
translate
scale
rotate
```

Careful:

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

Why: layout properties trigger a layout recalculation. On a single popup that's fine; on a list of 200 elements it's painful.

## `display: none` and enter animation

`display: none` removes the element from the UI. It has no previous rendered state, so an enter transition breaks easily.

For a popup:

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

If you need to disable layout after close:

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

When USS isn't enough, use `schedule`. An opacity-tween example:

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

## Stagger animation via classes

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

Use transition events when you need cleanup after the animation:

```csharp
panel.RegisterCallback<TransitionEndEvent>(OnTransitionEnd);

private void OnTransitionEnd(TransitionEndEvent evt)
{
    if (evt.stylePropertyNames.Contains("opacity") && !panel.ClassListContains("is-open"))
        panel.style.display = DisplayStyle.None;
}
```

## Filter transitions

For filters the order and function types must match if you want a smooth transition.

Good:

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

Bad:

```css
.card { filter: blur(0px); }
.card.is-disabled { filter: grayscale(100%) blur(2px); }
```

## Documentation

- USS transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Transitions.html
- USS filter transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter-transitions.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
