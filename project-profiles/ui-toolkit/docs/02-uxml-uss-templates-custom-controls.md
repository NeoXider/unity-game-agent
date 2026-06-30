# 02 — UXML, USS, templates и custom controls

## Базовое разделение

```text
UXML = что есть на экране
USS  = как выглядит и двигается
C#   = что происходит при действиях и данных
```

Простой экран:

```xml
<ui:UXML xmlns:ui="UnityEngine.UIElements">
    <Style src="MainMenu.uss" />

    <ui:VisualElement class="main-menu">
        <ui:Label name="title-label" class="main-menu__title" text="Victor" />
        <ui:Button name="play-button" class="main-menu__button" text="Играть" />
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

## Правила USS

- Стили — в classes, не в inline `style`.
- `name` используй для C# и rare instance overrides.
- Не делай длинные fragile selectors: `.root > .panel > .row > .label`.
- Не используй `transition-property: all`.
- Для states используй classes: `is-open`, `is-selected`, `is-warning`.

Хорошо:

```css
.quest-card {}
.quest-card__title {}
.quest-card.is-completed {}
```

Плохо:

```css
#Root > VisualElement > VisualElement > Label {}
```

---

## UXML templates

Используй template, когда нужен повторяемый визуальный блок без собственного C# API.

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
        <ui:AttributeOverrides element-name="card-title" text="Квест" />
        <ui:AttributeOverrides element-name="card-subtitle" text="Награда: 120 XP" />
        <ui:Label text="Поговорить с кузнецом" />
    </ui:Instance>
</ui:UXML>
```

`content-container` указывает, куда попадут children, вложенные внутрь `<Instance>`.

### Ограничения AttributeOverrides

`AttributeOverrides`:

- ищет элементы только по `element-name`;
- не использует USS selectors или UQuery;
- не может переопределить `class`, `name`, `style`;
- не подходит для data binding через overrides;
- shallow override в nested templates имеет приоритет.

Лайфхак: если нужно менять внешний вид instance, не пытайся override `style`; дай instance уникальное `name` или class вокруг и переопредели через USS.

```css
#quest-card > .card {
    border-left-width: 4px;
}
```

---

## Custom controls

Используй custom control, когда элемент имеет собственное состояние и API.

### Минимальный control

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

## Custom control с content container

Нужно, если custom control должен иметь внутреннюю рамку и принимать children из UXML.

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
<game:FramedBox title="Инвентарь">
    <ui:Label text="Меч" />
    <ui:Label text="Зелье" />
</game:FramedBox>
```

## Когда template, когда custom control

| Нужда | Template | Custom control |
|---|---:|---:|
| Быстро переиспользовать кусок UXML | ✅ | ⚠️ |
| Менять text/tooltip/value через UXML | ✅ | ✅ |
| Собственный C# API | ❌ | ✅ |
| Внутренние события | ⚠️ | ✅ |
| Сложное состояние | ❌ | ✅ |
| Дизайнерские вариации | ✅ | ✅ |
| Runtime-created элементы | ⚠️ | ✅ |

## Документация

- Reuse UXML files: https://docs.unity3d.com/6000.0/Documentation/Manual/UIE-reuse-uxml-files.html
- Custom controls attributes: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/custom-control-attributes-complex-data-types.html
- UXML elements upgrade notes: https://docs.unity3d.com/6000.5/Documentation/Manual/UpgradeGuide60.html
- USS common properties: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
