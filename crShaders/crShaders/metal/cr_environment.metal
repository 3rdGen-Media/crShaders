//
//  cr_environment.metal
//  crShaders
//
//  Created by Joe Moulton on 1/20/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_graphics>
#include <metal_matrix>
#include <metal_geometric>
#include <metal_math>
#include <metal_texture>
#include <metal_stdlib>

using namespace metal;
#include "../MtlShaderInterface.h"
#include "../atm_T.h"


vertex MetalRenderVertexOutput cr_env_vert(device crgc_static_vbo* vertex_array [[ buffer(0) ]],
                                                constant Camera& camera [[ buffer(1) ]],
                                                constant Model& model [[ buffer(2) ]],
                                                constant Animation& animation [[ buffer(3) ]],
                                                uint vid [[vertex_id]])
{
    // output transformed geometry data
    MetalRenderVertexOutput shaderOutput;
    
    // get per vertex data
    float4 crVertexPosition     = float4(vertex_array[vid].position);
    float4 crVertexNormal       = float4(vertex_array[vid].normal);
    uchar4 crVertexJointIndices = uchar4(vertex_array[vid].joints);
    float2 crVertexTextureUV    = float2(vertex_array[vid].uv);
    float4 crVertexJointWeights = float4(vertex_array[vid].jointweights);
        
    float4 vLocalPos = float4( crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);

    /*
    //calculate vertex position for animated VBOs
    int jointIndex0 = int( crVertexJointIndices[0]);
    int jointIndex1 = int( crVertexJointIndices[1]);
    int jointIndex2 = int( crVertexJointIndices[2]);
    int jointIndex3 = int( crVertexJointIndices[3]);

    float4 posePosition0 = animation.jointXforms[jointIndex0] * vLocalPos;
    float4 posePosition1 = animation.jointXforms[jointIndex1] * vLocalPos;
    float4 posePosition2 = animation.jointXforms[jointIndex2] * vLocalPos;
    float4 posePosition3 = animation.jointXforms[jointIndex3] * vLocalPos;

    float4 totalLocalPos = float4(0.0);
    totalLocalPos += posePosition0 * crVertexJointWeights[0];
    totalLocalPos += posePosition1 * crVertexJointWeights[1];
    totalLocalPos += posePosition2 * crVertexJointWeights[2];
    totalLocalPos += posePosition3 * crVertexJointWeights[3];
    */
    
    float4 vWorldPos  = model.xform * vLocalPos;
    float4 vViewPos   = camera.view * vWorldPos;
    float4 vScreenPos = camera.proj * vViewPos;
    
    
    //float3 normal = float3(vertex_array[vid].normal);
    
    
    //pass through 'varying' variables to fragment shader
    shaderOutput.clipPos    = vScreenPos.xyww;
    shaderOutput.fragPos    = vWorldPos;
    shaderOutput.fragNormal = crVertexNormal;
    shaderOutput.viewPos    = camera.pos;//float4(0,0,0,1);
    shaderOutput.sunDir     = camera.sun;//float4(0,0,-1,1);
    shaderOutput.fragUV     = float2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);
    //float2(crVertexTextureUV.x, 0.5 + uniforms.crTextureLookupScalar + (uniforms.crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );//crVertexTextureUV.xy;//vec2(crVertexTextureUV.x, crVertexTextureUV.y);
    //shaderOutput.uv *= uniforms.crTextureCoordinateScalar;
    //shaderOutput.pointsize = 10.0;

    
    // calculate the incident vector and normal vectors for reflection in the quad's modelview space
    //out.eye = normalize(uniforms.modelview_matrix * float4(position, 1.0));
    //out.eye_normal = normalize(uniforms.modelview_matrix * float4(normal, 0.0)).xyz;
    
    // calculate diffuse lighting with the material color
    //float n_dot_l = dot(out.normal, normalize(light_position));
    //n_dot_l = fmax(0.0, n_dot_l);
    //out.color = half4(1, 0, 0, 1);//half4(copper_ambient) + half4(copper_diffuse * n_dot_l);
    
    return shaderOutput;
}




float3 getValFromSkyLUT(texture2d<float> skyLUT, sampler sampler2D,  float3 rayDir, float3 sunDir, float3 viewPos)
{
    float  height = length(viewPos);
    float3 up = viewPos / height;

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height);
    float altitudeAngle = horizonAngle - acos(dot(rayDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI
    if (abs(altitudeAngle) > (0.5 * PI - .0001)) {
        // Looking nearly straight up or down.
        azimuthAngle = 0.0;
    }
    else {
        float3 right = cross(sunDir, up);
        float3 forward = cross(up, right);

        float3 projectedDir = normalize(rayDir - up * (dot(rayDir, up)));
        float  sinTheta = dot(projectedDir, right);
        float  cosTheta = dot(projectedDir, forward);
        azimuthAngle = atan2(sinTheta, cosTheta) + PI; //HLSL atan2(y,x) == GLSL atan(y,x)
    }

    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
    float2 uv = float2(azimuthAngle / (2.0 * PI), v);
    //uv *= skyLUTRes;
    //uv /= skyLUTRes;// iChannelResolution[1].xy;

    return skyLUT.sample(sampler2D, uv).rgb;
}

float3 jodieReinhardTonemap(float3 c)
{
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

float3 sunWithBloom(float3 rayDir, float3 sunDir)
{
    const float sunSolidAngle = 0.53 * PI / 180.0;
    const float minSunCosTheta = cos(sunSolidAngle);

    float cosTheta = dot(rayDir, sunDir);
    if (cosTheta >= minSunCosTheta) return float3(1.0, 1.0, 1.0);

    float offset = minSunCosTheta - cosTheta;
    float gaussianBloom = exp(-offset * 50000.0) * 0.5;
    float invBloom = 1.0 / (0.02 + offset * 300.0) * 0.01;
    float totalBloom = gaussianBloom + invBloom;
    return float3(totalBloom, totalBloom, totalBloom);
}



fragment half4 cr_env_frag(MetalRenderVertexOutput   in        [[ stage_in   ]],
                           texture2d<float>          skyLUT    [[ texture(0) ]],
                           texture2d<float>          tLUT      [[ texture(1) ]],
                           sampler                   sampler2D [[ sampler(0) ]])
                           //texture2d<float>        colorMap  [[ texture(0) ]],
                           //texture2d<float>        normalMap [[ texture(1) ]],

                           //texturecube<float>      texture   [[ texture(0) ]], //always sample environment cubemaps with full floating point precision
                           //sampler                 sampler3D [[ sampler(0) ]])
                           //constant Camera&        camera    [[ buffer(0) ]])
{
    
    const float3 camPos = float3(0.0, groundRadiusMM + 0.0002, 0.0);

    //skydome sphere is always centered on camera so the ray
    //into the sky LUT is just the normal of the sphere
    float3 rayDir = in.fragNormal.xyz;
    float3 lum = 0.0;

    //float altitudeKM = (length(camPos + viewPos) - groundRadiusMM);//*1000.0;
    if (1>0)//length(camPos + viewPos) < atmosphereRadiusMM * 10.)
    {
        lum = getValFromSkyLUT(skyLUT, sampler2D, rayDir, in.sunDir.xyz, camPos);
        // Draw Sun
        // Bloom should be added at the end, but this is subtle and works well.
        float3 sunLum = sunWithBloom(in.fragNormal.xyz, in.sunDir.xyz);

        // Use smoothstep to limit the effect, so it drops off to actual zero.
        sunLum = smoothstep(0.002, 1.0, sunLum);
        if (length(sunLum) > 0.0)
        {
            if (rayIntersectSphere(camPos, rayDir, groundRadiusMM) >= 0.0)
            {
                sunLum *= 0.0;
            }
            else
            {
                // If the sun value is applied to this pixel, we need to calculate the transmittance to obscure it.
                sunLum *= getValFromTLUT(tLUT, sampler2D, tLUTRes, camPos, in.sunDir.xyz);
                //rgba = vec4(rgba.xyz + sunLum, rgba.a);
            }
        }
        lum += sunLum;
    }
    else
    {

        // As mentioned in section 7 of the paper, switch to direct raymarching outside atmosphere
        //lum = raymarchScattering(crSourceTexture, tLUTRes, crNormalTexture, skyLUTRes,
        //                         camPos, rayDir, sunDir, float(numScatteringSteps));

        // This little bit of red helps to debug when the rendering switches to pure raymarching
        //lum = vec3(0,0.0,0.0);
    }

    // Tonemapping and gamma. Super ad-hoc, probably a better way to do this.
    lum *= 20.0;
    lum = pow(lum, float3(1.3, 1.3, 1.3));
    lum /= (smoothstep(0.0, 0.2, clamp(in.sunDir.y, 0.0, 1.0)) * 2.0 + 0.15);

    lum = jodieReinhardTonemap(lum);
    //lum = pow(lum, vec3(1.0 / 2.2)); //gamma resolve is done automatically at the end of frame render pass

    return half4(lum.x, lum.y, lum.z, 1.0);
    
    /*
    // sample from the cubemap
    //float2 d = 2.0 * ( ( float2(idx.x, idx.y) + float2(0.5,0.5) ) / float2(width, height) ) - 1.0;
    //float3 texCoords = float3(in.fragNormal.x, in.fragNormal.y, -in.fragNormal.z);
    //float4 rgba = texture.sample(sampler3D, texCoords);
    float4 rgba = colorMap.sample(sampler2D, in.fragUV);
   
    
    //if(image_color.a < 0.75) discard_fragment();
    //if(image_color.a < 0.75) discard_fragment();
    //return half4(enc.x, enc.y, packedColorRB, rgba.g);//vec4( (fragNormal.x + 1. ) * 0.5, (fragNormal.y+1.)*0.5, (fragNormal.z + 1.) * 0.5, 1.0);
    return half4(rgba);
    */
}
