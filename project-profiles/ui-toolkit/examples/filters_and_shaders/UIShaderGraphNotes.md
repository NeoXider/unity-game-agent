# UI Shader Graph + UITK notes

## When to use

Use UI Shader Graph when you need a material look on an element:

- hologram;
- scanlines;
- dissolve;
- animated gradient;
- additive glow;
- custom alpha.

## How to wire it to UITK

1. Create a UI Shader Graph in URP.
2. Create a material from the graph.
3. Assign the material via USS:

```css
.special-button {
    -unity-material: url("project://database/Assets/UI/Materials/M_SpecialButton.mat");
}
```

## Inheritance

`-unity-material` is inherited by children.

```css
.special-button__label {
    -unity-material: none;
}
```

## Material vs filter

```text
Material: the element is drawn with its own shader/material.
Filter: the subtree is first rendered into a texture, then processed by a shader pass.
```

If you need to "distort the whole card together with its text" — that's a filter.
If you need "a special shader on a button's background" — that's a material.
