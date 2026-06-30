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
