//
//  cr_atm_sky_view.metal
//  crShaders-OSX
//
//  Created by Joe Moulton on 2/18/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../MtlShaderInterface.h"
#include "../atm_T.h"


// Buffer C calculates the actual sky-view! It's a lat-long map (or maybe altitude-azimuth is the better term),
// but the latitude/altitude is non-linear to get more resolution near the horizon.


float3 getValFromMultiScattLUT(texture2d<float> msLUT, sampler sampler2D, float2 bufferRes, float3 pos, float3 sunDir) {
    float  height = length(pos);
    float3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    float2 uv = float2(msLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0), msLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return msLUT.sample(sampler2D, uv).rgb;
}


static constant int numScatteringSteps = 32;
float3 raymarchScattering(texture2d<float> tLUT, texture2d<float> msLUT, sampler sampler2D, float3 pos, float3 rayDir, float3 sunDir, float tMax, float numSteps)
{
    float cosTheta = dot(rayDir, sunDir);

    float miePhaseValue      = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    float3 lum = float3(0.0, 0.0, 0.0);
    float3 transmittance = float3(1.0, 1.0, 1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0)
    {
        float newT = ((i + 0.3) / numSteps) * tMax;
        float dt = newT - t;
        t = newT;

        float3 newPos = pos + t * rayDir;

        float3 rayleighScattering = float3(0,0,0);
        float3 extinction         = float3(0,0,0);
        float mieScattering       = 0.0;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        float3 sampleTransmittance = exp(-dt * extinction);

        float3 sunTransmittance = getValFromTLUT(tLUT, sampler2D, tLUTRes,  newPos, sunDir);
        float3 psiMS =  getValFromMultiScattLUT(msLUT, sampler2D, msLUTRes, newPos, sunDir);

        float3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunTransmittance + psiMS);
        float3 mieInScattering = mieScattering * (miePhaseValue * sunTransmittance + psiMS);
        float3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}

fragment AtmBufferTargets cr_atmSKY_frag(MetalRenderVertexOutput in        [[ stage_in   ]],
                                         texture2d<float>        tLUT      [[ texture(0) ]],
                                         texture2d<float>        msLUT     [[ texture(1) ]],
                                         sampler                 sampler2D [[ sampler(0) ]])
                                        //texturecube<float>      texture   [[ texture(0) ]], //always sample environment cubemaps with full floating point precision
                                        //sampler                 sampler3D [[ sampler(0) ]])
                                        //constant Camera&        camera    [[ buffer(0)  ]])
{
    AtmBufferTargets targets;

    float3 camPos = float3(0.0, groundRadiusMM + 0.0002, 0.0);
    //vec3 camPos = vec3(0.0, groundRadiusMM + 0.0002 * 1000. + viewPos.y, 0.0);

    /*
    if (crFragmentTextureUV.x >= (skyLUTRes.x + 1.5) || crFragmentTextureUV.y >= (skyLUTRes.y + 1.5)) {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, skyLUTRes.x - 1.0) / skyLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, skyLUTRes.y - 1.0) / skyLUTRes.y;
    */

    float u = in.fragUV.x;
    float v = in.fragUV.y;

    float azimuthAngle = (u - 0.5) * 2.0 * PI;

    // Non-linear mapping of altitude. See Section 5.3 of the paper.
    float adjV;
    if (v < 0.5)
    {
        float coord = 1.0 - 2.0 * v;
        adjV = -coord * coord;
    }
    else
    {
        float coord = v * 2.0 - 1.0;
        adjV = coord * coord;
    }

    float  height = length(camPos);
    float3 up = camPos / height;
    float  horizonAngle  = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height) - 0.5 * PI;
    float  altitudeAngle = adjV * 0.5 * PI - horizonAngle;

    float  cosAltitude = cos(altitudeAngle);
    float3 rayDir = float3(cosAltitude * sin(azimuthAngle), sin(altitudeAngle), -cosAltitude * cos(azimuthAngle));

    float  sunAltitude = (0.5 * PI) - acos(dot(in.sunDir.xyz, up));
    float3 sunDirAlt   = float3(0.0, sin(sunAltitude), -cos(sunAltitude));

    float  atmoDist   = rayIntersectSphere(camPos, rayDir, atmosphereRadiusMM);
    float  groundDist = rayIntersectSphere(camPos, rayDir, groundRadiusMM);
    float  tMax = (groundDist < 0.0) ? atmoDist : groundDist;
    float3 lum  = raymarchScattering(tLUT, msLUT, sampler2D, camPos, rayDir, sunDirAlt, tMax, float(numScatteringSteps));

    
    //vec3 lum = raymarchScattering(crSourceTexture, tLUTRes, crNormalTexture, skyLUTRes, camPos, rayDir, sunDir, float(numScatteringSteps));
    targets.SKY = float4(lum.x, lum.y, lum.z, 1.0);
    return targets;
}
