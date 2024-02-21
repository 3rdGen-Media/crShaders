//
//  cr_atm_transmittance.metal
//  crShaders-OSX
//
//  Created by Joe Moulton on 2/18/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../MtlShaderInterface.h"
#include "../atm_T.h"

/*
struct T
{
    float4  v   [[ color(ATM_TRANSMITTANCE_ATTACHMENT) ]];
};
*/
 
fragment AtmBufferTargets cr_atmT_frag(MetalRenderVertexOutput in        [[ stage_in   ]],
                                       texture2d<float>        colorMap  [[ texture(0) ]],
                                       texture2d<float>        normalMap [[ texture(1) ]],
                                       sampler                 sampler2D [[ sampler(0) ]])
                             //texturecube<float>    texture   [[ texture(0) ]], //always sample environment cubemaps with full floating point precision
                             //sampler               sampler3D [[ sampler(0) ]])
                             //constant Camera&      camera    [[ buffer(0)  ]])
{
    AtmBufferTargets targets
    ;
    /*
    if (crFragmentTextureUV.x >= (tLUTRes.x + 1.5) || crFragmentTextureUV.y >= (tLUTRes.y + 1.5))
    {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, tLUTRes.x - 1.0) / tLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, tLUTRes.y - 1.0) / tLUTRes.y;
    */

    float sunCosTheta = 2.0 * in.fragUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, in.fragUV.y);

    float3 pos = float3(0.0, height, 0.0);
    float3 sunDirAlt = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));

    float3 T = getSunTransmittance(pos.xyz, sunDirAlt);
    
    //return float4(T.x, T.y, T.z, 1.0);
    targets.T = float4(T, 1.0);
    return targets;
}
