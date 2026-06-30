# 05 — Shaders, materials and filters in UI Toolkit 6.5

## Two different mechanisms

In UITK 6.5 it's important not to confuse:

| Mechanism | What it does | When to use |
|---|---|---|
| `-unity-material` | Assigns a custom material to the element's mesh | hologram, dissolve, special fill, scanline |
| USS `filter` | Renders an element subtree into a texture and pushes it through a shader/post effect | blur background, grayscale subtree, swirl, shockwave |
| Built-in USS filters | Ready-made effects | blur, grayscale, invert, opacity, sepia, tint, hue-rotate, contrast |
| Custom USS filter | Your own shader pass over a subtree | swirl, distortion, CRT warp, radial blur |
| UI Shader Graph | Creates a material/shader for UI | artist-friendly material effects |

## `-unity-material`

USS property:

```css
.hologram-card {
    -unity-material: url("project://database/Assets/UI/Materials/M_HologramUI.mat");
}
```

Tip: `-unity-material` is inherited by children. If the material should be only on the container, reset it on the child content:

```css
.hologram-card__content {
    -unity-material: none;
}
```

When to choose it:

- the effect should be a property of a specific visual element mesh;
- you need a shader graph material;
- the effect should not post-process all children as one image.

When not to:

- you need to blur the whole menu together with its children;
- you need distortion of an already-rendered subtree;
- you need uniform post-process behavior for a group.

## UI Shader Graph notes

The UI Shader Graph in URP has a Fragment context with `Base Color` and `Alpha`. For transparent UI you usually need correct blending settings:

- Alpha — ordinary transparency;
- Premultiply — useful when working with premultiplied alpha;
- Additive — glow/energy style;
- Multiply — darkening overlay effects.

Practical pipeline:

```text
1. Create → Shader Graph → URP → UI Shader Graph.
2. Set up Fragment: Base Color, Alpha.
3. Create a Material from the graph.
4. Assign the material via USS `-unity-material`.
5. Check material inheritance on children.
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

Built-in filters can be combined. They are applied in sequence.

Important: if two classes set `filter`, they don't merge automatically; the last/higher-priority style wins.

Bad:

```css
.blur { filter: blur(4px); }
.gray { filter: grayscale(100%); }
```

```xml
<ui:VisualElement class="blur gray" />
```

Don't expect `blur + grayscale` to result.

Good:

```css
.blur-gray {
    filter: blur(4px) grayscale(100%);
}
```

## Filter performance

A USS filter is not "free CSS". Unity renders the element's content and its children into a texture, then a shader processes that texture and returns the result into the UI hierarchy.

Practical rules:

- don't apply a heavy blur on a huge full-screen root without a profiler check;
- better to blur a specific backdrop layer than the whole UI;
- combine filters in one declaration;
- avoid changing filter parameters every frame without need;
- for transitioning filters keep the same order of functions.

## Filter transitions

Good:

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

Bad:

```css
.modal-backdrop { filter: blur(0px); }
.modal-backdrop.is-open { filter: grayscale(30%) blur(8px); }
```

The types and order of filter functions must match for smooth interpolation.

## Custom USS filter

A custom filter consists of:

```text
FilterFunctionDefinition asset
├─ Parameters: float/color/etc.
├─ Passes: material + pass index
├─ Bindings: parameter -> material property
└─ Optional margins callback for effects extending outside the element rect
```

USS usage:

```css
.swirl-card {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 58.9 2.3);
}
```

Can be combined:

```css
.swirl-card.is-hovered {
    filter: filter("Assets/UI/Filters/SwirlFilter.asset" 65 2.5) blur(1px);
}
```

## Custom filter shader skeleton

File: `SwirlFilter.shader`

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

1. Create a shader and material.
2. Create a `FilterFunctionDefinition` asset.
3. Add parameters: e.g. `Angle`, `Radius`.
4. Add a pass with the material and pass index `0`.
5. Bind parameter 0 → `_Angle`, parameter 1 → `_Radius`.
6. In USS set `filter: filter("...asset" angle radius);`.
7. If the effect extends beyond the element bounds, set up a margins callback or increase the container's margin/padding.
8. Check the gamma/linear workflow and `_UIE_OUTPUT_LINEAR`.

## What's best for popular effects

| Effect | Best path |
|---|---|
| Disabled item grayscale | Built-in filter |
| Pause menu blur | Built-in filter on the backdrop |
| Hologram card | UI Shader Graph + `-unity-material` |
| Dissolve button | UI Shader Graph + material param |
| Shockwave over a panel | Custom USS filter |
| Swirl portal preview | Custom USS filter |
| Health fill gradient | USS background/sprite or material, depending on the art |
| Animated glow | material + USS class/C# param |

## Documentation

- USS filter overview: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter.html
- Built-in filters: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/built-in-filters.html
- Custom filters: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/custom-filters.html
- Filter transitions: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/uss-filter-transitions.html
- Swirl filter example: https://docs.unity3d.com/6000.5/Documentation/Manual/ui-systems/create-custom-swirl-filter.html
- UI Shader Graph reference: https://docs.unity3d.com/6000.5/Documentation/Manual/urp/prebuilt-shader-graphs-urp-ui.html
- USS material property: https://docs.unity3d.com/6000.5/Documentation/Manual/UIE-USS-SupportedProperties.html
