# 06 — Performance, debugging и частые ловушки

## Profiler markers

Смотри UI Toolkit markers:

| Marker | Что обычно значит |
|---|---|
| `UpdateStyle` | Часто меняются classes/styles или слишком сложные selectors |
| `UpdateLayout` | Меняются layout properties или дерево активно перестраивается |
| `UpdateAnimation` | Много transitions/animations |
| `UpdateRenderData` | Меняются mesh/visual data, текстуры, geometry |
| `DrawChain` | Стоимость подготовки/отрисовки UI |
| `UpdateRuntimeBindings` | Runtime binding много обновляет |
| `PickAll` | Pointer picking/event hit-testing |

## Проверочный порядок

1. Включи UI Toolkit Debugger.
2. Проверь, что нужный USS rule реально применяется.
3. Проверь specificity и inline styles.
4. В Profiler смотри spikes.
5. Если spike в `UpdateLayout`, ищи анимацию `width/height/flex/top/left`.
6. Если spike в `UpdateStyle`, ищи частое переключение classes на большом subtree.
7. Если spike в `UpdateRenderData`, проверь текстуры, текст, vector graphics, masks, material/filter.
8. Если spike в `DrawChain`, проверь batch breaks, nested masks, materials, filters.

## Dynamic atlas

Panel Settings содержит dynamic atlas настройки. UI Toolkit может собирать подходящие текстуры в atlas. Важные решения:

- большие текстуры могут не попадать в atlas из-за max subtexture size;
- много уникальных текстур может разбивать batches;
- sprites/vector images/backgrounds проверяй через Frame Debugger/Profiler;
- не дублируй одинаковые icons разными импорт-настройками без причины.

Лайфхак: если inventory icons 128x128, а atlas max subtexture слишком мал, они могут не атласиться. Проверь Panel Settings и profiler, прежде чем оптимизировать код.

## Маски

`overflow: hidden` может использоваться как masking. Rounded/arbitrary masks могут использовать stencil. Nested masks могут ломать batching и дорожать.

Правила:

- не вкладывай много rounded masks без нужды;
- для scroll/list clipping используй штатные элементы;
- для heavy mask container проверь `UsageHints.MaskContainer`;
- для корректных masks убедись, что depth/stencil buffers включены там, где это требуется.

## Filters

Filters могут создавать render texture pass для subtree. Это мощно, но не бесплатно.

Правила:

- blur только на нужном слое;
- не ставь filter на root всего UI без профайлера;
- не меняй filter каждый frame, если можно class transition;
- для multiple effects задавай один `filter:` declaration;
- для transitions держи одинаковый порядок filter functions.

## Materials/shaders

`-unity-material` может ломать batching, если у многих элементов разные material instances.

Правила:

- переиспользуй material assets;
- не создавай material instances per element без нужды;
- если меняешь shader param индивидуально, думай о последствиях для batching;
- проверяй, не наследуется ли material на children случайно.

## Списки и большое количество элементов

Плохо:

```csharp
foreach (var item in items)
{
    var row = template.Instantiate();
    list.Add(row);
}
```

для 1000 items.

Хорошо: `ListView` с `makeItem` и `bindItem`.

```csharp
listView.itemsSource = inventoryItems;
listView.makeItem = () => new Label();
listView.bindItem = (element, index) =>
{
    ((Label)element).text = inventoryItems[index].Name;
};
```

Лайфхак: в `bindItem` не подписывай callbacks без стратегии отписки. Лучше row control имеет method `Bind(item)` и внутри не накапливает обработчики.

### Строки разной высоты (variable-height rows)

`fixedItemHeight` работает только в режиме виртуализации `FixedHeight` (дефолт). Если строки разной
высоты (например, чат: одна строка vs 20 строк wrapped markdown), фиксированная высота режет/наслаивает
контент. Переключи метод виртуализации:

```csharp
listView.virtualizationMethod = CollectionVirtualizationMethod.DynamicHeight; // дефолт = FixedHeight
listView.itemsSource = messages;
listView.makeItem = () => new MessageRow();
listView.bindItem = (e, i) => ((MessageRow)e).Bind(messages[i]);
```

В `DynamicHeight` высота берётся из реального контента строки, `fixedItemHeight` не нужен (в этом режиме
он лишь начальная оценка). Проверено рефлексией в живом редакторе: свойство
`BaseVerticalCollectionView.virtualizationMethod` (тип `CollectionVirtualizationMethod`), enum-поля —
ровно `FixedHeight` и `DynamicHeight`. Цена: измерение каждой видимой строки чуть дороже, но при тысячах
items это всё равно несопоставимо дешевле, чем строить все элементы сразу.

## Pooling VisualElement

Unity не даёт универсальный встроенный pool для любого `VisualElement`. Если делаешь свой pool:

При возврате в pool обязательно:

- снять callbacks;
- очистить userData;
- сбросить classes state: `is-selected`, `is-warning`, etc.;
- сбросить inline styles;
- отменить scheduled tasks;
- убрать из parent;
- очистить binding/data references.

Иначе получишь “призрачные” клики, память и состояние от старого item.

## Text performance

- Не переписывай `label.text` каждый frame тем же значением.
- Для таймеров обновляй с разумной частотой, например 5–10 раз/сек, если не нужен frame-perfect.
- Длинный rich text и outline/shadow могут быть дороже.

## Selectors performance и maintainability

Лучше:

```css
.inventory__slot.is-selected {}
```

Хуже:

```css
.inventory > .panel > .scroll > .row:nth-child > .slot {}
```

UITK USS не CSS браузера полностью; меньше магии — стабильнее.

## Debug checklist для “почему стиль не работает”

1. Style sheet реально подключён к UXML?
2. Class/name на элементе совпадает?
3. Inline style перебивает USS?
4. `AttributeOverrides` пытается менять `style/class/name`? Так нельзя.
5. В UI Builder preview theme отличается от Panel Settings runtime theme?
6. Material наследуется от parent?
7. Filter declaration перетёрт другим class?
8. `display: none` мешает transition?
9. Элемент после reload старый, а ты меняешь не тот reference?

## Документация

- Profiler markers: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-profiler-markers.html
- Panel Settings / atlas: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Panel-Settings.html
- Dynamic atlas: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-control-textures-of-the-dynamic-atlas.html
- Masking: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-masking.html
- Managing elements best practices: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-best-practices-for-managing-elements.html
- Comparison of UI systems: https://docs.unity3d.com/6000.5/Documentation/Manual/UI-system-compare.html
