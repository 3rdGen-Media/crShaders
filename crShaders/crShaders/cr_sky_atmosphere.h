// Copyright Epic Games, Inc. All Rights Reserved.
#pragma once

// Only for artifact evaluation, Should not be used when measuring performance
#define SKYHIGHQUALITY

//class Texture2D;
//class Texture3D;

/*
struct GlslVec3
{
	float x, y, z;
};
#define vec3 GlslVec3
//#include "./Resources/Bruneton17/definitions.glsl"
*/

typedef cr_float3 vec3;

#include "cr_atm_params.glsl"
#include "math.h"
typedef unsigned int uint32;
typedef AtmosphereParameters AtmosphereInfo;

//void SetupEarthAtmosphere(AtmosphereInfo& info);

// Units are in megameters.
#define EARTH_GROUND_RADIUS_MM 6371.
#define EARTH_ATM_RADIUS_MM	   6471.

#if 1
static const uint32 TRANSMITTANCE_TEXTURE_WIDTH  = 512;
static const uint32 TRANSMITTANCE_TEXTURE_HEIGHT = 512;

static const uint32 SCATTERING_TEXTURE_R_SIZE    = 32;
static const uint32 SCATTERING_TEXTURE_MU_SIZE   = 128;
static const uint32 SCATTERING_TEXTURE_MU_S_SIZE = 32;
static const uint32 SCATTERING_TEXTURE_NU_SIZE   = 8;

static const uint32 SCATTERING_TEXTURE_WIDTH	= 512;
static const uint32 SCATTERING_TEXTURE_HEIGHT   = 512;

static const uint32 IRRADIANCE_TEXTURE_WIDTH	= 64;
static const uint32 IRRADIANCE_TEXTURE_HEIGHT	= 16;

static const uint32 SKY_VIEW_TEXTURE_WIDTH		= 512;
static const uint32 SKY_VIEW_TEXTURE_HEIGHT		= 512;

#else
uint32 TRANSMITTANCE_TEXTURE_WIDTH = 64;
uint32 TRANSMITTANCE_TEXTURE_HEIGHT = 16;

uint32 SCATTERING_TEXTURE_R_SIZE = 16;
uint32 SCATTERING_TEXTURE_MU_SIZE = 16;
uint32 SCATTERING_TEXTURE_MU_S_SIZE = 16;
uint32 SCATTERING_TEXTURE_NU_SIZE = 4;

uint32 IRRADIANCE_TEXTURE_WIDTH = 32;
uint32 IRRADIANCE_TEXTURE_HEIGHT = 8;
#endif

// Derived from above
//uint32 SCATTERING_TEXTURE_WIDTH  = 0xDEADBEEF;
//uint32 SCATTERING_TEXTURE_HEIGHT = 0xDEADBEEF;
//uint32 SCATTERING_TEXTURE_DEPTH  = 0xDEADBEEF;

//#define SCATTERING_TEXTURE_WIDTH  = SCATTERING_TEXTURE_NU_SIZE * SCATTERING_TEXTURE_MU_S_SIZE;
//#define SCATTERING_TEXTURE_HEIGHT = SCATTERING_TEXTURE_MU_SIZE;
//#define SCATTERING_TEXTURE_DEPTH  = SCATTERING_TEXTURE_R_SIZE;

/*
Creating this as a dynamically allocated object is pointless...
struct LookUpTablesInfo
{
#if 1
	uint32 TRANSMITTANCE_TEXTURE_WIDTH = 256;
	uint32 TRANSMITTANCE_TEXTURE_HEIGHT = 64;

	uint32 SCATTERING_TEXTURE_R_SIZE = 32;
	uint32 SCATTERING_TEXTURE_MU_SIZE = 128;
	uint32 SCATTERING_TEXTURE_MU_S_SIZE = 32;
	uint32 SCATTERING_TEXTURE_NU_SIZE = 8;

	uint32 IRRADIANCE_TEXTURE_WIDTH = 64;
	uint32 IRRADIANCE_TEXTURE_HEIGHT = 16;
#else
	uint32 TRANSMITTANCE_TEXTURE_WIDTH = 64;
	uint32 TRANSMITTANCE_TEXTURE_HEIGHT = 16;

	uint32 SCATTERING_TEXTURE_R_SIZE = 16;
	uint32 SCATTERING_TEXTURE_MU_SIZE = 16;
	uint32 SCATTERING_TEXTURE_MU_S_SIZE = 16;
	uint32 SCATTERING_TEXTURE_NU_SIZE = 4;

	uint32 IRRADIANCE_TEXTURE_WIDTH = 32;
	uint32 IRRADIANCE_TEXTURE_HEIGHT = 8;
#endif

	// Derived from above
	uint32 SCATTERING_TEXTURE_WIDTH  = 0xDEADBEEF;
	uint32 SCATTERING_TEXTURE_HEIGHT = 0xDEADBEEF;
	uint32 SCATTERING_TEXTURE_DEPTH  = 0xDEADBEEF;

	void updateDerivedData()
	{
		SCATTERING_TEXTURE_WIDTH = SCATTERING_TEXTURE_NU_SIZE * SCATTERING_TEXTURE_MU_S_SIZE;
		SCATTERING_TEXTURE_HEIGHT = SCATTERING_TEXTURE_MU_SIZE;
		SCATTERING_TEXTURE_DEPTH = SCATTERING_TEXTURE_R_SIZE;
	}

	LookUpTablesInfo() { updateDerivedData(); }
};
*/

/*
//LUTs is just an object containing 3 LUT GPU textures
//We have moved these onto a CRenderTarget
struct LookUpTables
{
	Texture2D* TransmittanceTex;
	Texture3D* ScatteringTex;
	Texture2D* IrradianceTex;

	void Allocate(LookUpTablesInfo& LutInfo);
	void Release();
};
*/

/*
//TempLUTs is just an object containing 4 GPU textures for storing Deltas
//We have moved these onto a CRenderTarget?
struct TempLookUpTables
{
	Texture2D* DeltaIrradianceTex;
	Texture3D* DeltaMieScatteringTex;
	Texture3D* DeltaRaleighScatteringTex;
	Texture3D* DeltaScatteringDensityTex;

	void Allocate(LookUpTablesInfo& LutInfo);
	void Release();
};
*/


static void SetupEarthAtmosphere(AtmosphereInfo* info)
{
	// Values shown here are the result of integration over wavelength power spectrum integrated with paricular function.
	// Refer to https://github.com/ebruneton/precomputed_atmospheric_scattering for details.

	// All units in kilometers
	const float EarthBottomRadius = 6360.0f;
	const float EarthTopRadius = 6460.0f;   // 100km atmosphere radius, less edge visible and it contain 99.99% of the atmosphere medium https://en.wikipedia.org/wiki/K%C3%A1rm%C3%A1n_line
	const float EarthRayleighScaleHeight = 8.0f;
	const float EarthMieScaleHeight = 1.2f;

	// Sun - This should not be part of the sky model...
	//info.solar_irradiance = { 1.474000f, 1.850400f, 1.911980f };
	info->solar_irradiance	 = CR_FLOAT3_ONE; //(vec3) { 1.0f, 1.0f, 1.0f };	// Using a normalise sun illuminance. This is to make sure the LUTs acts as a transfert factor to apply the runtime computed sun irradiance over.
	info->sun_angular_radius = 0.004675f;

	// Earth
	info->bottom_radius		 = EarthBottomRadius;
	info->top_radius		 = EarthTopRadius;
	info->ground_albedo		 = CR_FLOAT3_ZERO;// { 0.0f, 0.0f, 0.0f };

	// Raleigh scattering
	info->rayleigh_density.layers[0] = (DensityProfileLayer){ 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
	info->rayleigh_density.layers[1] = (DensityProfileLayer){ 0.0f, 1.0f, -1.0f / EarthRayleighScaleHeight, 0.0f, 0.0f };
	info->rayleigh_scattering		 = (vec3){ 0.005802f, 0.013558f, 0.033100f };		// 1/km

	// Mie scattering
	info->mie_density.layers[0] = (DensityProfileLayer){ 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
	info->mie_density.layers[1] = (DensityProfileLayer){ 0.0f, 1.0f, -1.0f / EarthMieScaleHeight, 0.0f, 0.0f };
	info->mie_scattering		= (vec3){ 0.003996f, 0.003996f, 0.003996f };			// 1/km
	info->mie_extinction		= (vec3){ 0.004440f, 0.004440f, 0.004440f };			// 1/km
	info->mie_phase_function_g	= 0.8f;

	// Ozone absorption
	info->absorption_density.layers[0] = (DensityProfileLayer){ 25.0f, 0.0f, 0.0f, 1.0f / 15.0f, -2.0f / 3.0f };
	info->absorption_density.layers[1] = (DensityProfileLayer){ 0.0f, 0.0f, 0.0f, -1.0f / 15.0f, 8.0f / 3.0f };
	info->absorption_extinction		   = (vec3){ 0.000650f, 0.001881f, 0.000085f };	// 1/km

	const double max_sun_zenith_angle = PI * 120.0 / 180.0; // (use_half_precision_ ? 102.0 : 120.0) / 180.0 * kPi;
	info->mu_s_min = (float)cos(max_sun_zenith_angle);
}


//DXGI_FORMAT_R32G32B32A32_FLOAT  DXGI_FORMAT_R16G16B16A16_FLOAT
// 32f is required if you do not want extra visual artefacts...
#ifdef SKYHIGHQUALITY
#define DX_ATM_LUT_FORMAT DXGI_FORMAT_R32G32B32A32_FLOAT
#else
#define DX_ATM_LUT_FORMAT DXGI_FORMAT_R16G16B16A16_FLOAT
#endif

/*
void LookUpTables::Allocate(LookUpTablesInfo& LutInfo)
{
	{
		D3dTexture2dDesc desc = Texture2D::initDefault(D_LUT_FORMAT, LutInfo.TRANSMITTANCE_TEXTURE_WIDTH, LutInfo.TRANSMITTANCE_TEXTURE_HEIGHT, true, true);
		TransmittanceTex = new Texture2D(desc);
	}
	{
		D3dTexture2dDesc desc = Texture2D::initDefault(D_LUT_FORMAT, LutInfo.IRRADIANCE_TEXTURE_WIDTH, LutInfo.IRRADIANCE_TEXTURE_HEIGHT, true, true);
		IrradianceTex = new Texture2D(desc);
	}
	{
		D3dTexture3dDesc desc = Texture3D::initDefault(D_LUT_FORMAT, LutInfo.SCATTERING_TEXTURE_WIDTH, LutInfo.SCATTERING_TEXTURE_HEIGHT, LutInfo.SCATTERING_TEXTURE_DEPTH, true, true);
		ScatteringTex = new Texture3D(desc);
	}
}

void LookUpTables::Release()
{
	resetPtr(&TransmittanceTex);
	resetPtr(&IrradianceTex);
	resetPtr(&ScatteringTex);
}



void TempLookUpTables::Allocate(LookUpTablesInfo& LutInfo)
{
	{
		D3dTexture2dDesc desc = Texture2D::initDefault(D_LUT_FORMAT, LutInfo.IRRADIANCE_TEXTURE_WIDTH, LutInfo.IRRADIANCE_TEXTURE_HEIGHT, true, true);
		DeltaIrradianceTex = new Texture2D(desc);
	}
	{
		D3dTexture3dDesc desc = Texture3D::initDefault(D_LUT_FORMAT, LutInfo.SCATTERING_TEXTURE_WIDTH, LutInfo.SCATTERING_TEXTURE_HEIGHT, LutInfo.SCATTERING_TEXTURE_DEPTH, true, true);
		DeltaMieScatteringTex = new Texture3D(desc);
		DeltaRaleighScatteringTex = new Texture3D(desc);
		DeltaScatteringDensityTex = new Texture3D(desc);
	}
}

void TempLookUpTables::Release()
{
	resetPtr(&DeltaIrradianceTex);
	resetPtr(&DeltaMieScatteringTex);
	resetPtr(&DeltaRaleighScatteringTex);
	resetPtr(&DeltaScatteringDensityTex);
}
*/

//Globals

//LookUpTablesInfo LutsInfo;  //These properties were moved out of struct, i don't think this is needed anymore
static const AtmosphereInfo   AtmosphereInfos;
static const AtmosphereInfo   AtmosphereInfosSaved;
//LookUpTables     LUTs;
//TempLookUpTables TempLUTs;
