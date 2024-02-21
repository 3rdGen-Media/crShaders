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

layout(binding = 1) uniform Model
{
    mat4 xform;
} model;

layout(binding = 2) uniform Animation
{
    //per object/draw call input array of joint transforms
    mat4 jointXforms[MAX_JOINTS];
} animation;


layout(location = 0) in vec4  crVertexPosition;
layout(location = 1) in vec4  crVertexNormal;
layout(location = 2) in vec4  crVertexJointWeights;
layout(location = 3) in vec2  crVertexTextureUV;
layout(location = 4) in uvec4 crVertexJointIndices;


//OUTPUTS

/*
varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;
varying mat4 inverseProjectionViewMatrix;
varying vec4 viewport;
*/

/*
//The 2 varyings that are needed to calculate cosTheta for lighting calculations
varying vec4 fragPos;       //the vertex position in our desired coordinate space for lighting calculations (ie world space or view space)
varying vec4 viewPos;       //the positition of the camera in our desired coordinate space for lighting calculations
varying vec4 lightPos;      //the positiong of the emitting light in our desired coordinate space for lighting calculations
//varying vec3 sunDirection;
varying vec4 crFragmentNormal;
varying vec3 vertexNormal;  //the vertex normal transformed to our desired coordinate space for lighting calculations

//varying output variables for passing to frag shaders0
varying vec2 crFragmentTextureUV;
*/



layout(location = 0) out vec4 fragPos;
layout(location = 1) out vec4 fragNormal;
layout(location = 2) out vec4 viewPos;
layout(location = 3) out vec4 sunDir;
layout(location = 4) out vec2 fragUV;

//varying vec4 viewport;
//varying vec3 sunDir;

void main()
{
    vec4 vLocalPos = vec4(crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);
    
    /********* Skeletal Keyframe Animation **********/

    /*
    int jointIndex0 = int(crVertexJointIndices[0]);
    int jointIndex1 = int(crVertexJointIndices[1]);
    int jointIndex2 = int(crVertexJointIndices[2]);
    int jointIndex3 = int(crVertexJointIndices[3]);

    //mat4 jointTransform = crJointTransforms[jointIndex];
    vec4 posePosition0 = animation.jointXforms[jointIndex0] * vLocalPos;
    vec4 posePosition1 = animation.jointXforms[jointIndex1] * vLocalPos;
    vec4 posePosition2 = animation.jointXforms[jointIndex2] * vLocalPos;
    vec4 posePosition3 = animation.jointXforms[jointIndex3] * vLocalPos;

    vec4 totalLocalPos = vec4(0.0);
    totalLocalPos += posePosition0 * crVertexJointWeights[0];
    totalLocalPos += posePosition1 * crVertexJointWeights[1];
    totalLocalPos += posePosition2 * crVertexJointWeights[2];
    totalLocalPos += posePosition3 * crVertexJointWeights[3];
    */

    vec4 vWorldPos  = model.xform * vLocalPos;
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

    //2  Calculate Lighting Variables that involve vertex normals
    //calculate the fragment position in the desired coordinate space for lighting
    fragPos =    vWorldPos;        //lighting in world space
    //fragPos =  viewPos;       //lighting in view space

    /*
    // Vector that goes from the vertex to the light, in desired lighting coordinate space space. M is ommited because it's identity.
    lightPos = vec4(crLightPosition.xyz, 1.);                   //world space
    //lightPos =  crViewMatrix * vec4(crLightPosition,1.);  //view space
    //sunDirection = crSunDirection;

    //vertexViewPosToLight = lightViewPos.xyz + vertexViewPosToCamera;

    //  Vector that defines the view position in our lighting coordinate space
    viewPos = vec4(crViewPosition.xyz, 1.);
    //vertexViewPosToCamera = normalize(vertexViewPosToCamera);
    //3. Pass through 'varying' variables to fragment shader
    */

    //3.1  Caclulate the Normal of the the vertex for lighting by multiplying the vertex normal by the "Normal Matrix" in our desired coordinate space for lighting
    fragNormal = crVertexNormal;
    //vertexViewNormal = ( crViewMatrix * crModelMatrix * vec4(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z, 0) ).xyz; // Only correct if ModelMatrix does not scale the model ! Use its inverse transpose if not.

    viewPos = camera.pos;
    sunDir  = camera.sun;
    fragUV = vec2(crVertexTextureUV.x, 1.0 - crVertexTextureUV.y);

    /*
    mat3 modelInverseXpose = mat3(crModelMatrix[0].xyz, crModelMatrix[1].xyz, crModelMatrix[2].xyz);
    vertexNormal = normalize(modelInverseXpose * crVertexNormal.xyz);
    //vertexNormal = normalize(crModelInverseTransposeMatrix * vec3(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z));
    //vertexNormal = crModelViewInverseTransposeMatrix * vec3(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z);

    //3.2  Proces/Pass through UV texture coordinate lookup 'varying' variables to fragment shader
    crFragmentTextureUV.xy = vec2(crVertexTextureUV.x, 0.5 + crTextureLookupScalar + (crTextureLookupScalar * -2.0 * crVertexTextureUV.y));//crVertexTextureUV.xy;//vec2(crVertexTextureUV.x, crVertexTextureUV.y);
    crFragmentTextureUV *= crTextureCoordinateScalar;
    //crFragmentColor = crVertexColor;

    viewport = crViewport;
    inverseViewMatrix = crInverseViewMatrix;
    inverseProjectionMatrix = crInverseProjectionMatrix;
    inverseProjectionViewMatrix = crInverseProjectionViewMatrix;
    */
}
