#version 310 es

//#ifdef GL_ES
//precision highp float;
//precision highp int;
//#else
//#define highp
//#define mediump
//#define lowp
//#endif

//const int MAX_JOINTS = 200;

//cr_vertex_mesh_vbo input attributes for PBR rendering and animation
//attribute vec4 crVertexPosition;
//attribute vec4 crVertexNormal;
//attribute vec4 crVertexJointWeights;
//attribute vec2 crVertexTextureUV;
//attribute vec4 crVertexJointIndices;



//global uniform attributes
//uniform float crVertexXOffset;
//uniform float crVertexYOffset;

//uniform float crTextureLookupScalar;
//uniform float crTextureCoordinateScalar;

//uniform vec3 crViewPosition;
//uniform vec3 crLightPosition;
//uniform vec3 crSunDirection;

//uniform vec4 crViewport;

//float crTextureLookupScalar = 0.5f;

layout(binding = 0) uniform UniformBufferObject 
{
    mat4 proj;
    mat4 view;
    vec4 viewport;
    vec4 pos;
    vec4 sun;
    vec4 moon;
} ubo;

layout (binding = 1) uniform UboInstance 
{
	mat4 model;
} uboInstance;

layout(location = 0) in vec4  crVertexPosition;
layout(location = 1) in vec4  crVertexNormal;
layout(location = 2) in vec4  crVertexJointWeights;
layout(location = 3) in vec2  crVertexTextureUV;
layout(location = 4) in uvec4 crVertexJointIndices;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec2 fragUV;

void main() 
{
    gl_Position = ubo.proj * ubo.view * uboInstance.model * crVertexPosition;
    fragColor = vec4(crVertexTextureUV.x, crVertexTextureUV.y, 0., 1.);//crVertexNormal;

    //fragUV = vec2(crVertexTextureUV.x, 0.5 + crTextureLookupScalar + (crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );
    fragUV = vec2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);
}
