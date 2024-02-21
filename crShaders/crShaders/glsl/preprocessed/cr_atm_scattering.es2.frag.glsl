
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

//Begin atm_T.glsl


//Begin ATM_H

#ifndef atm_T_h 
#define atm_T_h

#define ATM_SKYVIEW_ATTACHMENT       0
#define ATM_TRANSMITTANCE_ATTACHMENT 1
#define ATM_SCATTERING_ATTACHMENT    2

#if defined(__SHADER_TARGET_MAJOR) //Direct3D
#define FloatTexture Texture2D
#define FloatSampler SamplerState
//#define float4 vec4
//#define float3 vec3
//#define float2 vec2
#define constant const
//#define thread out
#define float3_out out float3
#define float_out  out float
#elif defined(SHADERMODEL_ES2) //GLES 2.1
#define FloatTexture texture2D
#define FloatSampler sampler2D
#define float4 vec4
#define float3 vec3
#define float2 vec2
#define static 
#define constant const
//#define thread out
#define float3_out out float3
#define float_out  out float
#elif defined(SHADERMODEL_ES3) //GLES 3.1
#define FloatTexture texture
#define FloatSampler sampler2D
#define float4 vec4
#define float3 vec3
#define float2 vec2
#define static 
#define constant const
#define float3_out out float3
#define float_out  out float
#else                           //METAL 
#define FloatTexture texture2d<float>
#define FloatSampler sampler

#define float3_out thread float3&
#define float_out  thread float&

struct AtmBufferTargets
{
    // color attachment 0
    float4 SKY [[ color(ATM_SKYVIEW_ATTACHMENT) ]];
    float4 T   [[ color(ATM_TRANSMITTANCE_ATTACHMENT) ]];
    float4 MS  [[ color(ATM_SCATTERING_ATTACHMENT) ]];
};
#endif

//Begin Common
static constant float PI = 3.14159265358;

// Units are in megameters.
//const float groundRadiusMM = 6371.;
//const float atmosphereRadiusMM = 6471.;

// Units are in megameters.
static constant float groundRadiusMM = 6.360;
static constant float atmosphereRadiusMM = 6.460;

// 200M above the ground.
//const vec3 viewPos = vec3(0.0, groundRadiusMM + 0.0002, 0.0);

static constant float2 tLUTRes  = float2(512., 512.);// vec2(256.0, 64.0);
static constant float2 msLUTRes = float2(512., 512.);// vec2(32.0, 32.0);
// Doubled the vertical skyLUT res from the paper, looks way
// better for sunrise.
//const vec2 skyLUTRes = vec2(512., 512.);//vec2(512., 256.);

static constant float3 groundAlbedo = float3(0.3, 0.3, 0.3);

// These are per megameter.
static constant float3 rayleighScatteringBase = float3(5.802, 13.558, 33.1);
static constant float rayleighAbsorptionBase = 0.0;

static constant float mieScatteringBase = 3.996;
static constant float mieAbsorptionBase = 4.4;

static constant float3 ozoneAbsorptionBase = float3(0.650, 1.881, .085);

//Output Transmittance LUT Public API
float safeacos(const float x);
float3 getSunTransmittance(float3 pos, float3 sunDir);

//Read Transmittance LUT Public API
float getMiePhase(float cosTheta);
float getRayleighPhase(float cosTheta);

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(float3 ro, float3 rd, float rad);

void getScatteringValues(float3 pos, float3_out rayleighScattering, float_out mieScattering, float3_out extinction);

#if defined(SHADERMODEL_ES2) || defined(SHADERMODEL_ES3) //GLES 2.1 or GLES 3.1
float3 getValFromTLUT(FloatSampler tLUT, float2 bufferRes, float3 pos, float3 sunDir);
#else
float3 getValFromTLUT(FloatTexture tLUT, FloatSampler sampler2D, float2 bufferRes, float3 pos, float3 sunDir);
#endif

#endif //End ATM_H


/*
 * Animates the sun movement.
 */
float getSunAltitude(float time)
{
    const float periodSec = 120.0;
    const float halfPeriod = periodSec / 2.0;
    const float sunriseShift = 0.1;
    float cyclePoint = (1.0 - abs((mod(time, periodSec) - halfPeriod) / halfPeriod));
    cyclePoint = (cyclePoint * (1.0 + sunriseShift)) - sunriseShift;
    return (0.5 * PI) * cyclePoint;
}
vec3 getSunDir(float time)
{
    float altitude = getSunAltitude(time);
    return normalize(vec3(0.0, sin(altitude), -cos(altitude)));
}

float getMiePhase(float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0 / (8.0 * PI);

    float num = (1.0 - g * g) * (1.0 + cosTheta * cosTheta);
    float denom = (2.0 + g * g) * pow((1.0 + g * g - 2.0 * g * cosTheta), 1.5);

    return scale * num / denom;
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0 / (16.0 * PI);
    return k * (1.0 + cosTheta * cosTheta);
}


void getScatteringValues(vec3 pos,
    out vec3 rayleighScattering,
    out float mieScattering,
    out vec3 extinction) {
    float altitudeKM = (length(pos) - groundRadiusMM) * 1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0);
    float mieDensity = exp(-altitudeKM / 1.2);

    rayleighScattering = rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;

    mieScattering = mieScatteringBase * mieDensity;
    float mieAbsorption = mieAbsorptionBase * mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM - 25.0) / 15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}


/*
void getScatteringValues(vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction)
{
    float altitudeKM = (length(pos) - groundRadiusMM);//*1000.0;
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
float rayIntersectSphere(vec3 ro, vec3 rd, float rad)
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



const float sunTransmittanceSteps = 40.0;
vec3 getSunTransmittance(vec3 pos, vec3 sunDir)
{
    if (rayIntersectSphere(pos, sunDir, groundRadiusMM) > 0.0)
    {
        return vec3(0.0);
    }

    float atmoDist = rayIntersectSphere(pos, sunDir, atmosphereRadiusMM);
    float t = 0.0;

    vec3 transmittance = vec3(1.0);
    for (float i = 0.0; i < sunTransmittanceSteps; i += 1.0) {
        float newT = ((i + 0.3) / sunTransmittanceSteps) * atmoDist;
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t * sunDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        transmittance *= exp(-dt * extinction);
    }
    return transmittance;
}

/*
 * Same parameterization here.
 */
vec3 getValFromTLUT(FloatSampler tLUT, vec2 bufferRes, vec3 pos, vec3 sunDir) 
{
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(tLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
        tLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return FloatTexture(tLUT, uv).rgb;
}

//End atm_T.glsl

//Begin atm_MS.glsl

const float mulScattSteps = 20.0;
const int sqrtSamples = 8;

vec3 getSphericalDir(float theta, float phi)
{
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return vec3(sinPhi * sinTheta, cosPhi, sinPhi * cosTheta);
}

// Calculates Equation (5) and (7) from the paper.
void getMulScattValues(sampler2D tLUT, vec3 pos, vec3 sunDir, out vec3 lumTotal, out vec3 fms)
{
    lumTotal = vec3(0.0);
    fms = vec3(0.0);

    float invSamples = 1.0 / float(sqrtSamples * sqrtSamples);
    for (int i = 0; i < sqrtSamples; i++) {
        for (int j = 0; j < sqrtSamples; j++) {
            // This integral is symmetric about theta = 0 (or theta = PI), so we
            // only need to integrate from zero to PI, not zero to 2*PI.
            float theta = PI * (float(i) + 0.5) / float(sqrtSamples);
            float phi = safeacos(1.0 - 2.0 * (float(j) + 0.5) / float(sqrtSamples));
            vec3 rayDir = getSphericalDir(theta, phi);

            float atmoDist = rayIntersectSphere(pos, rayDir, atmosphereRadiusMM);
            float groundDist = rayIntersectSphere(pos, rayDir, groundRadiusMM);
            float tMax = atmoDist;
            if (groundDist > 0.0) {
                tMax = groundDist;
            }

            float cosTheta = dot(rayDir, sunDir);

            float miePhaseValue = getMiePhase(cosTheta);
            float rayleighPhaseValue = getRayleighPhase(-cosTheta);

            vec3 lum = vec3(0.0), lumFactor = vec3(0.0), transmittance = vec3(1.0);
            float t = 0.0;
            for (float stepI = 0.0; stepI < mulScattSteps; stepI += 1.0) {
                float newT = ((stepI + 0.3) / mulScattSteps) * tMax;
                float dt = newT - t;
                t = newT;

                vec3 newPos = pos + t * rayDir;

                vec3 rayleighScattering, extinction;
                float mieScattering;
                getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

                vec3 sampleTransmittance = exp(-dt * extinction);

                // Integrate within each segment.
                vec3 scatteringNoPhase = rayleighScattering + mieScattering;
                vec3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / extinction;
                lumFactor += transmittance * scatteringF;

                // This is slightly different from the paper, but I think the paper has a mistake?
                // In equation (6), I think S(x,w_s) should be S(x-tv,w_s).
                vec3 sunTransmittance = getValFromTLUT(tLUT, tLUTRes, newPos, sunDir);

                vec3 rayleighInScattering = rayleighScattering * rayleighPhaseValue;
                float mieInScattering = mieScattering * miePhaseValue;
                vec3 inScattering = (rayleighInScattering + mieInScattering) * sunTransmittance;

                // Integrated scattering within path segment.
                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                lum += scatteringIntegral * transmittance;
                transmittance *= sampleTransmittance;
            }

            if (groundDist > 0.0) {
                vec3 hitPos = pos + groundDist * rayDir;
                if (dot(pos, sunDir) > 0.0) {
                    hitPos = normalize(hitPos) * groundRadiusMM;
                    lum += transmittance * groundAlbedo * getValFromTLUT(tLUT, tLUTRes, hitPos, sunDir);
                }
            }

            fms += lumFactor * invSamples;
            lumTotal += lum * invSamples;
        }
    }
}


//End atm_MS.glsl



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


// Buffer B is the multiple-scattering LUT. Each pixel coordinate corresponds to a height and sun zenith angle, and
// the value is the multiple scattering approximation (Psi_ms from the paper, Eq. 10).
void main(void)
{
    /*
    if (fragCoord.x >= (msLUTRes.x + 1.5) || fragCoord.y >= (msLUTRes.y + 1.5)) {
        return;
    }
    float u = clamp(fragCoord.x, 0.0, msLUTRes.x - 1.0) / msLUTRes.x;
    float v = clamp(fragCoord.y, 0.0, msLUTRes.y - 1.0) / msLUTRes.y;
    */

    float sunCosTheta = 2.0 * crFragmentTextureUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, crFragmentTextureUV.y);

    vec3 pos = vec3(0.0, height, 0.0);
    vec3 sunDirAlt = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));

    vec3 lum, f_ms;
    getMulScattValues(crSourceTexture, pos, sunDirAlt, lum, f_ms);

    // Equation 10 from the paper.
    vec3 psi = lum / (1.0 - f_ms);
    gl_FragColor = vec4(psi, 1.0);
}