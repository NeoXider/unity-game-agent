# UI Shader Graph + UITK notes

## Когда использовать

Используй UI Shader Graph, если нужен material look на элементе:

- hologram;
- scanlines;
- dissolve;
- animated gradient;
- additive glow;
- custom alpha.

## Как подключить к UITK

1. Создай UI Shader Graph в URP.
2. Создай material из graph.
3. Назначь material через USS:

```css
.special-button {
    -unity-material: url("project://database/Assets/UI/Materials/M_SpecialButton.mat");
}
```

## Наследование

`-unity-material` наследуется детьми.

```css
.special-button__label {
    -unity-material: none;
}
```

## Material vs filter

```text
Material: элемент рисуется своим shader/material.
Filter: subtree сначала рендерится в texture, потом обрабатывается shader pass.
```

Если нужно “исказить всю карточку вместе с текстом” — это filter.
Если нужно “особый shader на фоне кнопки” — это material.
