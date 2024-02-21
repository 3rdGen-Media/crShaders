//#version 120//for gles2 glsl compatibility
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision highp float;
precision highp int;
#else
#define highp
#define mediump
#define lowp
#endif

const float PI = 3.14159265358;

// Units are in megameters.
//const float groundRadiusMM     = 6371.;
//const float atmosphereRadiusMM = 6471.;

// Units are in megameters.
const float groundRadiusMM = 6.360;
const float atmosphereRadiusMM = 6.460;

// 200M above the ground.
//const vec3 viewPos = vec3(0.0, groundRadiusMM, 0.0);

const vec2 tLUTRes  = vec2(512., 512.);// vec2(256.0, 64.0);
const vec2 msLUTRes = vec2(512., 512.);// vec2(32.0, 32.0);
// Doubled the vertical skyLUT res from the paper, looks way
// better for sunrise.
const vec2 skyLUTRes = vec2(512., 512.);//vec2(512., 256.);

// These are per megameter.
const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase = 0.0;

const float mieScatteringBase = 3.996;
const float mieAbsorptionBase = 4.4;

const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, .085);

float getMiePhase(float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0 / (8.0 * PI);

    float num = (1.0 - g * g) * (1.0 + cosTheta * cosTheta);
    float denom = (2.0 + g * g) * pow((1.0 + g * g - 2.0 * g * cosTheta), 1.5);

    return scale * num / denom;
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0 / (16.0 * PI);
    return k * (1.0 + cosTheta * cosTheta);
}


void getScatteringValues(vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction)
{
    float altitudeKM = (length(pos) - groundRadiusMM) * 1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0);
    float mieDensity = exp(-altitudeKM / 1.2);

    rayleighScattering = rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;

    mieScattering = mieScatteringBase * mieDensity;
    float mieAbsorption = mieAbsorptionBase * mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM - 25.0) / 15.0);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}


/*
void getScatteringValues(vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) 
{
    float altitudeKM = (length(pos) - groundRadiusMM);//*1000.0;
    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM / 8.0);
    float mieDensity = exp(-altitudeKM / 1.2);

    rayleighScattering = rayleighScatteringBase * rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;

    mieScattering = mieScatteringBase * mieDensity;
    float mieAbsorption = mieAbsorptionBase * mieDensity;

    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM - 40.179) / 17.83);

    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}
*/

float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(vec3 ro, vec3 rd, float rad)
{
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad * rad;
    if (c > 0.0 && b > 0.0) return -1.0;
    float discr = b * b - c;
    if (discr < 0.0) return -1.0;
    // Special case: inside sphere, use far discriminant
    if (discr > b * b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

// From https://www.shadertoy.com/view/wlBXWK
vec2 rayIntersectSphere2D(
    vec3 start, // starting position of the ray
    vec3 dir, // the direction of the ray
    float radius // and the sphere radius
) {
    // ray-sphere intersection that assumes
    // the sphere is centered at the origin.
    // No intersection when result.x > result.y
    float a = dot(dir, dir);
    float b = 2.0 * dot(dir, start);
    float c = dot(start, start) - (radius * radius);
    float d = (b * b) - 4.0 * a * c;
    if (d < 0.0) return vec2(1e5, -1e5);
    return vec2(
        (-b - sqrt(d)) / (2.0 * a),
        (-b + sqrt(d)) / (2.0 * a)
    );
}


//uniform samplerCube crSourceTexture;
uniform highp sampler2D crSourceTexture;
uniform highp sampler2D crNormalTexture;

varying mat4 viewMat;

varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;
varying mat4 inverseProjectionViewMatrix;

//uniform vec3 crLightPosition;
varying vec4 viewport;
varying vec3 sunDir;


//The 2 varyings that are needed to calculate cosTheta for lighting calculations
//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;
varying vec3 fragPos;
varying vec3 viewPos;
varying vec3 lightPos;
varying vec3 vertexNormal;

//varying mat3 TBN;


//Texture Lookup Values from vertex shader
varying vec3 crFragmentNormal;
varying vec2 crFragmentTextureUV;


//varying mat4 projectionViewMatrix;


// "Followup: Normal Mapping Without Precomputed Tangents" from http://www.thetenthplanet.de/archives/1180
mat3 cotangent_frame( vec3 N, vec3 p, vec2 uv )
{
    /* get edge vectors of the pixel triangle */
    vec3 dp1 = dFdx( p );
    vec3 dp2 = dFdy( p );
    vec2 duv1 = dFdx( uv );
    vec2 duv2 = dFdy( uv );

    /* solve the linear system */
    vec3 dp2perp = cross( dp2, N );
    vec3 dp1perp = cross( N, dp1 );
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    /* construct a scale-invariant frame */
    float invmax = inversesqrt( max( dot(T,T), dot(B,B) ) );
    return mat3( T * invmax, B * invmax, N );
}

vec3 perturb_normal( vec3 N, vec3 V, vec2 texcoord )
{
    /* assume N, the interpolated vertex normal and V, the view vector (vertex to eye) */
    vec3 map = texture2D( crNormalTexture, texcoord ).xyz;
    // WITH_NORMALMAP_UNSIGNED
    //map = normalize(map);
    //map = map * 2.0 - 1.0;

    map = map * 255./127. - 128./127.;
    map = normalize(map);
    
    // WITH_NORMALMAP_2CHANNEL
    // map.z = sqrt( 1. - dot( map.xy, map.xy ) );
    // WITH_NORMALMAP_GREEN_UP
    // map.y = -map.y;
    mat3 TBN = cotangent_frame( N, -V, texcoord );
    return normalize( TBN * map );
}

float pack_vec2_16b(vec2 src)
{
   const float fromFixed = 255.0/256.;
   float enc = src.x * fromFixed * 256. * 255. + src.y * fromFixed * 255.;
   return enc/65535.;
}
            

float pack_vec2_16f(vec2 src)
{
    return floor(src.x * 100.)+(src.y * 0.8);
}



/*
 * Partial implementation of
 *    "A Scalable and Production Ready Sky and Atmosphere Rendering Technique"
 *    by S�bastien Hillaire (2020).
 * Very much referenced and copied S�bastien's provided code:
 *    https://github.com/sebh/UnrealEngineSkyAtmosphere
 *
 * This basically implements the generation of a sky-view LUT, so it doesn't
 * include aerial perspective. It only works for views inside the atmosphere,
 * because the code assumes that the ray-marching starts at the camera position.
 * For a planetary view you'd want to check that and you might march from, e.g.
 * the edge of the atmosphere to the ground (rather than the camera position
 * to either the ground or edge of the atmosphere).
 *
 * Also want to cite:
 *    https://www.shadertoy.com/view/tdSXzD
 * Used the jodieReinhardTonemap from there, but that also made
 * me realize that the paper switched the Mie and Rayleigh height densities
 * (which was confirmed after reading S�bastien's code more closely).
 */

 /*
  * Final output basically looks up the value from the skyLUT, and then adds a sun on top,
  * does some tonemapping.
  */

vec3 getValFromTLUT(sampler2D tex, vec2 bufferRes, vec3 pos, vec3 sunDir) 
{
    float height = length(pos);
    vec3 up = pos / height;
    float sunCosZenithAngle = dot(sunDir, up);
    vec2 uv = vec2(tLUTRes.x * clamp(0.5 + 0.5 * sunCosZenithAngle, 0.0, 1.0),
        tLUTRes.y * max(0.0, min(1.0, (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM))));
    uv /= bufferRes;
    return texture2D(tex, uv).rgb;
}

vec3 getValFromSkyLUT(sampler2D tex, vec3 rayDir, vec3 sunDir, vec3 viewPos) 
{
    float height = length(viewPos);
    vec3 up = viewPos / height;

    float horizonAngle = safeacos(sqrt(height * height - groundRadiusMM * groundRadiusMM) / height);
    float altitudeAngle = horizonAngle - acos(dot(rayDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI
    if (abs(altitudeAngle) > (0.5 * PI - .0001)) {
        // Looking nearly straight up or down.
        azimuthAngle = 0.0;
    }
    else {
        vec3 right = cross(sunDir, up);
        vec3 forward = cross(up, right);

        vec3 projectedDir = normalize(rayDir - up * (dot(rayDir, up)));
        float sinTheta = dot(projectedDir, right);
        float cosTheta = dot(projectedDir, forward);
        azimuthAngle = atan(sinTheta, cosTheta) + PI;
    }

    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5 * sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0 / PI);
    vec2 uv = vec2(azimuthAngle / (2.0 * PI), v);
    //uv *= skyLUTRes;
    //uv /= skyLUTRes;// iChannelResolution[1].xy;

    return texture2D(tex, uv).rgb;
}


vec3 jodieReinhardTonemap(vec3 c) 
{
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

vec3 sunWithBloom(vec3 rayDir, vec3 sunDir)
{
    /*const*/ float sunSolidAngle = 0.53 * PI / 180.0;
    /*const*/ float minSunCosTheta = cos(sunSolidAngle);

    float cosTheta = dot(rayDir, sunDir);
    if (cosTheta >= minSunCosTheta) return vec3(1.0);

    float offset = minSunCosTheta - cosTheta;
    float gaussianBloom = exp(-offset * 50000.0) * 0.5;
    float invBloom = 1.0 / (0.02 + offset * 300.0) * 0.01;
    return vec3(gaussianBloom + invBloom);
}


/*
 * Do raymarching : builds skyview lut inside atmoshpere, raymarches directly outside atmosphere
*/

//const int numScatteringSteps = 32;
const int numScatteringSteps = 16;
vec3 raymarchScattering(sampler2D TLUT, vec2 TLUT_size, sampler2D MSLUT, vec2 MSLUT_size,
    vec3 viewPos,
    vec3 rayDir,
    vec3 sunDir,
    float numSteps) {


    vec2 atmos_intercept = rayIntersectSphere2D(viewPos, rayDir, atmosphereRadiusMM);
    float terra_intercept = rayIntersectSphere(viewPos, rayDir, groundRadiusMM);

    float mindist, maxdist;

    if (atmos_intercept.x < atmos_intercept.y) {
        // there is an atmosphere intercept!
        // start at the closest atmosphere intercept
        // trace the distance between the closest and farthest intercept
        mindist = atmos_intercept.x > 0.0 ? atmos_intercept.x : 0.0;
        maxdist = atmos_intercept.y > 0.0 ? atmos_intercept.y : 0.0;
    }
    else {
        // no atmosphere intercept means no atmosphere!
        return vec3(0.0);
    }

    // if in the atmosphere start at the camera
    if (length(viewPos) < atmosphereRadiusMM) mindist = 0.0;


    // if there's a terra intercept that's closer than the atmosphere one,
    // use that instead!
    if (terra_intercept > 0.0) { // confirm valid intercepts			
        maxdist = terra_intercept;
    }

    // start marching at the min dist
    vec3 pos = viewPos + mindist * rayDir;

    float cosTheta = dot(rayDir, sunDir);

    float miePhaseValue = getMiePhase(cosTheta);
    float rayleighPhaseValue = getRayleighPhase(-cosTheta);

    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;
    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3) / numSteps) * (maxdist - mindist);
        float dt = newT - t;
        t = newT;

        vec3 newPos = pos + t * rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;

        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

        vec3 sampleTransmittance = exp(-dt * extinction);

        vec3 sunTransmittance = getValFromTLUT(TLUT, TLUT_size, newPos, sunDir);
        vec3 psiMS = vec3(0.0);// *getValFromMultiScattLUT(MSLUT, MSLUT_size, newPos, sunDir);

        vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunTransmittance + psiMS);
        vec3 mieInScattering = mieScattering * (miePhaseValue * sunTransmittance + psiMS);
        vec3 inScattering = (rayleighInScattering + mieInScattering);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral * transmittance;

        transmittance *= sampleTransmittance;
    }
    return lum;
}

void main(void)
{
    const vec3 camPos = vec3(0.0, groundRadiusMM + 0.0002, 0.0);
    //vec3 camPos = vec3(0.0, groundRadiusMM + 0.0002 * 1000. + viewPos.y, 0.0);

    //Initializations
    vec3 lightColor = vec3(1.,1.,1.);
    float lightPower = 60.0;//vec3(60., 60., 60.);//60 W light source
    float specularStrength = 100.0;
    
    //Retrieve Source Texture color
    //vec3 texCoord = vec3(crFragmentNormal.x, crFragmentNormal.y, -crFragmentNormal.z);
    //vec4 rgba = textureCube(crSourceTexture, texCoord);//* crRenderColorMult + crRenderColorAdd;//vec2(crFragmentTextureUV.x, crFragmentTextureUV.y));
    vec4 rgba = texture2D(crSourceTexture, crFragmentTextureUV);
    //vec3 fragNormal = texture2D(crNormalTexture, crFragmentTextureUV).rgb;

    //Calculate Tangent Space for Normal
    vec3 viewDir = normalize(fragPos.xyz - viewPos.xyz);//normalize(-fragPos.xyz); // the viewer is always at (0,0,0) in view-space, so viewDir is (0,0,0) - Position => -Position
    vec3 fragNormal = vertexNormal;//perturb_normal( vertexNormal, viewDir, crFragmentTextureUV );//normalize(fragNormal);
    
    vec2 enc = normalize(fragNormal.xy) * (sqrt(-fragNormal.z*0.5 + 0.5));
    enc = enc * 0.5 + 0.5;
    
    float packedNormalXY = pack_vec2_16b( enc );//vec2(enc.x, rgba.r) );

    //vec3 rgbEnc = normalize(rgba.rgb);
    //enc = normalize(rgbEnc.rg) * sqrt(rgbEnc.b*0.5+0.5);
    float packedColorRB = pack_vec2_16f( rgba.rb );//vec2(enc.y, rgba.g) );

    //float aspect = 0.562500;

    /*
    vec3 camDir = crFragmentNormal.xyz;// normalize(vec3(0.0, 0.27, -1.0));
    float camFOVHeight = 45. * PI / 180.;
    float camHeightScale = tan(camFOVHeight / 2.0);
    float camWidthScale  =  (viewport.w / viewport.z) / camHeightScale;

    vec3 camRight = normalize(cross(camDir, vec3(0.0, 1.0, 0.0)));
    vec3 camUp = normalize(cross(camRight, camDir));
    
    vec2 xy = 2.0 * (crFragmentTextureUV) - 1.0;
    vec3 rayDir = normalize(camDir + camRight * xy.x * camWidthScale + camUp * xy.y * camHeightScale);
    */

    //vec3 camDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    /*
    float camFOVWidth = 45. * PI / 180.0;
    float camWidthScale = 2.0 * tan(camFOVWidth / 2.0);
    float camHeightScale = camWidthScale * viewport.z / viewport.w;

    //vec3 camRight = normalize(cross(camDir, vec3(0.0, 1.0, 0.0)));
    //vec3 camUp = normalize(cross(camRight, camDir));

    vec2 xy = 2.0 * (crFragmentTextureUV) - 1.0;
    vec3 rayDir = normalize(-viewMat[3].xyz + viewMat[0].xyz * xy.x * camWidthScale + viewMat[1].xyz * xy.y * camHeightScale);
    */

    //skydome sphere is always centered on camera so the ray 
    //into the sky LUT is just the normal of the sphere
    vec3 rayDir = crFragmentNormal.xyz;
    vec3 lum;

    //float altitudeKM = (length(camPos + viewPos) - groundRadiusMM);//*1000.0;
    if ( 1>0 )//length(camPos + viewPos) < atmosphereRadiusMM * 10.) 
    {
        lum = getValFromSkyLUT(crNormalTexture, rayDir, sunDir, camPos);
        // Draw Sun
        // Bloom should be added at the end, but this is subtle and works well.
        vec3 sunLum = sunWithBloom(crFragmentNormal.xyz, sunDir);
    
        // Use smoothstep to limit the effect, so it drops off to actual zero.
        sunLum = smoothstep(0.002, 1.0, sunLum);
        if (length(sunLum) > 0.0) 
        {
            if (rayIntersectSphere(camPos, rayDir, groundRadiusMM) >= 0.0)
            {
                sunLum *= 0.0;
            }
            else 
            {
                // If the sun value is applied to this pixel, we need to calculate the transmittance to obscure it.
               sunLum *= getValFromTLUT(crSourceTexture, tLUTRes, camPos, sunDir);
               //rgba = vec4(rgba.xyz + sunLum, rgba.a);
            }
        }
        lum += sunLum;
    }
    else 
    {

        // As mentioned in section 7 of the paper, switch to direct raymarching outside atmosphere
        //lum = raymarchScattering(crSourceTexture, tLUTRes, crNormalTexture, skyLUTRes,
        //                         camPos, rayDir, sunDir, float(numScatteringSteps));

        // This little bit of red helps to debug when the rendering switches to pure raymarching
        //lum = vec3(0,0.0,0.0);
    }

    // Tonemapping and gamma. Super ad-hoc, probably a better way to do this.
    lum *= 20.0;
    lum = pow(lum, vec3(1.3));
    lum /= (smoothstep(0.0, 0.2, clamp(sunDir.y, 0.0, 1.0)) * 2.0 + 0.15);

    lum = jodieReinhardTonemap(lum);
    //lum = pow(lum, vec3(1.0 / 2.2)); //gamma resolve is done automatically at the end of frame render pass

    gl_FragColor = vec4(lum, 1.0);
}
