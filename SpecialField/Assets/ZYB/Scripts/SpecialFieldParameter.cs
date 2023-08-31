using UnityEngine;

namespace ZYB
{
    [ExecuteAlways]
    public class SpecialFieldParameter : MonoBehaviour
    {
        private static SpecialFieldParameter _instance;
        public static SpecialFieldParameter Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = FindObjectOfType<SpecialFieldParameter>();
                }
                return _instance;
            }
        }
        
        private static readonly int _centerPositionId = Shader.PropertyToID("_CenterPosition");
        private static readonly int _radiusId = Shader.PropertyToID("_Radius");
        private static readonly int _edgeSmoothId = Shader.PropertyToID("_EdgeSmooth");
        private static readonly int _displacementMapId = Shader.PropertyToID("_DisplacementMap");
        private static readonly int _dispacementParamsId = Shader.PropertyToID("_DisplacementParams");
        private static readonly int _ShallowColorId = Shader.PropertyToID("_ShallowColor");
        private static readonly int _DeepColorId = Shader.PropertyToID("_DeepColor");
        private static readonly int _DepthSmoothId = Shader.PropertyToID("_DepthSmooth");

        public enum Pass
        {
            Scan,
            Field,
        }
        
        public bool PostActive = false;
        public bool MeshActive = false;
        public Material PassMaterial;
        public Pass PassIndex = Pass.Scan;
        public Transform CenterTransform;
        public float Radius = 0f;
        public float EdgeSmooth = 0f;
        public Texture DisplacementMap;
        public Vector2 DisplacementSpeed;
        public Vector2 DisplacementScale;
        public Color ShallowColor;
        public Color DeepColor;
        public float DepthSmooth = 0f;
        
        public Vector3 Center => CenterTransform != null ? CenterTransform.position : Vector3.zero;
        
        public bool IsActive => isActiveAndEnabled
                                && PassMaterial != null
                                && Radius > 0f;
        public bool IsPostActive => PostActive && IsActive;
        public bool IsMeshActive => MeshActive && IsActive;

        private void Update()
        {
            if (IsMeshActive || IsPostActive)
            {
                UpdateSetMaterial();
            }
        }

        private void UpdateSetMaterial()
        {
            PassMaterial.SetVector(_centerPositionId, Center);
            PassMaterial.SetFloat(_radiusId, Radius);
            PassMaterial.SetFloat(_edgeSmoothId, EdgeSmooth);
            PassMaterial.SetColor(_ShallowColorId, ShallowColor);
            PassMaterial.SetColor(_DeepColorId, DeepColor);
            PassMaterial.SetFloat(_DepthSmoothId, DepthSmooth);
            if (DisplacementMap != null)
            {
                PassMaterial.SetTexture(_displacementMapId, DisplacementMap);
                PassMaterial.SetVector(_dispacementParamsId, 
                    new Vector4(DisplacementSpeed.x, DisplacementSpeed.y, DisplacementScale.x, DisplacementScale.y));
            }
        }
    }
}
