//#version 120
#ifdef GL_ES
precision highp float;
precision highp int;
#else
#define highp
#define mediump
#define lowp
#endif

const int MAX_JOINTS = 200;

//cr_vertex_mesh_vbo input attributes for PBR rendering and animation
attribute vec4 crVertexPosition;
attribute vec4 crVertexNormal;
attribute vec4 crVertexJointWeights;
attribute vec2 crVertexTextureUV;
attribute vec4 crVertexJointIndices;

//global CPU calculated matrix inputs
uniform mat4 crProjectionMatrix;
uniform mat4 crViewMatrix;

uniform mat4 crInverseProjectionMatrix;
uniform mat4 crInverseViewMatrix;

uniform mat4 crModelMatrix;
uniform mat4 crModelInverseMatrix;
//uniform mat3 crModelInverseTransposeMatrix;

uniform mat4 crModelViewMatrix;
uniform mat4 crModelViewInverseMatrix;
//uniform mat3 crModelViewInverseTransposeMatrix;

uniform mat4 crInverseProjectionViewMatrix;

//per object/draw call input array of joint transforms
uniform mat4 crJointTransforms[MAX_JOINTS];

//global uniform attributes
uniform vec4 crViewPosition;
uniform vec4 crViewport;
uniform vec4 crSunDirection;
uniform vec4 crLightPosition;

uniform float crVertexXOffset;
uniform float crVertexYOffset;

uniform float crTextureLookupScalar;
uniform float crTextureCoordinateScalar;

//OUTPUTS

varying mat4 viewMat;

varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;
varying mat4 inverseProjectionViewMatrix;

varying vec4 viewport;
varying vec3 sunDir;

//The 2 varyings that are needed to calculate cosTheta for lighting calculations
//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;
varying vec3 fragPos;       //the vertex position in our desired coordinate space for lighting calculations (ie world space or view space)
varying vec3 viewPos;       //the positition of the camera in our desired coordinate space for lighting calculations
varying vec3 lightPos;      //the positiong of the emitting light in our desired coordinate space for lighting calculations
varying vec3 vertexNormal;  //the vertex normal transformed to our desired coordinate space for lighting calculations
//varying vec3 vertexTangent;
//varying mat3 TBN;

//varying output variables for passing to frag shaders0
varying vec3 crFragmentNormal;
varying vec2 crFragmentTextureUV;

void main(void)
{
    //0 Initializations
    //gl_PointSize = crPointSize;//50.0;//crPlotPointSize;
    
    //1  calculate VBO vertex position for static VBOs
    vec4 vLocalPos = vec4(crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.0);
   
    /*
    //calculate vertex position for animated VBOs
    vec4 totalLocalPos = vec4(0.0);
    int jointIndex0 = int( crVertexJointIndices[0]);
    int jointIndex1 = int( crVertexJointIndices[1]);
    int jointIndex2 = int( crVertexJointIndices[2]);
    int jointIndex3 = int( crVertexJointIndices[3]);

    //mat4 jointTransform = crJointTransforms[jointIndex];
    vec4 posePosition0 = crJointTransforms[jointIndex0] * vLocalPos;//vec4(crVertexPosition.xyz, 1.0);
    vec4 posePosition1 = crJointTransforms[jointIndex1] * vLocalPos;//vec4(crVertexPosition.xyz, 1.0);
    vec4 posePosition2 = crJointTransforms[jointIndex2] * vLocalPos;//vec4(crVertexPosition.xyz, 1.0);
    vec4 posePosition3 = crJointTransforms[jointIndex3] * vLocalPos;//vec4(crVertexPosition.xyz, 1.0);

    totalLocalPos += posePosition0 * crVertexJointWeights[0];
    totalLocalPos += posePosition1 * crVertexJointWeights[1];
    totalLocalPos += posePosition2 * crVertexJointWeights[2];
    totalLocalPos += posePosition3 * crVertexJointWeights[3];

    mat4 scaleMatrix = mat4(0);
    //mat4 matrix = mat4(x,y,z,w);
    scaleMatrix[0][0] = 1.;
    scaleMatrix[1][1] = 1.;
    scaleMatrix[2][2] = 1.;
    scaleMatrix[3][3] = 1.;
    */

    vec4 vWorldPos  = crModelMatrix * vLocalPos;// totalLocalPos;
    vec4 vViewPos   = crViewMatrix * vWorldPos;
    vec4 vScreenPos = crProjectionMatrix * vViewPos;
     
    //vertexPosition = totalLocalPos;
    //gl_Position = crProjectionMatrix * crModelViewMatrix * totalLocalPos;//vec4(crVertexPosition.x, crVertexPosition.y, crVertexPosition.z, 1.);//vertex;
    //preprocess screen position for the values we need to back out from it in the frag shaders
    //vertexScreenPosition = screenPos;// crProjectionMatrix * vertexViewPosition;
    //vertexScreenPosition.xy /= screenPos.w;
    
    gl_Position = vScreenPos.xyww;
    
    viewMat = crViewMatrix;
    //2  Calculate Lighting Variables that involve vertex normals
    //calculate the fragment position in the desired coordinate space for lighting
    fragPos = vWorldPos.xyz;        //lighting in world space
    //fragPos =  vViewPos.xyz;                          //lighting in view space

    sunDir = crSunDirection.xyz;
    // Vector that goes from the vertex to the light, in desired lighting coordinate space space. M is ommited because it's identity.
    //lightPos =  vec4(crLightPosition.xyz,1.);               //world space
    //lightPos =  crViewMatrix * vec4(crLightPosition,1.);  //view space
    //sunDirection = crSunDirection;
    
    //vertexViewPosToLight = lightViewPos.xyz + vertexViewPosToCamera;

    //  Vector that defines the view position in our lighting coordinate space
    viewPos = crViewPosition.xyz;// vec4(crViewPosition.xyz, 1.);
    //vertexViewPosToCamera = normalize(vertexViewPosToCamera);
    //3. Pass through 'varying' variables to fragment shader

    //3.1  Caclulate the Normal of the the vertex for lighting by multiplying the vertex normal by the "Normal Matrix" in our desired coordinate space for lighting
    crFragmentNormal = crVertexNormal.xyz;
    //vertexViewNormal = ( crViewMatrix * crModelMatrix * vec4(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z, 0) ).xyz; // Only correct if ModelMatrix does not scale the model ! Use its inverse transpose if not.
    mat3 modelInverseXpose = mat3(crModelMatrix[0].xyz, crModelMatrix[1].xyz, crModelMatrix[2].xyz);
    vertexNormal = normalize(modelInverseXpose * crVertexNormal.xyz);
    //vertexNormal = normalize(crModelInverseTransposeMatrix * vec3(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z));
    //vertexNormal = crModelViewInverseTransposeMatrix * vec3(crVertexNormal.x, crVertexNormal.y, crVertexNormal.z);
    
    //3.2  Proces/Pass through UV texture coordinate lookup 'varying' variables to fragment shader
    crFragmentTextureUV.xy = vec2(crVertexTextureUV.x, 0.5 + crTextureLookupScalar + (crTextureLookupScalar * -2.0 * crVertexTextureUV.y ) );//crVertexTextureUV.xy;//vec2(crVertexTextureUV.x, crVertexTextureUV.y);
    crFragmentTextureUV *= crTextureCoordinateScalar;
    //crFragmentColor = crVertexColor;
    
    viewport = crViewport;
    inverseViewMatrix = crInverseViewMatrix;
    inverseProjectionMatrix = crInverseProjectionMatrix;
    inverseProjectionViewMatrix = crInverseProjectionViewMatrix;

    /*
    //Calculate TBN matrix for normals
    vec3 T = normalize(crModelInverseTransposeMatrix * normalize(crVertexTangent.xyz));
    //vec3 B = normalize(crModelInverseTransposeMatrix * crVertexBitangent.xyz);
    vec3 N = normalize(crModelInverseTransposeMatrix * normalize(crVertexNormal.xyz));
    
    
    //vec3 T = normalize(vec3(model * vec4(aTangent, 0.0)));
    //vec3 N = normalize(vec3(model * vec4(aNormal, 0.0)));
    // re-orthogonalize T with respect to N
    T = normalize(T - dot(T, N) * N);
    // then retrieve perpendicular vector B with the cross product of T and N
    vec3 B = cross(N, T);

    TBN = mat3(T, B, N);
     */
}
