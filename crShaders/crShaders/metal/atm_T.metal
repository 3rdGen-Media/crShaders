//
//  atm_T.metal
//  crShaders-OSX
//
//  Created by Joe Moulton on 2/18/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../atm_T.h"





/*
 * Animates the sun movement.
 */
float getSunAltitude(float time)
{
    const float periodSec = 120.0;
    const float halfPeriod = periodSec / 2.0;
    const float sunriseShift = 0.1;
    float cyclePoint = (1.0 - abs((fmod(time, periodSec) - halfPeriod) / halfPeriod));
    cyclePoint = (cyclePoint * (1.0 + sunriseShift)) - sunriseShift;
    return (0.5 * PI) * cyclePoint;
}

float3 getSunDir(float time)
{
    float altitude = getSunAltitude(time);
    return normalize(float3(0.0, sin(altitude), -cos(altitude)));
}

float getMiePhase(float cosTheta)
{
    const float g = 0.8;
    const float scale = 3.0 / (8.0 * PI);

    float num = (1.0 - g * g) * (1.0 + cosTheta * cosTheta);
    float denom = (2.0 + g * g) * pow((1.0 + g * g - 2.0 * g * cosTheta), 1.5);

    return scale * num / denom;
}

float getRayleighPhase(float cosTheta)
{
    const float k = 3.0 / (16.0 * PI);
    return k * (1.0 + cosTheta * cosTheta);
}


void getScatteringValues(float3 pos, /*out*/ thread float3 &rayleighScattering, /*out*/ thread float &mieScattering, /*out*/ thread float3 &extinction)
{
    float altitudeKM = (length(pos) - groundRadiusMM) * 1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0);
    float mieDensity = exp(-altitudeKM / 1.2);

    rayleighScattering = rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;

    mieScattering = mieScatteringBase * mieDensity;
    float mieAbsorption = mieAbsorptionBase * mieDensity;

    float3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM - 25.0) / 15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}


/*
void getScatteringValues(vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction)
{
    float altitudeKM = (length(pos) - groundRadiusMM); // *1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0);
    float mieDensity = exp(-altitudeKM / 1.2);

    rayleighScattering = rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;

    mieScattering = mieScatteringBase * mieDensity;
    float mieAbsorption = mieAbsorptionBase * mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM - 40.179) / 17.83);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}
*/

float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(float3 ro, float3 rd, float rad)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad * rad;
    if (c > 0.0 && b > 0.0) return -1.0;
    float discr = b * b - c;
    if (discr < 0.0) return -1.0;
    // Special case: inside sphere, use far discriminant
    if (discr > b * b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

// https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d
// - r0: ray origin
// - rd: normalized ray direction
// - s0: sphere center
// - sR: sphere radius
// - Returns distance from r0 to first intersecion with sphere,
//   or -1.0 if no intersection.
/*
float BrunetonRaySphereIntersect(float3 r0, float3 rd, float3 s0, float sR)
{
    float a = dot(rd, rd);
    vec3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sR * sR);
    if (b * b - 4.0 * a * c < 0.0)
    {
        return -1.0;
    }
    return (-b - sqrt((b * b) - 4.0 * a * c)) / (2.0 * a);
}
*/


/*
 * Same parameterization here.
 */
 /*
 vec3 getValFromTLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
     float height = length(pos);
     vec3 up = pos / height;
     float sunCosZenithAngle = dot(sunDir, up);
     vec2 uv = vec2(tLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
         tLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
     uv /= bufferRes;
     return texture(tex, uv).rgb;
 }

 vec3 getValFromMultiScattLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
     float height = length(pos);
     vec3 up = pos / height;
     float sunCosZenithAngle = dot(sunDir, up);
     vec2 uv = vec2(msLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
         msLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
     uv /= bufferRes;
     return texture(tex, uv).rgb;
 }
 */

 //End Common


static constant float sunTransmittanceSteps = 40.0;
float3 getSunTransmittance(float3 pos, float3 sunDir)
{
    if (rayIntersectSphere(pos, sunDir, groundRadiusMM) > 0.0)
    {
        return float3(0.0, 0.0, 0.0);
    }

    float atmoDist = rayIntersectSphere(pos, sunDir, atmosphereRadiusMM);
    float t = 0.0;

    float3 transmittance = float3(1.0, 1.0, 1.0);
    for (float i = 0.0; i < sunTransmittanceSteps; i += 1.0) {
        float newT = ((i + 0.3) / sunTransmittanceSteps) * atmoDist;
        float dt = newT - t;
        t = newT;

        float3 newPos = pos + t * sunDir;

        float3 rayleighScattering = float3(0,0,0);
        float3 extinction         = float3(0,0,0);
        float mieScattering       = 0.0;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        transmittance *= exp(-dt * extinction);
    }
    return transmittance;
}


float3 getValFromTLUT(texture2d<float> tLUT, sampler sampler2D, float2 bufferRes, float3 pos, float3 sunDir)
{
    float  height = length(pos);
    float3 up = pos / height;
    float  sunCosZenithAngle = dot(sunDir, up);
    float2 uv = float2(tLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0), tLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return tLUT.sample(sampler2D, uv).rgb;
}
