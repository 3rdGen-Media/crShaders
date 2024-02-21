#include "atm_T.hlsl"

float3 getValFromSkyLUT(Texture2D TEX, SamplerState SAMPLER, float3 rayDir, float3 sunDir, float3 viewPos)
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

    return TEX.Sample(SAMPLER, uv).rgb;
}

float3 jodieReinhardTonemap(float3 c)
{
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, float3(0.2126, 0.7152, 0.0722));
    float3 tc = c / (c + 1.0);
    return lerp(c / (l + 1.0), tc, tc);
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


// Per-pixel color data passed through the pixel shader.
struct PixelShaderInput
{
	float4 fragPos    : SV_POSITION;
	float4 fragNormal : NORMAL;
	float4 viewPos	  : COLOR0;
	float4 sunDir	  : COLOR1;
	float2 fragUV	  : UV;
};

SamplerState SAMPLER	      : register(s0);	//The single static sampler was embedded in the RootSignature
//TextureCube  MESH_TEXTURE   : register(t0);	//The Cubemap Mesh Texture was bound during Draw call submission
Texture2D    MESH_TEXTURES[2] : register(t0);	//The PBR Mesh Textures were bound during Draw calls submission

// A pass-through function for the (interpolated) color data.
float4 main(PixelShaderInput input) : SV_TARGET
{
	const float3 camPos = float3(0.0, groundRadiusMM + 0.0002, 0.0);

    //skydome sphere is always centered on camera so the ray 
    //into the sky LUT is just the normal of the sphere
    float3 rayDir = input.fragNormal.xyz;
    float3 lum;

    //float altitudeKM = (length(camPos + viewPos) - groundRadiusMM);//*1000.0;
    if (1>0)//length(camPos + viewPos) < atmosphereRadiusMM * 10.) 
    {
        lum = getValFromSkyLUT(MESH_TEXTURES[0], SAMPLER, rayDir, input.sunDir.xyz, camPos);
        // Draw Sun
        // Bloom should be added at the end, but this is subtle and works well.
        float3 sunLum = sunWithBloom(input.fragNormal.xyz, input.sunDir.xyz);

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
                sunLum *= getValFromTLUT(MESH_TEXTURES[1], SAMPLER, tLUTRes, camPos, input.sunDir.xyz);
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
    lum /= (smoothstep(0.0, 0.2, clamp(input.sunDir.y, 0.0, 1.0)) * 2.0 + 0.15);

    lum = jodieReinhardTonemap(lum);
    //lum = pow(lum, vec3(1.0 / 2.2)); //gamma resolve is done automatically at the end of frame render pass

    return float4(lum, 1.0);

    /*
	//float3 texCoord = float3(input.fragNormal.x, input.fragNormal.y, -input.fragNormal.z);
	//float4 rgba = MESH_TEXTURE.Sample(SAMPLER, texCoord);
	float4 rgba = MESH_TEXTURES[0].Sample(SAMPLER, input.fragUV);

	if (rgba.a < 0.75) discard;
	return rgba;
    */
}
