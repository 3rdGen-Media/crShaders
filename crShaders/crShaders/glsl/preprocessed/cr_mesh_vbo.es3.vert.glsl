#version 310 es

//#ifdef GL_ES
//precision highp float;
//precision highp int;
//#else
//#define highp
//#define mediump
//#define lowp
//#endif

const int MAX_JOINTS = 256;

//cr_vertex_mesh_vbo input attributes for PBR rendering and animation
//attribute vec4 crVertexPosition;
//attribute vec4 crVertexNormal;
//attribute vec4 crVertexJointWeights;
//attribute vec2 crVertexTextureUV;
//attribute vec4 crVertexJointIndices;

//per object/draw call input array of joint transforms
//uniform mat4 crJointTransforms[MAX_JOINTS];

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

layout(binding = 0) uniform Camera 
{
    mat4 proj;
    mat4 view;
    vec4 viewport;
    vec4 pos;
    vec4 sun;
    vec4 moon;
} camera;

layout (binding = 1) uniform Model 
{
	mat4 xform;
} model;

layout (binding = 2) uniform Animation 
{
    //per object/draw call input array of joint transforms
    mat4 jointXforms[MAX_JOINTS];
} animation;


layout(location = 0) in vec4  crVertexPosition;
layout(location = 1) in vec4  crVertexNormal;
layout(location = 2) in vec4  crVertexJointWeights;
layout(location = 3) in vec2  crVertexTextureUV;
layout(location = 4) in uvec4 crVertexJointIndices;

layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec2 fragUV;

void main() 
{    
    vec4 vLocalPos = vec4( crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);    
    vec4 totalLocalPos = vec4(0.0);

    /********* Skeletal Keyframe Animation **********/

    int jointIndex0 = int( crVertexJointIndices[0]);
    int jointIndex1 = int( crVertexJointIndices[1]);
    int jointIndex2 = int( crVertexJointIndices[2]);
    int jointIndex3 = int( crVertexJointIndices[3]);

    //mat4 jointTransform = crJointTransforms[jointIndex];
    vec4 posePosition0 = animation.jointXforms[jointIndex0] * vLocalPos;
    vec4 posePosition1 = animation.jointXforms[jointIndex1] * vLocalPos;
    vec4 posePosition2 = animation.jointXforms[jointIndex2] * vLocalPos;
    vec4 posePosition3 = animation.jointXforms[jointIndex3] * vLocalPos;

    totalLocalPos += posePosition0 * crVertexJointWeights[0];
    totalLocalPos += posePosition1 * crVertexJointWeights[1];
    totalLocalPos += posePosition2 * crVertexJointWeights[2];
    totalLocalPos += posePosition3 * crVertexJointWeights[3];

    vec4 vWorldPos  = model.xform * totalLocalPos;
    vec4 vViewPos   = camera.view * vWorldPos;
    vec4 vScreenPos = camera.proj * vViewPos;

    /*
    if(vScreenPos.w != 0.0)
    {
        vScreenPos.x /= vScreenPos.w;
        vScreenPos.y /= vScreenPos.w;
        vScreenPos.z /= vScreenPos.w;
    }
    */

    /********* Vertex Position **********/

    gl_Position = vScreenPos;

    //gl_Position = camera.proj * camera.view * model.xform * crVertexPosition;
    fragColor = vec4(crVertexTextureUV.x, crVertexTextureUV.y, 0., 1.);//crVertexNormal;

    //fragUV = vec2(crVertexTextureUV.x, 0.5 + crTextureLookupScalar + (crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );
    fragUV = vec2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);
}
