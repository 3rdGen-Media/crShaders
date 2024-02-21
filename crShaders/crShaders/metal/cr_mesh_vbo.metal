//
//  cr_mesh_vbo.metal
//  CRViewer
//
//  Created by Joe Moulton on 2/12/19.
//  Copyright © 2019 Abstract Embedded. All rights reserved.
//

#include <metal_graphics>
#include <metal_matrix>
#include <metal_geometric>
#include <metal_math>
#include <metal_texture>
#include <metal_stdlib>

using namespace metal;
#include "../MtlShaderInterface.h"




vertex MetalRenderVertexOutput cr_mesh_vbo_vert(device crgc_static_vbo* vertex_array [[ buffer(0) ]],
                                                constant Camera& camera [[ buffer(1) ]],
                                                constant Model& model [[ buffer(2) ]],
                                                constant Animation& animation [[ buffer(3) ]],
                                                uint vid [[vertex_id]])
{
    // output transformed geometry data
    MetalRenderVertexOutput shaderOutput;
    
    // get per vertex data
    float4 crVertexPosition = float4(vertex_array[vid].position);
    float4 crVertexNormal = float4(vertex_array[vid].normal);
    uchar4 crVertexJointIndices = uchar4(vertex_array[vid].joints);
    float2 crVertexTextureUV = float2(vertex_array[vid].uv);
    float4 crVertexJointWeights = float4(vertex_array[vid].jointweights);
    //vertexPos.w = 1.0;
    
    //calculate VBO vertex position for static VBOs
    //float4 screenPos = camera.proj * camera.view * model.xform * vertexPos;
    
    float4 vLocalPos = float4( crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);
    float4 totalLocalPos = float4(0.0);


    int jointIndex0 = int( crVertexJointIndices[0]);
    int jointIndex1 = int( crVertexJointIndices[1]);
    int jointIndex2 = int( crVertexJointIndices[2]);
    int jointIndex3 = int( crVertexJointIndices[3]);

    //mat4 jointTransform = crJointTransforms[jointIndex];
    float4 posePosition0 = animation.jointXforms[jointIndex0] * vLocalPos;
    float4 posePosition1 = animation.jointXforms[jointIndex1] * vLocalPos;
    float4 posePosition2 = animation.jointXforms[jointIndex2] * vLocalPos;
    float4 posePosition3 = animation.jointXforms[jointIndex3] * vLocalPos;

    totalLocalPos += posePosition0 * crVertexJointWeights[0];
    totalLocalPos += posePosition1 * crVertexJointWeights[1];
    totalLocalPos += posePosition2 * crVertexJointWeights[2];
    totalLocalPos += posePosition3 * crVertexJointWeights[3];

    float4 vWorldPos  = model.xform * totalLocalPos;
    float4 vViewPos   = camera.view * vWorldPos;
    float4 vScreenPos = camera.proj * vViewPos;
    
    
    //3.1  Calculate the Normal of the the vertex for lighting by multiplying the vertex normal by the "Normal Matrix" in our desired coordinate space for lighting
    // Only correct if ModelMatrix is an orthonormal rotation then transpose(inverse(mat)) == mat so the inverse transpose does not explicitly need to be calculated for non-shear scale.
    float3x3 modelInverseXpose = float3x3(model.xform[0].xyz, model.xform[1].xyz, model.xform[2].xyz);

    //pass through 'varying' variables to fragment shader
    shaderOutput.clipPos     = vScreenPos;
    shaderOutput.fragPos     = vWorldPos;
    shaderOutput.fragNormal  = float4(normalize(modelInverseXpose * crVertexNormal.xyz), 1.0);
    shaderOutput.viewPos     = float4(2000,2000,2000,1.0);//camera.view[3];
    shaderOutput.fragUV      = float2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);//float2(crVertexTextureUV.x, 0.5 + uniforms.crTextureLookupScalar + (uniforms.crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );//crVertexTextureUV.xy;//vec2(crVertexTextureUV.x, crVertexTextureUV.y);
    //shaderOutput.uv *= uniforms.crTextureCoordinateScalar;
    //shaderOutput.pointsize = 10.0;

    //crFragmentTextureUV.xy = vec2(crVertexTextureUV.x, 0.5 + crTextureLookupScalar + (crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );//crVertexTextureUV.xy;//vec2(crVertexTextureUV.x, crVertexTextureUV.y);
    //crFragmentTextureUV *= crTextureCoordinateScalar;
    
    // calculate the incident vector and normal vectors for reflection in the quad's modelview space
    //out.eye = normalize(uniforms.modelview_matrix * float4(position, 1.0));
    //out.eye_normal = normalize(uniforms.modelview_matrix * float4(normal, 0.0)).xyz;
    
    // calculate diffuse lighting with the material color
    //float n_dot_l = dot(out.normal, normalize(light_position));
    //n_dot_l = fmax(0.0, n_dot_l);
    //out.color = half4(1, 0, 0, 1);//half4(copper_ambient) + half4(copper_diffuse * n_dot_l);
    
    return shaderOutput;
}



fragment half4 cr_mesh_vbo_frag(MetalRenderVertexOutput in        [[stage_in]],
                                texture2d<float>        colorMap  [[ texture(0) ]],
                                texture2d<float>        normalMap [[ texture(1) ]],
                                sampler                 sampler2D [[ sampler(0) ]])
                                //constant Camera&        camera    [[ buffer(0) ]])
{
    
    // use the inverted reflection vector to sample from the cube map
    //constexpr sampler s_cube(filter::linear, mip_filter::linear);
    //half4 tex_color = env_tex.sample(s_cube, reflect_world.xyz);
        
    // sample from the 2d textured quad as well
    //1constexpr sampler s_quad(filter::linear);
    //constexpr sampler s_quad(coord::normalized, address::repeat, filter::linear);
    //float2 texCoord = float2( (2.0*in.uv.x*2048. - 1.0)/(2.0*2048.), (2.0*in.uv.y*1032. - 1.0)/(2.0*1032.));
    float4  rgba = colorMap.sample(sampler2D, in.fragUV); //unpack texture to full floating point precision
    float3  map = float3(normalMap.sample(sampler2D, in.fragUV ).xyz);

    //Calculate Tangent Space for Normal
    float3 viewDir = normalize(in.viewPos.xyz - (-in.fragPos.xyz));//normalize(-fragPos.xyz); // the viewer is always at (0,0,0) in view-space, so viewDir is (0,0,0) - Position => -Position
    float3 fragNormal = in.fragNormal.xyz;//perturb_normal(map, in.normal, viewDir, in.uv);//normalize(fragNormal);

    float2 enc = normalize(fragNormal.xy) * (sqrt(-fragNormal.z*0.5 + 0.5));
    enc = enc * 0.5 + 0.5;
    
    float packedNormalXY = pack_vec2_16b( enc );//vec2(enc.x, rgba.r) );

    //vec3 rgbEnc = normalize(rgba.rgb);
    //enc = normalize(rgbEnc.rg) * sqrt(rgbEnc.b*0.5+0.5);
    
    float packedColorRB = pack_vec2_16f( rgba.rb );//vec2(enc.y, rgba.g) );
    
    if(rgba.a < 0.75) discard_fragment();
    //return half4(enc.x, enc.y, packedColorRB, rgba.g);//vec4( (fragNormal.x + 1. ) * 0.5, (fragNormal.y+1.)*0.5, (fragNormal.z + 1.) * 0.5, 1.0);
    return half4(rgba);
}
