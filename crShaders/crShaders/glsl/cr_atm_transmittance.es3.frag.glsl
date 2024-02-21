#version 310 es

#ifdef GL_ES
precision highp float;
#else
#define highp
#define mediump
#define lowp
#endif

#define SHADERMODEL_ES3
#include "atm_T.glsl"


layout(location = 0) in  vec4 fragPos;
layout(location = 1) in  vec4 fragNormal;
layout(location = 2) in  vec4 viewPos;
layout(location = 3) in  vec4 sunDir;
layout(location = 4) in  vec2 fragUV;

layout(location = 0) out vec4 outColor;

//layout(set = 1, binding = 0) uniform samplerCube  MESH_TEXTURES[1];
//layout(set = 1, binding = 0) uniform sampler2D MESH_TEXTURES[2];

// Buffer A generates the Transmittance LUT. Each pixel coordinate corresponds to a height and sun zenith angle, 
// and the value is the transmittance from that point to sun, through the atmosphere.
void main()
{
    /*
    if (crFragmentTextureUV.x >= (tLUTRes.x + 1.5) || crFragmentTextureUV.y >= (tLUTRes.y + 1.5))
    {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, tLUTRes.x - 1.0) / tLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, tLUTRes.y - 1.0) / tLUTRes.y;
    */

    float sunCosTheta = 2.0 * fragUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, fragUV.y);

    vec3 pos = vec3(0.0, height, 0.0);
    vec3 sunDirAlt = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));

    outColor = vec4(getSunTransmittance(pos.xyz, sunDirAlt), 1.0);
}
