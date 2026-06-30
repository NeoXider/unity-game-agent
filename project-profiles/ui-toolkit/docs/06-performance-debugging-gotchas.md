# 06 — Performance, debugging and common gotchas

## Profiler markers

Watch the UI Toolkit markers:

| Marker | What it usually means |
|---|---|
| `UpdateStyle` | Classes/styles change often, or selectors are too complex |
| `UpdateLayout` | Layout properties change, or the tree is actively rebuilt |
| `UpdateAnimation` | Many transitions/animations |
| `UpdateRenderData` | Mesh/visual data, textures, or geometry change |
| `DrawChain` | Cost of preparing/drawing the UI |
| `UpdateRuntimeBindings` | Runtime binding updates a lot |
| `PickAll` | Pointer picking / event hit-testing |

## Verification order

1. Enable the UI Toolkit Debugger.
2. Check that the intended USS rule is actually applied.
3. Check specificity and inline styles.
4. In the Profiler look for spikes.
5. If the spike is in `UpdateLayout`, look for animating `width/height/flex/top/left`.
6. If the spike is in `UpdateStyle`, look for frequent class toggling on a large subtree.
7. If the spike is in `UpdateRenderData`, check textures, text, vector graphics, masks, material/filter.
8. If the spike is in `DrawChain`, check batch breaks, nested masks, materials, filters.

## Dynamic atlas

Panel Settings holds dynamic atlas settings. UI Toolkit can collect suitable textures into an atlas. Key decisions:

- large textures may not fit the atlas due to max subtexture size;
- many unique textures can break batches;
- check sprites/vector images/backgrounds via Frame Debugger/Profiler;
- don't duplicate identical icons with different import settings without reason.

Tip: if inventory icons are 128x128 but the atlas max subtexture is too small, they may not be atlased. Check Panel Settings and the profiler before optimizing code.

## Masks

`overflow: hidden` can be used as masking. Rounded/arbitrary masks may use stencil. Nested masks can break batching and get expensive.

Rules:

- don't nest many rounded masks without need;
- for scroll/list clipping use the built-in elements;
- for a heavy mask container check `UsageHints.MaskContainer`;
- for correct masks make sure depth/stencil buffers are enabled where required.

## Filters

Filters can create a render-texture pass for a subtree. Powerful, but not free.

Rules:

- blur only on the needed layer;
- don't put a filter on the root of the whole UI without a profiler;
- don't change the filter every frame if a class transition will do;
- for multiple effects set a single `filter:` declaration;
- for transitions keep the same order of filter functions.

## Materials/shaders

`-unity-material` can break batching if many elements have different material instances.

Rules:

- reuse material assets;
- don't create per-element material instances without need;
- if you change a shader param individually, consider the batching consequences;
- check whether the material is accidentally inherited by children.

## Lists and large element counts

Bad:

```csharp
foreach (var item in items)
{
    var row = template.Instantiate();
    list.Add(row);
}
```

for 1000 items.

Good: `ListView` with `makeItem` and `bindItem`.

```csharp
listView.itemsSource = inventoryItems;
listView.makeItem = () => new Label();
listView.bindItem = (element, index) =>
{
    ((Label)element).text = inventoryItems[index].Name;
};
```

Tip: in `bindItem` don't subscribe callbacks without an unsubscription strategy. Better that the row control has a `Bind(item)` method and doesn't accumulate handlers inside.

### Variable-height rows

`fixedItemHeight` works only in the `FixedHeight` virtualization method (the default). If rows have different heights (e.g. a chat: one line vs 20 lines of wrapped markdown), a fixed height clips/overlaps content. Switch the virtualization method:

```csharp
listView.virtualizationMethod = CollectionVirtualizationMethod.DynamicHeight; // default = FixedHeight
listView.itemsSource = messages;
listView.makeItem = () => new MessageRow();
listView.bindItem = (e, i) => ((MessageRow)e).Bind(messages[i]);
```

In `DynamicHeight` the height comes from the row's actual content; `fixedItemHeight` is not needed (in this mode it's only an initial estimate). Verified by reflection in a live editor: the property
`BaseVerticalCollectionView.virtualizationMethod` (type `CollectionVirtualizationMethod`), enum fields are exactly `FixedHeight` and `DynamicHeight`. Cost: measuring each visible row is a little more expensive, but with thousands of items it is still incomparably cheaper than building all elements at once.

## Pooling VisualElement

Unity doesn't provide a universal built-in pool for any `VisualElement`. If you make your own pool:

On return to the pool, always:

- remove callbacks;
- clear userData;
- reset class state: `is-selected`, `is-warning`, etc.;
- reset inline styles;
- cancel scheduled tasks;
- remove from parent;
- clear binding/data references.

Otherwise you'll get "ghost" clicks, memory, and state from the old item.

## Text performance

- Don't rewrite `label.text` every frame with the same value.
- For timers update at a reasonable rate, e.g. 5–10 times/sec if you don't need frame-perfect.
- Long rich text and outline/shadow can be more expensive.

## Selectors: performance and maintainability

Better:

```css
.inventory__slot.is-selected {}
```

Worse:

```css
.inventory > .panel > .scroll > .row:nth-child > .slot {}
```

UITK USS isn't fully a browser CSS; less magic — more stable.

## Debug checklist for "why isn't the style working"

1. Is the style sheet actually linked to the UXML?
2. Does the class/name on the element match?
3. Is an inline style overriding USS?
4. Is `AttributeOverrides` trying to change `style/class/name`? That's not allowed.
5. Does the UI Builder preview theme differ from the Panel Settings runtime theme?
6. Is the material inherited from the parent?
7. Is the filter declaration overridden by another class?
8. Is `display: none` breaking the transition?
9. Is the element stale after a reload, and you're changing the wrong reference?

## Documentation

- Profiler markers: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-profiler-markers.html
- Panel Settings / atlas: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-Runtime-Panel-Settings.html
- Dynamic atlas: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-control-textures-of-the-dynamic-atlas.html
- Masking: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-masking.html
- Managing elements best practices: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-best-practices-for-managing-elements.html
- Comparison of UI systems: https://docs.unity3d.com/6000.5/Documentation/Manual/UI-system-compare.html
