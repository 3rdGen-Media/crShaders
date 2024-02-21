//
//  cr_gbuffer.metal
//  crShaders
//
//  Created by Joe Moulton on 12/29/23.
//  Copyright © 2023 Abstract Embedded. All rights reserved.
//

#include <metal_graphics>
#include <metal_matrix>
#include <metal_geometric>
#include <metal_math>
#include <metal_texture>
#include <metal_stdlib>

using namespace metal;
#include "../MtlShaderInterface.h"


/*
 *  Vertex Shader:  Render to 3D Space Quad Vertices
 */
vertex MetalRenderVertexOutput cr_gbuffer_vert(device crgc_static_vbo* vertex_array [[ buffer(0) ]],
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

    /********* Skeletal Keyframe Animation **********/

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
    
    
    //float3 normal = float3(vertex_array[vid].normal);
    
    
    //pass through 'varying' variables to fragment shader
    shaderOutput.clipPos    = vScreenPos;
    shaderOutput.fragPos    = vWorldPos;
    shaderOutput.fragNormal = crVertexNormal;
    shaderOutput.fragNormal = crVertexNormal;
    //shaderOutput.viewPos  = float4(2000,2000,2000,1.0);//camera.view[3];
    //shaderOutput.sunDir   = crVertexNormal;
    shaderOutput.fragUV     = float2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);
    

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

float2 unpack_vec2_16b(float src)
{
    float src2 = src * 65535.0;
    float2 dec = float2(src2/256./255.,  src2*256./256./255.);
    return dec;
}

//unpack:    f2=frac(res);    f1=(res-f2)/1000;    f1=(f1-0.5)*2;f2=(f2-0.5)*2;
half2 unpack_16f_vec2(half src)
{
    float2 o;
    float fFrac = fract(src);
    o.y = fFrac/0.8;//(fFrac - 0.4)*2.5;
    o.x = (src-fFrac)/100.;// - 0.5)*2.;
    return half2(o);
}


/*
 *  Fragment Shader:  Render a Metal Texture to 3D Mehs Geometry
 */
fragment half4 cr_gbuffer_frag(MetalRenderVertexOutput in      [[stage_in]],
                                  texture2d<float>      texture [[ texture(0) ]])
                                  //constant Camera&      camera  [[ buffer(0) ]])
{
    // get reflection vector
    //float3 reflect_dir = reflect(in.eye.xyz, in.eye_normal);
    
    // return reflection vector to world space
    //float4 reflect_world = uniforms.inverted_view_matrix * float4(reflect_dir, 0.0);
    
    // use the inverted reflection vector to sample from the cube map
    //constexpr sampler s_cube(filter::linear, mip_filter::linear);
    //half4 tex_color = env_tex.sample(s_cube, reflect_world.xyz);
    
    //float2 crVertexTextureUV = float2(in.uv.x, 1.0-in.uv.y);
    
    // sample from the 2d textured quad as well
    
    //When sampling from floating point offscreen buffers it is imperative that min_filter be set to nearest when the Metal Layer is being composited to the desktop
    //minFilter -- The filtering option for combining pixels within one mipmap level when the sample footprint is larger than a pixel (minification)
    //magFilter -- The filtering operation for combining pixels within one mipmap level when the sample footprint is smaller than a pixel (magnification).
    //mipFilter -- The filtering option for combining pixels between two mipmap levels.
    constexpr sampler sampler2D(coord::normalized, address::clamp_to_edge, min_filter::linear, mag_filter::linear, mip_filter::linear);
    float4 rgba = texture.sample(sampler2D, in.fragUV);
    //half4 firstColor = tex.read(uint2(0,0));
    
    //float magLogN = log( length( firstColor.rg ) + 1.0f );
    //float magLog = log( length( image_color.rg ) + 1.0f );
    
    //float out = magLog/(magLogN*2.0f);
    //half4 outColor = half4(out, out, out, 1);
    // combine with texture, light, and envmap reflaction
    //half4 color = mix(in.color, image_color, 0.9h);
    //color = mix(tex_color, color, 0.6h);
    
    // RGB to grayscale
    //half color = dot(image_color.rgb, half3(0.30h, 0.59h, 0.11h));
    //half4 color = image_color;
    
    //half4 outColor = half4(color, color, color, 1.0);
    
    //float color = image_color.r ;/// firstColor.r;
    //half4 outColor = half4(1.0, 0.0,0.0,1.0);//half4(in.color.r, in.color.g, in.color.b,1.0);//image_color;//half4(color, color, color, 1.0);
    
    //Unpack geometry normal from gbuffer texture sample
    half2 unpackedNormalXY =   half2(rgba.r, rgba.g);//unpack_vec2_16b(rgba.r);
    //Unpack geometry diffuse color from gbuffer texture sample
    half2 unpackedColorRB =    unpack_16f_vec2(rgba.b);
    //vec2 unpackedColorBA =    unpack_vec2_16b(rgba.b);
    
    //vec2 unpackedNormalXY = vec2(unpackedNormalXR.x, unpackedColorYG.x);
    //vec2 unpackedColorRG = vec2(unpackedNormalXR.y, unpackedColorYG.y);
    //vec2 unpackedColorBA = vec2(unpackedColorZB.y, 1.0);
    
    //Decode Normal as Sphere Map
    //vec3 fragNormal = vec3( unpackedNormalXY, length2(unpackedNormalXY) * 2. - 1. );
    //fragNormal.xy = normalize(unpackedNormalXY) * sqrt(1. - fragNormal.z * fragNormal.z);
    
    //vec2 two = vec2(2.,2.);
    float2 fenc = float2(unpackedNormalXY) * 4. - 2.;
    float f = dot(fenc,fenc);
    float g = sqrt(1.-f/4.);
    float3 fragNormal;
    fragNormal.xy = fenc*g;
    fragNormal.z = 1.-f/2.;
    
    
    //vec2 angles = unpackedNormalXY * 2.0 - 1.0;
    //vec2 theta = vec2( sin(angles.x * M_PI), cos(angles.x*M_PI) );
    //sincos( angles.x * PI, theta.x, theta.y );
    //vec2 phi = vec2( sqrt( 1.0 - angles.y * angles.y ), angles.y );
    //vec3 fragNormal = vec3( theta.y * phi.x, theta.x * phi.x, phi.y );
    
    //vec3 fragNormal = vec3(unpackedNormalXY, length(unpackedNormalXY) * 2. - 1.);//vec3( unpackedNormalXY, sqrt(1.0 - (unpackedNormalXY.x * unpackedNormalXY.x + unpackedNormalXY.y * unpackedNormalXY.y)) );
    //fragNormal = normalize(fragNormal);
    //fragNormal.xy = normalize(unpackedNormalXY.xy) * sqrt(1. - fragNormal.z * fragNormal.z);
    
    
    
    //fragNormal.z = rgba.a;//(rgba.a/2.) - 1.0;
    half4 diffuseColor = half4(unpackedColorRB.x, rgba.a, unpackedColorRB.y, 1.0);
    
    
    //return image_color;
    return half4(rgba.x, rgba.y, rgba.z, 1.);//diffuseColor;
}


