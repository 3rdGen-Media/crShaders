//
//  cr_gbuffer.h
//  crShaders
//
//  Created by Joe Moulton on 2/17/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

// cr_gbufferHeaders.metal
#ifndef MTLSHADERINTERFACE_H
#define MTLSHADERINTERFACE_H

#define MAX_JOINTS 256

struct MetalRenderVertexOutput
{
    float4 clipPos [[position]];    //clip space vertex shader output
    float4 fragPos;                 //lighting space vert position for frag shader
    float4 fragNormal;
    float4 viewPos;
    float4 sunDir;
    float2 fragUV;
    //float pointsize[[point_size]];
};

//All members must be 16 byte aligned
//iOS does not support wide uchar8 alignment
typedef struct
{
    packed_float4 position;
    packed_float4 normal;
    packed_float4 jointweights;
    packed_float2 uv;
    packed_uchar4 joints;
    
} crgc_static_vbo;

typedef struct Camera
{
    float4x4 proj;
    float4x4 view;
    float4   viewport;
    float4   pos;
    float4   sun;
    float4   moon;
}camera;

typedef struct Model
{
    float4x4 xform;
} model;


typedef struct Animation
{
    //per object/draw call input array of joint transforms
    float4x4 jointXforms[MAX_JOINTS];
} animation;



float pack_vec2_16b(float2 src);
float pack_vec2_16f(float2 src);

float3x3 cotangent_frame(float3 N, float3 p, float2 uv);
float3 perturb_normal(float3 map, float3 N, float3 V, float2 texcoord);

//float2 unpack_vec2_16b(float src); //unpack vec2_16b
//half2 unpack_16f_vec2(half src);   //unpack vec2_16f


#endif /* CR_GBUFFER_H */
