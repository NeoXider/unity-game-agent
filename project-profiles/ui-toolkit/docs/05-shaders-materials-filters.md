# 05 — Шейдеры, материалы и фильтры в UI Toolkit 6.5

## Два разных механизма

В UITK 6.5 важно не путать:

| Механизм | Что делает | Когда использовать |
|---|---|---|
| `-unity-material` | Назначает custom material на mesh элемента | hologram, dissolve, special fill, scanline |
| USS `filter` | Рендерит element subtree в texture и гонит через shader/post effect | blur background, grayscale subtree, swirl, shockwave |
| Built-in USS filters | Готовые эффекты | blur, grayscale, invert, opacity, sepia, tint, hue-rotate, contrast |
| Custom USS filter | Свой shader pass над subtree | swirl, distortion, CRT warp, radial blur |
| UI Shader Graph | Создаёт material/shader для UI | artist-friendly material effects |

## `-unity-material`

USS property:

```css
.hologram-card {
    -unity-material: url("project://database/Assets/UI/Materials/M_HologramUI.mat");
}
```

Лайфхак: `-unity-material` наследуется детьми. Если материал должен быть только на контейнере, сбрось его на child content:

```css
.hologram-card__content {
    -unity-material: none;
}
```

Когда выбирать:

- эффект должен быть свойством конкретного visual element mesh;
- нужен shader graph material;
- эффект не должен постобрабатывать всех детей как одну картинку.

Когда не выбирать:

- нужно blur всего меню вместе с children;
- нужно distortion уже отрисованного subtree;
- нужно единое post-process поведение для группы.

## UI Shader Graph notes

UI Shader Graph в URP имеет Fragment context с `Base Color` и `Alpha`. Для transparent UI обычно нужны корректные blending settings:

- Alpha — обычная прозрачность;
- Premultiply — полезно, если работаешь с premultiplied alpha;
- Additive — glow/energy style;
- Multiply — затемняющие overlay effects.

Практический pipeline:

```text
1. Create → Shader Graph → URP → UI Shader Graph.
2. Настроить Fragment: Base Color, Alpha.
3. Создать Material из graph.
4. Назначить material через USS `-unity-material`.
5. Проверить наследование материала на children.
```

## Built-in USS filters

```css
.pause-backdrop {
    filter: blur(8px) grayscale(25%) opacity(90%);
}

.disabled-item {
    filter: grayscale(100%) opacity(55%);
}

.warning-panel {
    filter: tint(rgba(255, 64, 64, 0.22));
}
```

Built-in filters можно комбинировать. Они применяются последовательно.

Важно: если два класса задают `filter`, они не объединятся автоматически; победит последний/более приоритетный style.

Плохо:

```css
.blur { filter: blur(4px); }
.gray { filter: grayscale(100%); }
```

```xml
<ui:VisualElement class="blur gray" />
```

Не рассчитывай, что получится `blur + grayscale`.

Хорошо:

```css
.blur-gray {
    filter: blur(4px) grayscale(100%);
}
```

## Filter performance

USS filter — это не “бесплатный CSS”. Unity рендерит содержимое элемента и его children в texture, потом shader обрабатывает эту texture и возвращает результат в UI hierarchy.

Практические правила:

- не применяй heavy blur на огромный fullscreen root без проверки profiler;
- лучше blur-ить конкретный backdrop слой, а не весь UI;
- комбинируй filters в одном declaration;
- избегай постоянного изменения filter parameters каждый frame без нужды;
- для transition filters держи одинаковый порядок функций.

## Filter transitions

Хорошо:

```css
.modal-backdrop {
    filter: blur(0px) grayscale(0%) opacity(0%);
    transition-property: filter;
    transition-duration: 180ms;
}

.modal-backdrop.is-open {
    filter: blur(8px) grayscale(30%) opacity(100%);
}
```

Плохо:

```css
.modal-backdrop { filter: blur(0px); }
.modal-backdrop.is-open { filter: grayscale(30%) blur(8px); }
```

Типы и порядок filter functions должны совпадать для плавной интерполяции.

## Custom USS filter

Custom filter состоит из:

```text
FilterFunctionDefinition asset
├─ Parameters: float/color/etc.
├─ Passes: material + pass index
├─ Bindings: parameter -> material property
└─ Optional margins callback for effects extending outside element rect
```

USS usage:

```css
.swirl-card {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 58.9 2.3);
}
```

Можно комбинировать:

```css
.swirl-card.is-hovered {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 65 2.5) blur(1px);
}
```

## Custom filter shader skeleton

Файл: `SwirlFilter.shader`

```hlsl
Shader "Hidden/UITK/SwirlFilter"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Angle ("Angle", Float) = 0
        _Radius ("Radius", Float) = 0.5
    }

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _UIE_OUTPUT_LINEAR

            #include "UnityCG.cginc"
            #include "UnityUIEFilter.cginc"

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Angle;
            float _Radius;

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float rectIndex : TEXCOORD1;
            };

            v2f vert(FilterVertexInput v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.rectIndex = GetFilterRectIndex(v);
                return o;
            }

            float2 Rotate(float2 p, float angle)
            {
                float s = sin(angle);
                float c = cos(angle);
                return float2(c * p.x - s * p.y, s * p.x + c * p.y);
            }

            half4 frag(v2f i) : SV_Target
            {
                float4 uvRect = GetFilterUVRect(i.rectIndex);
                float2 uv = i.uv;

                float2 center = (uvRect.xy + uvRect.zw) * 0.5;
                float2 p = uv - center;
                float dist = length(p);
                float mask = saturate(1.0 - dist / max(_Radius, 0.0001));
                float angle = _Angle * mask * mask;

                uv = center + Rotate(p, angle);

                half4 col = tex2D(_MainTex, uv);

                #ifdef _UIE_OUTPUT_LINEAR
                    col.rgb = GammaToLinearSpace(col.rgb);
                #endif

                return col;
            }
            ENDHLSL
        }
    }
}
```

## Custom filter setup checklist

1. Создай shader и material.
2. Создай `FilterFunctionDefinition` asset.
3. Добавь parameters: например `Angle`, `Radius`.
4. Добавь pass с material и pass index `0`.
5. Забинди parameter 0 → `_Angle`, parameter 1 → `_Radius`.
6. В USS задай `filter: filter("...asset" angle radius);`.
7. Если эффект выходит за границы элемента, настрой margins callback или увеличь margin/padding контейнера.
8. Проверь gamma/linear workflow и `_UIE_OUTPUT_LINEAR`.

## Что лучше для популярных эффектов

| Эффект | Лучший путь |
|---|---|
| Disabled item grayscale | Built-in filter |
| Pause menu blur | Built-in filter on backdrop |
| Hologram card | UI Shader Graph + `-unity-material` |
| Dissolve button | UI Shader Graph + material param |
| Shockwave over panel | Custom USS filter |
| Swirl portal preview | Custom USS filter |
| Health fill gradient | USS background/sprite или material, зависит от art |
| Animated glow | material + USS class/C# param |

## Документация

- USS filter overview: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter.html
- Built-in filters: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/built-in-filters.html
- Custom filters: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/custom-filters.html
- Filter transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter-transitions.html
- Swirl filter example: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/create-custom-swirl-filter.html
- UI Shader Graph reference: https://docs.unity3d.com/6000.5/Documentation/Manual/urp/prebuilt-shader-graphs-urp-ui.html
- USS material property: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
