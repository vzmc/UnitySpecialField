Shader "ZYB/SpecialFiled"
{
    HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        // -------------------------------------
        // Universal Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
        #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
        #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
        #pragma multi_compile_fragment _ _SHADOWS_SOFT
        #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
        #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
        #pragma multi_compile_fragment _ _LIGHT_LAYERS
        #pragma multi_compile_fragment _ _LIGHT_COOKIES
        #pragma multi_compile _ _FORWARD_PLUS
        #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"
        
        // -------------------------------------
        // Unity defined keywords
        #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
        #pragma multi_compile _ SHADOWS_SHADOWMASK
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma multi_compile _ DYNAMICLIGHTMAP_ON
        #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
        #pragma multi_compile_fog
        #pragma multi_compile_fragment _ DEBUG_DISPLAY

        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing
        #pragma instancing_options renderinglayer
        #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

        TEXTURE2D_X(_DisplacementMap);
        float4 _DisplacementParams;
        #define _DisplacementSpeed _DisplacementParams.xy
        #define _DisplacementScale _DisplacementParams.zw
        
        float3 _CenterPosition;
        float _Radius;
        float _EdgeSmooth;

        half4 _ShallowColor;
        half4 _DeepColor;
        float _DepthSmooth;

        // 3回乗算したもっと濃い反色を取得
        half3 GetDeepNegativeColor(half3 color)
        {
            half3 negativeColor = 1 - color;
            negativeColor *= negativeColor * negativeColor;
            return negativeColor;
        }
        
        // レイと球体の交差判定し、交差ポイントを返す(交差してない時には無意味な座標になる)
        bool IntersectRaySphere(float3 rayOrigin, float3 rayDir, float3 sphereCenter, float sphereRadius,
            out float3 intersectPointNear, out float3 intersectPointFar, out int inField)
        {
            float3 L = sphereCenter - rayOrigin;
            
            float a = dot(rayDir, rayDir);
            float b = 2.0 * dot(rayDir, L);
            float c = dot(L, L) - sphereRadius * sphereRadius;
            
            float discriminant = b*b - 4*a*c;
            bool intersects = discriminant >= 0;
            
            float t1 = (-b - sqrt(discriminant)) / (2*a);
            float t2 = (-b + sqrt(discriminant)) / (2*a);

            float tNear = t1 > 0 && t1 < t2 ? t1 : t2;
            float tFar = tNear == t1 ? t2 : t1;
            
            intersectPointNear = rayOrigin + tNear * rayDir;
            intersectPointFar = rayOrigin + tFar * rayDir;
            inField = t1 * t2 < 0;  // レイの原点が球体の内側にあるかどうか
            
            return intersects && !(t1 > 0 && t2 > 0);
        }

        // float3 GetCameraRayDirWS(float2 screenUV) 
        // {
        //     float3 ws = ComputeWorldSpacePosition(screenUV, 0, UNITY_MATRIX_I_VP);
        //     float3 rayDir = normalize(ws - GetCameraPositionWS());
        //     return rayDir;
        // }

        // 歪んだUV取得
        float2 GetDisplacementUV(float2 uv)
        {
            float2 animatedUV = float2(uv.x + _Time.x * _DisplacementSpeed.x, uv.y + _Time.x * _DisplacementSpeed.y);
            float2 displacement = SAMPLE_TEXTURE2D_X(_DisplacementMap, sampler_LinearRepeat, animatedUV).rg;
            displacement = displacement * 2 - 1; // Range 0:1 -> -1:1
            displacement *= _DisplacementScale;
            return uv + displacement;
        }

        half3 CalcFieldColor(float2 uv, float2 displacementUV, half3 originalColor, half3 displacementColor)
        {
            half3 negativeColor = GetDeepNegativeColor(displacementColor);
            //displacementUV = uv;
            
            float depth = SampleSceneDepth(uv);
            float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
            float displacementDepth = SampleSceneDepth(displacementUV);
            float displacementEyeDepth = LinearEyeDepth(displacementDepth, _ZBufferParams);
            float3 worldPos = ComputeWorldSpacePosition(displacementUV, depth, UNITY_MATRIX_I_VP);

            float3 cameraPos = GetCameraPositionWS();
            float3 cameraRayDir = normalize(worldPos - cameraPos);  // GetCameraRayDirWS(displacementUV);

            float3 intersectPointNear;
            float3 intersectPointFar;
            bool inField;
            bool intersects = IntersectRaySphere(cameraPos, cameraRayDir, _CenterPosition, _Radius,
                                                 intersectPointNear, intersectPointFar, inField);

            float distanceBetweenIntersectPoints = distance(intersectPointNear, intersectPointFar);
            
            float intersectPointDepth = LinearEyeDepth(intersectPointNear, GetWorldToViewMatrix());
            float depthDelta = linearEyeDepth - intersectPointDepth;
            float displacementDepthDelta = displacementEyeDepth - intersectPointDepth;
                        
            bool isIntersectPointFront = depthDelta > 0;

            bool drawFieldColor = inField || (intersects && isIntersectPointFront);

            float fieldDepth = inField ? displacementEyeDepth : min(displacementDepthDelta, distanceBetweenIntersectPoints);
            float colorLerpT = smoothstep(0, _DepthSmooth, fieldDepth);
            half4 fieldColor = lerp(_ShallowColor, _DeepColor, colorLerpT);

            fieldColor.rgb = lerp(displacementColor, fieldColor.rgb, fieldColor.a);

            //fieldColor.rgb = negativeColor;
            
            half3 finalColor = drawFieldColor ? fieldColor.rgb : originalColor;
                        
            return finalColor;
        }
    
    ENDHLSL
    
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent+100" }
        LOD 100
        Cull Off ZWrite Off ZTest Always

        Pass    // 0
        {
            Name "Scan"
            
            Tags
            {
                "LightMode" = "PostEffects"
            }
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex Vert
            #pragma fragment Frag

            half4 Frag(Varyings input) : SV_Target
            {
                half4 originalColor = FragBilinear(input);
                half3 negativeColor = GetDeepNegativeColor(originalColor.rgb);
                //half3 scanColor = half3(0.8, 0.8, 0.8);

                float2 uv = input.texcoord;
                float depth = SampleSceneDepth(uv);
                float linearEyeDepth = LinearEyeDepth(depth, _ZBufferParams);
                float linear01Depth = Linear01Depth(depth, _ZBufferParams);
                float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);

                float dis = distance(_CenterPosition, worldPos);
                float lerpT = _EdgeSmooth > 0 ? smoothstep(_Radius - _EdgeSmooth, _Radius, dis) : step(_Radius, dis);

                float outerStep = 1 - step(_Radius, dis);
                float interStep = smoothstep(_Radius - _EdgeSmooth, _Radius, dis);
                float mixStep = outerStep * interStep;

                // scanColor *= mixStep;
                // half4 finalColor = half4(originalColor.rgb + scanColor, 1);
                
                half4 finalColor = half4(lerp(negativeColor, originalColor.rgb, lerpT), 1);
                
                return finalColor;
            }
            
            ENDHLSL
        }
        
        Pass    // 1
        {
            Name "Field"
            
            Tags
            {
                "LightMode" = "PostEffects"
            }
            
            HLSLPROGRAM

            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            #pragma vertex Vert
            #pragma fragment Frag

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.texcoord;
                half4 originalColor = FragBilinear(input);

                float2 displacementUV = GetDisplacementUV(uv);
                input.texcoord = displacementUV;
                half4 displacementColor = FragBilinear(input);
                
                half3 fieldColor = CalcFieldColor(uv, displacementUV, originalColor.rgb, displacementColor.rgb);
                
                return half4(fieldColor, 1);
            }
            
            ENDHLSL
        }
        
        Pass    // 2
        {
            Name "Mesh Field"

            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varying
            {
                float4 positionCS   : SV_POSITION;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varying Vert(Attributes input)
            {
                Varying output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.texcoord = input.texcoord;
                return output;
            }

            half4 Frag(Varying input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = GetNormalizedScreenSpaceUV(input.positionCS);
                half3 originalColor = SampleSceneColor(uv);

                float2 displacementUV = GetDisplacementUV(uv);
                half3 displacementColor = SampleSceneColor(displacementUV);
                
                half3 fieldColor = CalcFieldColor(uv, displacementUV, originalColor.rgb, displacementColor.rgb);
                return half4(fieldColor, 1);
            }
            
            ENDHLSL
        }
    }
}
