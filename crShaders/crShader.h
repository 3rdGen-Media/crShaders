//
//  crShader.h
//  CRViewer
//
//  Created by Joe Moulton on 12/9/16.
//  Copyright © 2016 Abstract Embedded. All rights reserved.
//

#ifndef crShader_h
#define crShader_h

#ifdef CR_TARGET_WIN32
#include <CoreRender/crPlatform/crgc_gl_ext.h>
#else

//#ifndef unsigned int
//#define unsigned int unsigned int
//#endif
#endif


//#include "cr_opengl.h"
//#include "crMath.h"
//#include "crShaders/crgc_vbo.h"
//#ifndef __APPLE__
//crPlatform:        Platform Window and Graphics Context Creation Library, also provides Vertical Retrace event callback
//#include <CoreRender/crPlatform.h>
//#else
//#include <OpenGLES/ES1/gl.h>
//#endif

/*
//crXML:            custom crXML class for fast xml loading for formats such as Collada and FBX or custom save files
#include <CoreRender/crXML.h>
//crPrimitives:        custom SIMD primitive Vector, Matrix, and Vertex data types and associated functions for graphics use
//crGeometry:        load model mesh for file types such as OBJ, FLT
#include <CoreRender/crGeometry.h>
//crImage:            image loading i/o, useful for creating graphics textures
#include <CoreRender/crImage.h>
//crUtils:            timing, file IO, string manipulation, etc... encapsulated in a header only library
#include <CoreRender/crUtils.h>
//crText:            font loading and manipulation, font glyph loading, text layout and manipulation
#include <CoreRender/crText.h>
*/


//#include <OpenGL/gl.h>
//#include "cr_mesh.h"
//#include "cr_event_queue.h"
#include "crMath.h"

typedef cr_float2_packed float2;
typedef cr_float3_packed float3;
typedef cr_float4_matrix float4x4;
#include "crShaders/cr_sky_atmosphere.h"

//enumerate each of our shader programs
typedef enum CR_SHADER_PROGRAMS
{
    CR_SHADER_PROG_VERTEX_MESH,
    CR_SHADER_PROG_VERTEX_PLOT
    
}CR_SHADER_PROGRAMS;

typedef enum CR_VERTEX_PLOT_TYPES
{
    CR_VERTEX_PLOT_LINES,
    CR_VERTEX_PLOT_POINTS
}CR_VERTEX_PLOT_TYPES;

//define some static strings for passing cr_vertex_mesh as attributes and uniforms

//GLOBAL MATRIX UNIFORM SHADER INPUTS
static const char * CR_PROJECTION_MATRIX_UNIFORM = "crProjectionMatrix";
static const char * CR_INVERSE_PROJECTION_MATRIX_UNIFORM = "crInverseProjectionMatrix";

static const char * CR_VIEW_MATRIX_UNIFORM = "crViewMatrix";
static const char * CR_INVERSE_VIEW_MATRIX_UNIFORM = "crInverseViewMatrix";

static const char * CR_MODEL_MATRIX_UNIFORM = "crModelMatrix";
static const char * CR_MODEL_INVERSE_MATRIX_UNIFORM = "crModelInverseMatrix";
static const char * CR_MODEL_INVERSE_TRANSPOSE_MATRIX_UNIFORM = "crModelInverseTransposeMatrix";

static const char * CR_PROJECTION_VIEW_MATRIX_UNIFORM = "crProjectionViewMatrix";
static const char * CR_INVERSE_PROJECTION_VIEW_MATRIX_UNIFORM = "crInverseProjectionViewMatrix";


static const char * CR_MODEL_VIEW_MATRIX_UNIFORM = "crModelViewMatrix";
static const char * CR_MODEL_VIEW_INVERSE_MATRIX_UNIFORM = "crModelViewInverseMatrix";
static const char * CR_MODEL_VIEW_INVERSE_TRANSPOSE_MATRIX_UNIFORM = "crModelViewInverseTransposeMatrix";

static const char * CR_VIEW_POSITION_UNIFORM = "crViewPosition";

static const char * CR_VIEWPORT_UNIFORM = "crViewport";
static const char * CR_VIEW_FRUSTUM_UNIFORM = "crFrustum";
static const char * CR_FOCAL_LENGTH_UNIFORM = "crFocalLength";


//Ephemeris Uniforms
static const char * CR_EPHEMERIS_SUN_DIRECTION_UNIFORM = "crSunDirection";

//for individual component uniforms
//static const char * CR_VERTEX_POSITION_X_SHADER_ATTRIBUTE = "crVertexPositionX"; //for a single float component uniform
//static const char * CR_VERTEX_POSITION_Y_SHADER_ATTRIBUTE = "crVertexPositionY"; //for a single float component uniform
//static const char * CR_VERTEX_POSITION_Z_SHADER_ATTRIBUTE = "crVertexPositionZ"; //for a single float component uniform
//static const char * CR_VERTEX_POSITION_W_SHADER_ATTRIBUTE = "crVertexPositionW"; //for a single float component uniform

//CR_VERTEX_MESH_VBO SHADER ATTRIBUTE INPUTS
static const char * CR_VERTEX_POSITION_SHADER_ATTRIBUTE = "crVertexPosition"; //for a vec4 vertex position uniform
static const char * CR_VERTEX_COLOR_SHADER_ATTRIBUTE = "crVertexColor";
static const char * CR_VERTEX_NORMAL_SHADER_ATTRIBUTE = "crVertexNormal";
static const char * CR_VERTEX_TANGENT_SHADER_ATTRIBUTE = "crVertexTangent";
static const char * CR_VERTEX_BITANGENT_SHADER_ATTRIBUTE = "crVertexBitangent";
static const char * CR_VERTEX_TEXTURE_UV_SHADER_ATTRIBUTE = "crVertexTextureUV";
static const char * CR_VERTEX_JOINT_INDEX_SHADER_ATTRIBUTE = "crVertexJointIndices";
static const char * CR_VERTEX_JOINT_WEIGHT_SHADER_ATTRIBUTE = "crVertexJointWeights";

//CR_VERTEX_MESH_VBO ATTRIBUTE HANDLES
static unsigned int _positionAttribute;
static unsigned int _colorAttribute;
static unsigned int _normalAttribute;
static unsigned int _tangentAttribute;
static unsigned int _bitangentAttribute;
static unsigned int _uvAttribute;
static unsigned int _texelAttribute;
static unsigned int _jointIndexAttribute;
static unsigned int _jointWeightAttribute;

//static unsigned int _vertexXAttribute;
//static unsigned int _vertexYAttribute;
//static unsigned int _vertexZAttribute;
//static unsigned int _vertexWAttribute;

//establish uniforms to pass matrices and textures to shaders

//CR_VERTEX_MESH_VBO Source texture and PBR pipeline texture inputs
static const char * CR_SOURCE_TEXTURE_UNIFORM = "crSourceTexture";
static const char * CR_NORMAL_TEXTURE_UNIFORM = "crNormalTexture";

static const char * CR_JOINT_TRANSFORM_ARRAY_UNIFORM = "crJointTransforms";
static const char * CR_APPLY_JOINT_TRANSFORMS_UNIFORM = "crApplyJointTransforms";

static const char * CR_TEXTURE_LOOKUP_SCALAR_UNIFORM = "crTextureLookupScalar";
static const char * CR_TEXTURE_COORDINATE_SCALAR_UNIFORM = "crTextureCoordinateScalar";

static const char * CR_VERTEX_X_OFFSET_UNIFORM = "crVertexXOffset";
static const char * CR_VERTEX_Y_OFFSET_UNIFORM = "crVertexYOffset";

static const char * CR_RENDER_COLOR_OPTION_UNIFORM = "crRenderColorOption";

static const char * CR_CLEAR_COLOR_UNIFORM = "crClearColor";
static const char * CR_RENDER_COLOR_MULT_UNIFORM = "crRenderColorMult";
static const char * CR_RENDER_COLOR_ADD_UNIFORM = "crRenderColorAdd";

/*** DEPTH Uniform Definitions (for custom depth writing to a framebuffer color render buffer)***/
static const char * CR_DEPTH_SCHEME_UNIFORM = "crDepthScheme";
static const char * CR_DEPTH_PRECISION_UNIFORM = "crDepthPrecision";

static const char * CR_OUTPUT_DEPTH_UNIFORM = "crOutputDepth";
static const char * CR_RENDER_PLOT_UNIFORM = "crRenderPlotConditional";
static const char * CR_POINT_SIZE_UNIFORM = "crPointSize";

static const char * CR_RENDER_BILLBOARD_UNIFORM = "crRenderBillboard";

static const char * CR_LIGHT_POSITION_UNIFORM = "crLightPosition";

//static const char * CR_PLOT_TYPE_UNIFORM = "crPlotType";

//static const char * CR_PLOT_COLOR_UNIFORM = "crPlotColor";

//static const char * CR_PLOT_POINT_SIZE_UNIFORM = "crPlotPointSize";

//static const char * CR_TEXTURE_LOOKUP_SCALAR_UNIFORM = "crTextureLookupScalar";
static unsigned int _gVAO;
//create a handle for each shader program
//static unsigned int _meshShaderProg;
//static unsigned int _gbufferShaderProg;

//static unsigned int _staticMeshShader;
//static unsigned int _plotShaderProg;

//handles to global matrix uniforms for passing to vertex shader
static unsigned int _projectionUniform;
static unsigned int _projectionInverseUniform;

// Model, Model Inverse, Model Inverse Transpose
static unsigned int _modelUniform;
static unsigned int _modelInverseUniform;
//static unsigned int _modelInverseTransposeUniform;

// View, View Inverse
static unsigned int _viewUniform;
static unsigned int _viewInverseUniform;

static unsigned int _projectionViewUniform;
static unsigned int _projectionViewInverseUniform;

// ModelView, ModelView Inverse, ModelView Inverse Transpose
static unsigned int _modelViewUniform;
static unsigned int _modelViewInverseUniform;
//static unsigned int _modelViewInverseTransposeUniform;

//handles to global vector uniforms for passing to vertex shader
static unsigned int _viewPositionUniform;

//global viewport, projection input uniforms
static unsigned int _viewportUniform;
static unsigned int _frustumUniform;
static unsigned int _focalLengthUniform;
//uniform vec4 crViewport;
//uniform vec2 crProjectionPlanes;  //near far projection frustum clip planes

//per object input uniforms
static unsigned int _jointTransformArrayUniform;
static unsigned int _applyJointTransformsUniform;

//texture uniforms to be passed to the vertex shader
//TO DO:  move these into an ordered list of color attachment uniforms
static unsigned int _sourceTextureUniform;
static unsigned int _normalTextureUniform;

static unsigned int _textureLookupScalarUniform;
static unsigned int _textureCoordinateScalarUniform;

static unsigned int _vertexXOffsetUniform;
static unsigned int _vertexYOffsetUniform;

static unsigned int _renderColorOptionUniform;

static unsigned int _clearColorUniform;
static unsigned int _renderColorMultUniform;
static unsigned int _renderColorAddUniform;

static unsigned int _pointSizeUniform;


//plot stuff
static unsigned int _plotVertexBuffer;
static unsigned int _plotIndexBuffer;

static unsigned int _outputDepthUniform;
static unsigned int _renderPlotUniform;
//static unsigned int _plotTypeUniform;
//static unsigned int _plotColorUniform;
//static unsigned int _plotPointSizeUniform;

static unsigned int _renderBillboardUniform;

static unsigned int _lightPositionUniform;

//buffer for rendering cr_vertex_mesh
static unsigned int _meshVertexBuffer;
static unsigned int _meshIndexBuffer;

static unsigned int _axisVertexBuffer;
static unsigned int _axisIndexBuffer;

static unsigned int _pointVertexBuffer;

//buffer handles for a quad for rendering fbo texture back to screen
//unsigned int _viewportSizedQuadVertexBuffer;
//unsigned int _viewportSizedQuadIndexBuffer;
static unsigned int _triVertexBuffer;
static unsigned int _triIndexBuffer;


//static GLuint64 _quadVertexBuffer;
//static GLuint64 _quadIndexBuffer;
//static unsigned int _quadVertexBuffer;
//static unsigned int _quadIndexBuffer;
//static unsigned int _floorTexture[5];
static unsigned int _wallTexture[5];
//static unsigned int _paintingTexture;

//frame and render buffers of screen size
//static unsigned int _framebuffer;
//static unsigned int _colorRenderBuffer;

//a dedicated final stage offscreen buffer
static unsigned int _offscreenFBO;
static unsigned int _offscreenFBOTexture;

/*** DEPTH Buffers, Textures & Uniforms ***/
//a depth buffer/texure that can either be attached to screen size framebuffer or a multismpled framebuffer
static unsigned int _depthRenderBuffer;
static unsigned int _depthTexture;
static unsigned int _depthSchemeUniform;
static unsigned int _depthPrecisionUniform;

//4x Antialising Buffers
static unsigned int _msaaFramebuffer;
static unsigned int _msaaRenderbuffer;
static unsigned int _msaaDepthStencilbuffer;
static unsigned int _msaaDepthBuffer;

//frame buffer objects for direct to texture rendering
static unsigned int _fbo;
static unsigned int _fboTexture;
static unsigned int _fboDepthBuffer;

//texture objects for text rendering
static unsigned int _fontGlyphQuadVertexBuffer;
static unsigned int _fontGlyphQuadIndexBuffer;
static unsigned int _fontGlyphTexture;

static unsigned int _crosshairTexture;
static unsigned int _gridTexture;
static unsigned int _plotTexture;


static unsigned int _quadDiffuseTexture;
static unsigned int _quadNormalTexture;

#pragma mark -- Ephermeris Uniform definitions
static unsigned int _sunDirectionUniform;

#pragma mark -- MESH VBO DEFINITIONS

typedef struct UniformBufferObject 
{
    //cr_float4_matrix model;
    cr_float4_matrix proj;
    cr_float4_matrix view;
	cr_float4		 viewport;
	cr_float4		 pos;
	cr_float4		 sun;
	cr_float4		 moon;
}UniformBufferObject;

////////////////////////////////////////////////////////////////////////////////
	// Sky and Atmosphere parameters

typedef struct SkyAtmosphereConstantBufferStructure
{
	//
	// From AtmosphereParameters
	//

	IrradianceSpectrum solar_irradiance;
	Angle sun_angular_radius;

	ScatteringSpectrum absorption_extinction;
	Number mu_s_min;

	ScatteringSpectrum rayleigh_scattering;
	Number mie_phase_function_g;

	ScatteringSpectrum mie_scattering;
	Length bottom_radius;

	ScatteringSpectrum mie_extinction;
	Length top_radius;

	ScatteringSpectrum mie_absorption;
	Length pad00;

	DimensionlessSpectrum ground_albedo;
	float pad0;

	float rayleigh_density[12];
	float mie_density[12];
	float absorption_density[12];

	//
	// Add generated static header constant
	//

	int TRANSMITTANCE_TEXTURE_WIDTH;
	int TRANSMITTANCE_TEXTURE_HEIGHT;
	int IRRADIANCE_TEXTURE_WIDTH;
	int IRRADIANCE_TEXTURE_HEIGHT;

	int SCATTERING_TEXTURE_R_SIZE;
	int SCATTERING_TEXTURE_MU_SIZE;
	int SCATTERING_TEXTURE_MU_S_SIZE;
	int SCATTERING_TEXTURE_NU_SIZE;

	float3 SKY_SPECTRAL_RADIANCE_TO_LUMINANCE;
	float  pad3;
	float3 SUN_SPECTRAL_RADIANCE_TO_LUMINANCE;
	float  pad4;

	//
	// Other globals
	//
	float4x4 gSkyViewProjMat;
	float4x4 gSkyInvViewProjMat;
	float4x4 gSkyInvProjMat;
	float4x4 gSkyInvViewMat;
	float4x4 gShadowmapViewProjMat;

	float3 camera;
	float  pad5;
	float3 sun_direction;
	float  pad6;
	float3 view_ray;
	float  pad7;

	float MultipleScatteringFactor;
	float MultiScatteringLUTRes;
	float pad9;
	float pad10;
}SkyAtmosphereConstantBufferStructure;

//typedef ConstantBuffer<SkyAtmosphereConstantBufferStructure> SkyAtmosphereConstantBuffer;
//SkyAtmosphereConstantBuffer* SkyAtmosphereBuffer;

typedef struct SkyAtmosphereSideConstantBufferStructure
{
	float4x4 LuminanceFromRadiance;
	int      ScatteringOrder;
	int      UseSingleMieScatteringTexture;
	float2   pad01;
};

#endif /* crShader_h */
