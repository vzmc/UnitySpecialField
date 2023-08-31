using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ZYB
{
    // [Serializable, VolumeComponentMenuForRenderPipeline("ZYB/SpecialField", typeof(UniversalRenderPipeline))]
    // public sealed class SpecialFieldVolume : VolumeComponent, IPostProcessComponent
    // {
    //     public MinFloatParameter radius = new(0f, 0f);
    //     public ClampedFloatParameter edgeSmooth = new(0f, 0f, 1f);
    //
    //     public Vector3 Center => Vector3.zero;
    //     
    //     public bool IsActive() => radius.value > 0f;
    //
    //     public bool IsTileCompatible() => false;
    // }
}
