using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZYB
{
    public class SpecialFieldFeature : ScriptableRendererFeature
    {
        public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
        public ScriptableRenderPassInput requirements = ScriptableRenderPassInput.Depth;

        private SpecialFieldPass _specialFieldPass;
        
        // private readonly int _centerPositionId = Shader.PropertyToID("_CenterPosition");
        // private readonly int _radiusId = Shader.PropertyToID("_Radius");
        // private readonly int _edgeSmoothId = Shader.PropertyToID("_EdgeSmooth");
        // private readonly int _displacementMapId = Shader.PropertyToID("_DisplacementMap");
        // private readonly int _displacementScaleId = Shader.PropertyToID("_DisplacementScale");
        // private readonly int _waterColorId = Shader.PropertyToID("_WaterColor");
        
        public override void Create()
        {
            _specialFieldPass = new SpecialFieldPass
            {
                renderPassEvent = injectionPoint
            };
            _specialFieldPass.ConfigureInput(requirements);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            var param = SpecialFieldParameter.Instance;
            if (param == null || !param.IsPostActive)
            {
                return;
            }
            
            if (renderingData.cameraData.isPreviewCamera)
            {
                return;
            }

            var passMaterial = param.PassMaterial;
            _specialFieldPass.Setup(passMaterial, (int)param.PassIndex);
            renderer.EnqueuePass(_specialFieldPass);
        }

        protected override void Dispose(bool disposing)
        {
            _specialFieldPass.Dispose();
        }

        class SpecialFieldPass : ScriptableRenderPass
        {
            private Material _passMaterial;
            private int _passIndex;

            public void Setup(Material mat, int index)
            {
                _passMaterial = mat;
                _passIndex = index;
                profilingSampler = new ProfilingSampler(GetType().Name);
            }

            public void Dispose() { }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, profilingSampler))
                {
                    Blit(cmd, ref renderingData, _passMaterial, _passIndex);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }
        }
    }
}
