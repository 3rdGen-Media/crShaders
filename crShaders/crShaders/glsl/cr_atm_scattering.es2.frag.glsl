
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
#include "atm_MS.glsl"


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