// A constant buffer that stores the three basic column-major matrices for composing geometry.
cbuffer Camera : register(b0)
{
	matrix proj;
	matrix view;
	float4 viewport;
	float4 pos;
	float4 sun;
	float4 moon;
};

cbuffer Model : register(b1)
{
	matrix model;
};

cbuffer Animation : register(b2)
{
	matrix jointXforms[256];
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
	float4 fragPos    : SV_POSITION;
	float4 fragNormal : NORMAL;
	float4 viewPos	  : COLOR0;
	float4 sunDir	  : COLOR1;
	float2 fragUV	  : UV;
};


// Simple shader to do vertex processing on the GPU.
PixelShaderInput main(VertexShaderInput input)
{
	PixelShaderInput output;
	float4 vLocalPos = input.pos; //vec4(crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);

	/********* Skeletal Keyframe Animation **********/
	/*
	int jointIndex0 = int(input.joints[0]);
	int jointIndex1 = int(input.joints[1]);
	int jointIndex2 = int(input.joints[2]);
	int jointIndex3 = int(input.joints[3]);

	float4 posePosition0 = mul(jointXforms[jointIndex0], vLocalPos);
	float4 posePosition1 = mul(jointXforms[jointIndex1], vLocalPos);
	float4 posePosition2 = mul(jointXforms[jointIndex2], vLocalPos);
	float4 posePosition3 = mul(jointXforms[jointIndex3], vLocalPos);

	float4 totalLocalPos = float4(0.0, 0.0, 0.0, 0.0);
	totalLocalPos += posePosition0 * input.weights[0];
	totalLocalPos += posePosition1 * input.weights[1];
	totalLocalPos += posePosition2 * input.weights[2];
	totalLocalPos += posePosition3 * input.weights[3];
	*/

	// Transform the vertex position into projected space.
	float4 vWorldPos  = mul(model, vLocalPos);
	float4 vViewPos   = mul(view, vWorldPos);
	float4 vScreenPos = mul(proj, vViewPos);

	output.fragPos     = vScreenPos;
	output.fragNormal  = input.normal;
	output.viewPos     = pos;
	output.sunDir      = sun;
	output.fragUV	   = float2(input.uv.x, 1.0 - input.uv.y); //input.uv;

	return output;
}
