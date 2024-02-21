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


uniform highp sampler2D crSourceTexture;
uniform highp sampler2D crNormalTexture;

varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;

//varying mat4 projectionViewMatrix;
varying mat4 inverseProjectionViewMatrix;


varying vec4 viewport;
//varying vec4 sunDir;


//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;
varying vec4 fragPos;
//varying vec4 viewPos;
varying vec4 lightPos;
//varying vec3 sunDirection;

//The 2 varyings that are needed to calculate cosTheta for lighting calculations
varying vec3 vertexNormal;

//varying mat3 TBN;

//Texture Lookup Values from vertex shader
varying vec2 crFragmentTextureUV;


// Buffer A generates the Transmittance LUT. Each pixel coordinate corresponds to a height and sun zenith angle, 
// and the value is the transmittance from that point to sun, through the atmosphere.
void main(void)
{
    /*
    if (crFragmentTextureUV.x >= (tLUTRes.x + 1.5) || crFragmentTextureUV.y >= (tLUTRes.y + 1.5)) 
    {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, tLUTRes.x - 1.0) / tLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, tLUTRes.y - 1.0) / tLUTRes.y;
    */

    float sunCosTheta = 2.0 * crFragmentTextureUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, crFragmentTextureUV.y);

    vec3 pos = vec3(0.0, height, 0.0);
    vec3 sunDirAlt = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));

    gl_FragColor = vec4(getSunTransmittance(pos.xyz, sunDirAlt), 1.0);
}
