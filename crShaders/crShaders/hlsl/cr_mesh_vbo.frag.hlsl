// Per-pixel color data passed through the pixel shader.
struct PixelShaderInput
{
	float4 pos : SV_POSITION;
	float4 color : COLOR0;
	float2 uv : UV;
};

SamplerState SAMPLER   : register(s0);	//The single static sampler was embedded in the RootSignature
Texture2D MESH_TEXTURE : register(t0);	//The PBR Mesh Textures were bound during Draw calls submission

// A pass-through function for the (interpolated) color data.
float4 main(PixelShaderInput input) : SV_TARGET
{
	//return float4(input.uv.x, 1.0-input.uv.y, 0.0,1.0);// input.color;

	float4 rgba = MESH_TEXTURE.Sample(SAMPLER, input.uv);
	if (rgba.a < 0.75) discard;
	
	return rgba;
}
