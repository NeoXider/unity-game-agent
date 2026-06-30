# SwirlFilter setup

1. Copy `SwirlFilter.shader` to `Assets/UI/Shaders/SwirlFilter.shader`.
2. Create a material `Assets/UI/Materials/M_SwirlFilter.mat` using that shader.
3. Create a `FilterFunctionDefinition` asset: `Assets/UI/Filters/SwirlFilter.asset`.
4. Add two parameters:
   - `Angle`, float, default `0`.
   - `Radius`, float, default `0.5`.
5. Add a pass:
   - Material: `M_SwirlFilter`.
   - Pass index: `0`.
6. Bind parameter 0 → material property `_Angle`.
7. Bind parameter 1 → material property `_Radius`.
8. In USS:

```css
.portal-preview {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 58.9 0.5);
}
```

If the effect is clipped at the edges, add margin/padding or set up a margins callback in the filter definition.
