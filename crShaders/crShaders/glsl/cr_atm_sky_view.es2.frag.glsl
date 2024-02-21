//#version 120
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision highp float;
precision highp int;
precision highp sampler2D;
#else
#define highp
#define mediump
#define lowp
#endif

#define SHADERMODEL_ES2
#include "atm_T.glsl"


vec3 getValFromMultiScattLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(msLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
        msLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return texture2D(tex, uv).rgb;
}


uniform highp sampler2D crSourceTexture;
uniform highp sampler2D crNormalTexture;

varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;

//varying mat4 projectionViewMatrix;
varying mat4 inverseProjectionViewMatrix;


varying vec4 viewport;
varying vec3 sunDir;


//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;
varying vec3 fragPos;
varying vec3 viewPos;
varying vec3 lightPos;
varying vec3 vertexNormal; //The 2 varyings that are needed to calculate cosTheta for lighting calculations

//varying mat3 TBN;

//Texture Lookup Values from vertex shader
varying vec2 crFragmentTextureUV;


// Buffer C calculates the actual sky-view! It's a lat-long map (or maybe altitude-azimuth is the better term),
// but the latitude/altitude is non-linear to get more resolution near the horizon.


const int numScatteringSteps = 32;
vec3 raymarchScattering(vec3 pos, vec3 rayDir, vec3 sunDir, float tMax, float numSteps) 
{
    float cosTheta = dot(rayDir, sunDir);

    float miePhaseValue = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) 
    {
        float newT = ((i + 0.3) / numSteps) * tMax;
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t * rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        vec3 sampleTransmittance = exp(-dt * extinction);

        vec3 sunTransmittance = getValFromTLUT(crSourceTexture, tLUTRes,  newPos, sunDir);
        vec3 psiMS = getValFromMultiScattLUT(crNormalTexture, msLUTRes, newPos, sunDir);

        vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering * (miePhaseValue * sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}


/*
 * Do raymarching : builds skyview lut inside atmoshpere, raymarches directly outside atmosphere
*/
/*
const int numScatteringSteps = 16;
vec3 raymarchScattering(sampler2D TLUT, vec2 TLUT_size, sampler2D MSLUT, vec2 MSLUT_size,
    vec3 viewPos,
    vec3 rayDir,
    vec3 sunDir,
    float numSteps) 
{


    vec2 atmos_intercept = rayIntersectSphere2D(viewPos, rayDir, atmosphereRadiusMM);
    float terra_intercept = rayIntersectSphere(viewPos, rayDir, groundRadiusMM);

    float mindist, maxdist;

    if (atmos_intercept.x < atmos_intercept.y) {
        // there is an atmosphere intercept!
        // start at the closest atmosphere intercept
        // trace the distance between the closest and farthest intercept
        mindist = atmos_intercept.x > 0.0 ? atmos_intercept.x : 0.0;
        maxdist = atmos_intercept.y > 0.0 ? atmos_intercept.y : 0.0;
    }
    else {
        // no atmosphere intercept means no atmosphere!
        return vec3(0.0);
    }

    // if in the atmosphere start at the camera
    if (length(viewPos) < atmosphereRadiusMM) mindist = 0.0;


    // if there's a terra intercept that's closer than the atmosphere one,
    // use that instead!
    if (terra_intercept > 0.0) { // confirm valid intercepts			
        maxdist = terra_intercept;
    }

    // start marching at the min dist
    vec3 pos = viewPos + mindist * rayDir;

    float cosTheta = dot(rayDir, sunDir);

    float miePhaseValue = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3) / numSteps) * (maxdist - mindist);
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t * rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;

        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        vec3 sampleTransmittance = exp(-dt * extinction);

        vec3 sunTransmittance = getValFromTLUT(TLUT, TLUT_size, newPos, sunDir);
        vec3 psiMS = vec3(0.0);// *getValFromMultiScattLUT(MSLUT, MSLUT_size, newPos, sunDir);

        vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering * (miePhaseValue * sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}
*/

void main(void)
{
    const vec3 camPos = vec3(0.0, groundRadiusMM + 0.0002, 0.0);
    //vec3 camPos = vec3(0.0, groundRadiusMM + 0.0002 * 1000. + viewPos.y, 0.0);

    /*
    if (crFragmentTextureUV.x >= (skyLUTRes.x + 1.5) || crFragmentTextureUV.y >= (skyLUTRes.y + 1.5)) {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, skyLUTRes.x - 1.0) / skyLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, skyLUTRes.y - 1.0) / skyLUTRes.y;
    */

    float u = crFragmentTextureUV.x;
    float v = crFragmentTextureUV.y;

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

    float height = length(camPos);
    vec3  up = camPos / height;
    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height) - 0.5 * PI;
    float altitudeAngle = adjV * 0.5 * PI - horizonAngle;

    float cosAltitude = cos(altitudeAngle);
    vec3  rayDir = vec3(cosAltitude * sin(azimuthAngle), sin(altitudeAngle), -cosAltitude * cos(azimuthAngle));

    float sunAltitude = (0.5 * PI) - acos(dot(sunDir, up));
    vec3  sunDirAlt = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));

    float atmoDist   = rayIntersectSphere(camPos, rayDir, atmosphereRadiusMM);
    float groundDist = rayIntersectSphere(camPos, rayDir, groundRadiusMM);
    float tMax = (groundDist < 0.0) ? atmoDist : groundDist;
    vec3 lum = raymarchScattering(camPos, rayDir, sunDirAlt, tMax, float(numScatteringSteps));
    
    /*
   vec3 lum = raymarchScattering(crSourceTexture, tLUTRes, crNormalTexture, skyLUTRes,
       camPos, rayDir, sunDir, float(numScatteringSteps));
    */

    gl_FragColor = vec4(lum, 1.0);
}

