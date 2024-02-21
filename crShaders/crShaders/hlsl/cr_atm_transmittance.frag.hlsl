#include "atm_T.hlsl"

//the equivalent of glsl mod as hlsl fmod is not suitable for negative inputs
float mod(float x, float y)
{
    return x - y * floor(x / y);
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

SamplerState SAMPLER	      : register(s0);	 //The single static sampler was embedded in the RootSignature
Texture2D    MESH_TEXTURES[1] : register(t0);	//The PBR Mesh Textures were bound during Draw calls submission
//TextureCube  MESH_TEXTURE  : register(t0);	 //The Cubemap Mesh Texture was bound during Draw call submission

// Buffer A generates the Transmittance LUT. Each pixel coordinate corresponds to a height and sun zenith angle, 
// and the value is the transmittance from that point to sun, through the atmosphere.
float4 main(PixelShaderInput input) : SV_TARGET
{
    /*
    if (crFragmentTextureUV.x >= (tLUTRes.x + 1.5) || crFragmentTextureUV.y >= (tLUTRes.y + 1.5))
    {
        return;
    }
    float u = clamp(crFragmentTextureUV.x, 0.0, tLUTRes.x - 1.0) / tLUTRes.x;
    float v = clamp(crFragmentTextureUV.y, 0.0, tLUTRes.y - 1.0) / tLUTRes.y;
    */

    float sunCosTheta = 2.0 * input.fragUV.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = lerp(groundRadiusMM, atmosphereRadiusMM, input.fragUV.y);

    float3 pos = float3(0.0, height, 0.0);
    float3 sunDirAlt = normalize(float3(0.0, sunCosTheta, -sin(sunTheta)));

    return float4(getSunTransmittance(pos.xyz, sunDirAlt), 1.0);

    /*
	float3 texCoord = float3(input.fragNormal.x, input.fragNormal.y, -input.fragNormal.z);
	float4 rgba = MESH_TEXTURE.Sample(SAMPLER, texCoord);
	if (rgba.a < 0.75) discard;
	return rgba;
    */
}