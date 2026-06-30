# 02 — UXML, USS, templates and custom controls

## Basic separation

```text
UXML = what is on the screen
USS  = how it looks and moves
C#   = what happens on actions and data
```

A simple screen:

```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <Style src="MainMenu.uss" />

    <ui:VisualElement class="main-menu">
        <ui:Label name="title-label" class="main-menu__title" text="Victor" />
        <ui:Button name="play-button" class="main-menu__button" text="Play" />
    </ui:VisualElement>
</ui:UXML>
```

```css
.main-menu {
    flex-grow: 1;
    align-items: center;
    justify-content: center;
}

.main-menu__title {
    font-size: 48px;
    margin-bottom: 24px;
}
```

## USS rules

- Styles go in classes, not in inline `style`.
- Use `name` for C# and rare instance overrides.
- Don't write long fragile selectors: `.root > .panel > .row > .label`.
- Don't use `transition-property: all`.
- For states use classes: `is-open`, `is-selected`, `is-warning`.

Good:

```css
.quest-card {}
.quest-card__title {}
.quest-card.is-completed {}
```

Bad:

```css
#Root > VisualElement > VisualElement > Label {}
```

---

## UXML templates

Use a template when you need a repeatable visual block without its own C# API.

### Template file: `CardTemplate.uxml`

```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <ui:VisualElement class="card">
        <ui:Label name="card-title" class="card__title" text="Default title" />
        <ui:Label name="card-subtitle" class="card__subtitle" text="Default subtitle" />
        <ui:VisualElement name="card-body" class="card__body" content-container="content" />
    </ui:VisualElement>
</ui:UXML>
```

### Usage file

```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <Style src="Cards.uss" />
    <ui:Template name="Card" src="CardTemplate.uxml" />

    <ui:Instance template="Card" name="quest-card">
        <ui:AttributeOverrides element-name="card-title" text="Quest" />
        <ui:AttributeOverrides element-name="card-subtitle" text="Reward: 120 XP" />
        <ui:Label text="Talk to the blacksmith" />
    </ui:Instance>
</ui:UXML>
```

`content-container` defines where children nested inside `<Instance>` will land.

### AttributeOverrides limitations

`AttributeOverrides`:

- finds elements only by `element-name`;
- doesn't use USS selectors or UQuery;
- can't override `class`, `name`, `style`;
- isn't suitable for data binding via overrides;
- a shallow override takes priority in nested templates.

Tip: if you need to change an instance's appearance, don't try to override `style`; give the instance a unique `name` or a wrapping class and override via USS.

```css
#quest-card > .card {
    border-left-width: 4px;
}
```

---

## Custom controls

Use a custom control when an element has its own state and API.

### Minimal control

```csharp
using UnityEngine;
using UnityEngine.UIElements;

namespace Game.UI.Controls
{
    [UxmlElement]
    public partial class StatBadge : VisualElement
    {
        private readonly Label titleLabel;
        private readonly Label valueLabel;
        private int value;
        private int warningBelow = 10;

        [UxmlAttribute]
        public string Title
        {
            get => titleLabel.text;
            set => titleLabel.text = value ?? string.Empty;
        }

        [UxmlAttribute]
        public int Value
        {
            get => value;
            set
            {
                this.value = value;
                valueLabel.text = value.ToString();
                RefreshState();
            }
        }

        [UxmlAttribute("warning-below")]
        public int WarningBelow
        {
            get => warningBelow;
            set
            {
                warningBelow = value;
                RefreshState();
            }
        }

        public StatBadge()
        {
            AddToClassList("stat-badge");

            titleLabel = new Label { name = "stat-title" };
            titleLabel.AddToClassList("stat-badge__title");

            valueLabel = new Label { name = "stat-value" };
            valueLabel.AddToClassList("stat-badge__value");

            Add(titleLabel);
            Add(valueLabel);

            Title = "Stat";
            Value = 0;
        }

        private void RefreshState()
        {
            EnableInClassList("is-warning", value <= warningBelow);
        }
    }
}
```

### UXML usage

```xml
<ui:UXML
    xmlns:ui="UnityEngine.UIElements"
    xmlns:game="Game.UI.Controls">

    <game:StatBadge title="HP" value="8" warning-below="10" />
    <game:StatBadge title="Mana" value="42" warning-below="5" />
</ui:UXML>
```

### USS

```css
.stat-badge {
    flex-direction: row;
    align-items: center;
    padding: 6px 10px;
    border-radius: 8px;
}

.stat-badge__title {
    opacity: 0.7;
    margin-right: 8px;
}

.stat-badge__value {
    font-size: 18px;
}

.stat-badge.is-warning {
    background-color: rgba(160, 40, 40, 0.35);
}
```

## Custom control with a content container

Needed when a custom control should have an inner frame and accept children from UXML.

```csharp
using UnityEngine.UIElements;

namespace Game.UI.Controls
{
    [UxmlElement]
    public partial class FramedBox : VisualElement
    {
        private readonly VisualElement header;
        private readonly VisualElement body;
        private readonly Label titleLabel;

        public override VisualElement contentContainer => body;

        [UxmlAttribute]
        public string Title
        {
            get => titleLabel.text;
            set => titleLabel.text = value ?? string.Empty;
        }

        public FramedBox()
        {
            AddToClassList("framed-box");

            header = new VisualElement { name = "header" };
            header.AddToClassList("framed-box__header");

            titleLabel = new Label { name = "title" };
            titleLabel.AddToClassList("framed-box__title");
            header.Add(titleLabel);

            body = new VisualElement { name = "body" };
            body.AddToClassList("framed-box__body");

            hierarchy.Add(header);
            hierarchy.Add(body);
        }
    }
}
```

Usage:

```xml
<game:FramedBox title="Inventory">
    <ui:Label text="Sword" />
    <ui:Label text="Potion" />
</game:FramedBox>
```

## When a template, when a custom control

| Need | Template | Custom control |
|---|---:|---:|
| Quickly reuse a chunk of UXML | ✅ | ⚠️ |
| Change text/tooltip/value via UXML | ✅ | ✅ |
| Own C# API | ❌ | ✅ |
| Internal events | ⚠️ | ✅ |
| Complex state | ❌ | ✅ |
| Designer variations | ✅ | ✅ |
| Runtime-created elements | ⚠️ | ✅ |

## Documentation

- Reuse UXML files: https://docs.unity3d.com/6000.0/Documentation/Manual/UIE-reuse-uxml-files.html
- Custom controls attributes: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/custom-control-attributes-complex-data-types.html
- UXML elements upgrade notes: https://docs.unity3d.com/6000.5/Documentation/Manual/UpgradeGuide60.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
