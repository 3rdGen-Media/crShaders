//
//  MtlShaderInterface.metal
//  crShaders
//
//  Created by Joe Moulton on 2/17/24.
//  Copyright © 2024 Abstract Embedded. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
#include "../MtlShaderInterface.h"


float pack_vec2_16b(float2 src)
{
   const float fromFixed = 255.0/256.;
   float enc = src.x * fromFixed * 256. * 255. + src.y * fromFixed * 255.;
   return enc/65535.;
}
            

float pack_vec2_16f(float2 src)
{
    return floor(src.x * 100.)+(src.y * 0.8);
}

// "Followup: Normal Mapping Without Precomputed Tangents" from http://www.thetenthplanet.de/archives/1180
float3x3 cotangent_frame( float3 N, float3 p, float2 uv )
{
    /* get edge vectors of the pixel triangle */
    float3 dp1 = dfdx( p );
    float3 dp2 = dfdy( p );
    float2 duv1 = dfdx( uv );
    float2 duv2 = dfdy( uv );

    /* solve the linear system */
    float3 dp2perp = cross( dp2, N );
    float3 dp1perp = cross( N, dp1 );
    float3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    float3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    /* construct a scale-invariant frame */
    float invmax = rsqrt( max( dot(T,T), dot(B,B) ) );
    return float3x3( T * invmax, B * invmax, N );
}

float3 perturb_normal( float3 map, float3 N, float3 V, float2 texcoord )
{
    /* assume N, the interpolated vertex normal and V, the view vector (vertex to eye) */
    //float3 map = texture2D( crNormalTexture, texcoord ).xyz;
    // WITH_NORMALMAP_UNSIGNED
    //map = normalize(map);
    //map = map * 2.0 - 1.0;

    map = map * 255./127. - 128./127.;
    map = normalize(map);
    
    // WITH_NORMALMAP_2CHANNEL
    // map.z = sqrt( 1. - dot( map.xy, map.xy ) );
    // WITH_NORMALMAP_GREEN_UP
    // map.y = -map.y;
    float3x3 TBN = cotangent_frame( N, -V, texcoord );
    return normalize( TBN * map );
}

