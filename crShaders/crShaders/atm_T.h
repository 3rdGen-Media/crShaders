
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
