//
//  cr_atm_scattering.metal
//  crShaders
//
//  Created by Joe Moulton on 2/19/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../MtlShaderInterface.h"
#include "../atm_T.h"

static constant float mulScattSteps = 20.0;
static constant int   sqrtSamples = 8;

float3 getSphericalDir(float theta, float phi)
{
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return float3(sinPhi * sinTheta, cosPhi, sinPhi * cosTheta);
}

// Calculates Equation (5) and (7) from the paper.
void getMulScattValues(texture2d<float> tLUT, sampler sampler2D, float3 pos, float3 sunDir, /*out*/ thread float3 &lumTotal, thread /*out*/ float3 &fms)
{
    lumTotal = float3(0.0, 0.0, 0.0);
    fms = float3(0.0, 0.0, 0.0);

    float invSamples = 1.0 / float(sqrtSamples * sqrtSamples);
    for (int i = 0; i < sqrtSamples; i++) {
        for (int j = 0; j < sqrtSamples; j++) {
            // This integral is symmetric about theta = 0 (or theta = PI), so we
            // only need to integrate from zero to PI, not zero to 2*PI.
            float theta = PI * (float(i) + 0.5) / float(sqrtSamples);
            float phi = safeacos(1.0 - 2.0 * (float(j) + 0.5) / float(sqrtSamples));
            float3 rayDir = getSphericalDir(theta, phi);

            float atmoDist = rayIntersectSphere(pos, rayDir, atmosphereRadiusMM);
            float groundDist = rayIntersectSphere(pos, rayDir, groundRadiusMM);
            float tMax = atmoDist;
            if (groundDist > 0.0) {
                tMax = groundDist;
            }

            float cosTheta = dot(rayDir, sunDir);

            float miePhaseValue = getMiePhase(cosTheta);
            float rayleighPhaseValue = getRayleighPhase(-cosTheta);

            float3 lum = float3(0.0, 0.0, 0.0), lumFactor = float3(0.0, 0.0, 0.0), transmittance = float3(1.0, 1.0, 1.0);
            float t = 0.0;
            for (float stepI = 0.0; stepI < mulScattSteps; stepI += 1.0) {
                float newT = ((stepI + 0.3) / mulScattSteps) * tMax;
                float dt = newT - t;
                t = newT;

                float3 newPos = pos + t * rayDir;

                float3 rayleighScattering, extinction;
                float mieScattering;
                getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

                float3 sampleTransmittance = exp(-dt * extinction);

                // Integrate within each segment.
                float3 scatteringNoPhase = rayleighScattering + mieScattering;
                float3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / extinction;
                lumFactor += transmittance * scatteringF;

                // This is slightly different from the paper, but I think the paper has a mistake?
                // In equation (6), I think S(x,w_s) should be S(x-tv,w_s).
                float3 sunTransmittance = getValFromTLUT(tLUT, sampler2D, tLUTRes, newPos, sunDir);

                float3 rayleighInScattering = rayleighScattering * rayleighPhaseValue;
                float mieInScattering = mieScattering * miePhaseValue;
                float3 inScattering = (rayleighInScattering + mieInScattering) * sunTransmittance;

                // Integrated scattering within path segment.
                float3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                lum += scatteringIntegral * transmittance;
                transmittance *= sampleTransmittance;
            }

            if (groundDist > 0.0) {
                float3 hitPos = pos + groundDist * rayDir;
                if (dot(pos, sunDir) > 0.0) {
                    hitPos = normalize(hitPos) * groundRadiusMM;
                    lum += transmittance * groundAlbedo * getValFromTLUT(tLUT, sampler2D, tLUTRes, hitPos, sunDir);
                }
            }

            fms += lumFactor * invSamples;
            lumTotal += lum * invSamples;
        }
    }
}


// Buffer B is the multiple-scattering LUT. Each pixel coordinate corresponds to a height and sun zenith angle, and
// the value is the multiple scattering approximation (Psi_ms from the paper, Eq. 10).
fragment AtmBufferTargets cr_atmMS_frag(MetalRenderVertexOutput in        [[ stage_in   ]],
                                        texture2d<float>        tLUT      [[ texture(0) ]],
                                        //texture2d<float>        msLUT     [[ texture(1) ]],
                                        sampler                 sampler2D [[ sampler(0) ]])
                                        //texturecube<float>      texture   [[ texture(0) ]], //always sample environment cubemaps with full floating point precision
                                        //sampler                 sampler3D [[ sampler(0) ]])
                                        //constant Camera&        camera    [[ buffer(0)  ]])
{
    AtmBufferTargets targets;

    /*
    if (fragCoord.x >= (msLUTRes.x + 1.5) || fragCoord.y >= (msLUTRes.y + 1.5)) {
        return;
    }
    float u = clamp(fragCoord.x, 0.0, msLUTRes.x - 1.0) / msLUTRes.x;
    float v = clamp(fragCoord.y, 0.0, msLUTRes.y - 1.0) / msLUTRes.y;
    */

    float sunCosTheta = 2.0 * in.fragUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, in.fragUV.y);

    float3 pos = float3(0.0, height, 0.0);
    float3 sunDirAlt = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));

    float3 lum  = float3(0.0,0.0,0.0);
    float3 f_ms = float3(0.0,0.0,0.0);
    getMulScattValues(tLUT, sampler2D, pos, sunDirAlt, lum, f_ms);

    // Equation 10 from the paper.
    float3 psi = lum / (1.0 - f_ms);
    targets.MS = float4(psi, 1.0);
    return targets;
}
