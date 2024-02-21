// A constant buffer that stores the three basic column-major matrices for composing geometry.
cbuffer Camera : register(b0)
{
	matrix proj;
	matrix view;
	//matrix model;
};

cbuffer Model : register(b1)
{
	matrix model;
};


// Per-vertex data used as input to the vertex shader.
struct VertexShaderInput
{
	float4 pos : POSITION;
	float4 normal : NORMAL;
	float4 weights : WEIGHTS;
	float2 uv : UV;
	uint4  joints: JOINTS;
};

// Per-pixel color data passed through the pixel shader.
struct PixelShaderInput
{
	float4 pos : SV_POSITION;
	float4 color : COLOR0;
	float2 uv : UV;

};



// Simple shader to do vertex processing on the GPU.
PixelShaderInput main(VertexShaderInput input)
{
	PixelShaderInput output;
	float4 pos = input.pos;

	// Transform the vertex position into projected space.
	pos = mul(model, pos);
	pos = mul(view, pos);
	pos = mul(proj, pos);
	output.pos = pos;

	// Pass the color through without modification.
	output.color = input.pos;
	output.uv = float2(input.uv.x, 1.0 - input.uv.y); //input.uv;
	return output;
}
