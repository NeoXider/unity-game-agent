# SwirlFilter setup

1. Скопируй `SwirlFilter.shader` в `Assets/UI/Shaders/SwirlFilter.shader`.
2. Создай material `Assets/UI/Materials/M_SwirlFilter.mat` на этом shader.
3. Создай `FilterFunctionDefinition` asset: `Assets/UI/Filters/SwirlFilter.asset`.
4. Добавь два parameters:
   - `Angle`, float, default `0`.
   - `Radius`, float, default `0.5`.
5. Добавь pass:
   - Material: `M_SwirlFilter`.
   - Pass index: `0`.
6. Bind parameter 0 → material property `_Angle`.
7. Bind parameter 1 → material property `_Radius`.
8. В USS:

```css
.portal-preview {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 58.9 0.5);
}
```

Если эффект обрезается по краям, добавь margin/padding или настрой margins callback в filter definition.
