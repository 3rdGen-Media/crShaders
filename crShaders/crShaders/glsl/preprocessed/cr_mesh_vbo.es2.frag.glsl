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

#define M_PI 3.1415926535897932384626433832795

uniform highp sampler2D crSourceTexture;
uniform highp sampler2D crNormalTexture;


varying mat4 inverseViewMatrix;
varying mat4 inverseProjectionMatrix;
varying mat4 inverseProjectionViewMatrix;


varying vec4 viewport;

//Texture Lookup Values from vertex shader
varying vec4 fragPos;
varying vec4 viewPos;
varying vec4 lightPos;
//uniform vec3 crLightPosition;
//varying vec3 sunDirection;
varying vec3 vertexNormal;

varying vec2 crFragmentTextureUV;

//The 2 varyings that are needed to calculate cosTheta for lighting calculations
//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;


//varying mat3 TBN;


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


//pack: f1=(f1+1)*0.5; f2=(f2+1)*0.5; res=floor(f1*1000)+f2;inline float PackFloat16bit2(float2 src){return floorf((src.x+1)*0.5f * 100.0f)+((src.y+1)*0.4f);}//unpack: f2=frac(res); f1=(res-f2)/1000; f1=(f1-0.5)*2;f2=(f2-0.5)*2;inline float2 UnPackFloat16bit2(float src){float2 o;float fFrac = frac(src);o.y = (fFrac-0.4f)*2.5f;o.x = ((src-fFrac)/100.0f-0.5f)*2;return o;}


//Thanks @paveltumik for the original code in comments
//pack:    f1=(f1+1)*0.5; f2=(f2+1)*0.5; res=floor(f1*1000)+f2
float pack_vec2_16f_normal(vec2 src)
{
    return floor((src.x + 1.)*0.5 * 100.0)+((src.y + 1.)*0.4);
}

//unpack:    f2=frac(res);    f1=(res-f2)/1000;    f1=(f1-0.5)*2;f2=(f2-0.5)*2;
vec2 unpack_16f_vec2_normal(float src)
{
    vec2 o;
    float fFrac = fract(src);
    o.y = (fFrac - 0.4)*2.5;
    o.x = ((src-fFrac)/100.0 - 0.5)*2.;
    return o;
}

       
float pack_vec2_16b(vec2 src)
{
   const float fromFixed = 255.0/256.;
   float enc = src.x * fromFixed * 256. * 255. + src.y * fromFixed * 255.;
   return enc/65535.;
}
            
 vec2 unpack_vec2_16b(float src)
 {
     float src2 = src * 65535.0;
     vec2 dec = vec2(src2/256./255.,  src2*256./256./255.);
     return dec;
 }

float pack_vec2_16f(vec2 src)
{
    return floor(src.x * 100.)+(src.y * 0.8);
}

//unpack:    f2=frac(res);    f1=(res-f2)/1000;    f1=(f1-0.5)*2;f2=(f2-0.5)*2;
vec2 unpack_16f_vec2(float src)
{
    vec2 o;
    float fFrac = fract(src);
    o.y = fFrac/0.8;//(fFrac - 0.4)*2.5;
    o.x = (src-fFrac)/100.;// - 0.5)*2.;
    return o;
}

void main(void)
{
    //Initializations
    vec3 lightColor = vec3(1.,1.,1.);
    float lightPower = 60.0;//vec3(60., 60., 60.);//60 W light source
    float specularStrength = 100.0;
    
    //Retrieve Source Texture color
    vec4 rgba = texture2D(crSourceTexture, crFragmentTextureUV);//* crRenderColorMult + crRenderColorAdd;//vec2(crFragmentTextureUV.x, crFragmentTextureUV.y));
    //vec3 fragNormal = texture2D(crNormalTexture, crFragmentTextureUV).rgb;

    /*
    //Retrieve Normal Map Tangent Space Vector
    vec3 fragNormal = texture2D(crNormalTexture, crFragmentTextureUV).rgb;
    // Normalize to guarantee normal from normal map in range [0,1]
    fragNormal = normalize(fragNormal);
    // transform normal vector to range [-1,1]
    fragNormal = fragNormal * 2.0 - 1.0;
    //transform normal from tangent space to world space
    fragNormal = normalize(TBN * fragNormal);
    */
    

    
    //Calculate Tangent Space for Normal
    vec3 viewDir = normalize(viewPos.xyz - fragPos.xyz);//normalize(-fragPos.xyz); // the viewer is always at (0,0,0) in view-space, so viewDir is (0,0,0) - Position => -Position
    vec3 fragNormal = perturb_normal( vertexNormal, viewDir, crFragmentTextureUV );//normalize(fragNormal);

    
    /*
    vec4 NDC = vec4( (gl_FragCoord.x - viewport.x)/(viewport.z) * 2.0 - 1., (gl_FragCoord.y - viewport.y)/(viewport.w ) * 2.0 - 1., 2.0 * gl_FragCoord.z - 1.0, 1.0);

    vec4 wVector = NDC;
    //if( wVector.w != 0.0 )
    //{
        
        //wVector.w = 1.0/wVector.w;
        vec4 worldVector = inverseProjectionMatrix * NDC;//vec4(WorldPosFromDepth(depth),1.);//vec4(wVector.xyz * wVector.w, 1.0);
        worldVector = inverseViewMatrix * worldVector;
    worldVector.w = 1./worldVector.w;
    worldVector.xyz = worldVector.xyz * worldVector.w;
    */
    
    /*
    //calculate ambient lighting for phong model
    float ambientStrength = 0.15;
    vec3  ambient = ambientStrength * lightColor;

    //Calculate the vector from the light to the fragment positition (in our desired coordinate space for lighting)
    vec3 fragToLightVec = lightPos.xyz - fragPos.xyz;
    float dist = length(fragToLightVec);
    float distSquared = dist * dist;
    
    // diffuse
    vec3 norm = fragNormal;//normalize(vertexNormal);
    vec3 lightDir = normalize(fragToLightVec);
    float diff = lightPower * clamp(dot(norm, lightDir), 0.0, 1.0) / distSquared;
    vec3 diffuse = diff * lightColor;

    // specular
    //vec3 viewDir = normalize(viewPos.xyz - fragPos.xyz);//normalize(-fragPos.xyz); // the viewer is always at (0,0,0) in view-space, so viewDir is (0,0,0) - Position => -Position
    vec3 halfwayDir = normalize(lightDir + viewDir);

    if( diff > 0.0 )
    {
        vec3 reflectDir = reflect(norm, halfwayDir);
        float spec = lightPower * pow(clamp(dot(viewDir, reflectDir), 0.0, 1.), 8.) / dist;
        vec3 specular = specularStrength * spec * lightColor;
        diffuse += specular;
    }
    */
    
    /*
    //float fragDepth = gl_FragCoord.z / gl_FragCoord.w;
    float distanceToFrag = length(vertexViewPosToLight);

    //calculate diffuse lighting for phong model
    float diff = lightPower * clamp(dot(vertexViewNormal, normalize(vertexViewPosToLight)), 0.0, 1.0) / (distanceToFrag * distanceToFrag);
    vec3 diffuse = diff * lightColor;
    
    //calculate specular lighting for phong model
    // Eye vector (towards the camera)
    //vec3 E = normalize(EyeDirection_cameraspace);
    // Direction in which the triangle reflects the light
    //vec3 R = reflect(-l,n);
    
    //vector from "frag" position to camera (in view space)
    vec3 vertexViewPosToCameraNorm = normalize(vertexViewPosToCamera);
    //vector in the direction of the reflection off the surface
    vec3 reflectDir = reflect(vec3(0.0,0.,0.) - vertexViewPosToLight, vertexViewNormal);
    
    vec3 lightDir   = normalize(vertexViewPosToLight);
    vec3 viewDir    = normalize(vertexViewPosToCamera);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    
    float cosAlpha = clamp( dot( vertexViewNormal,halfwayDir ), 0.,1. );
    float spec = lightPower * pow(cosAlpha, 16.) / (distanceToFrag * distanceToFrag);
    vec3 specular = specularStrength * spec * lightColor;
    */
    //calculate specular lighting for phong model
    //vec3 phongColor =  (ambient + diffuse) * rgba.xyz;
    
    //vec2 one = vec2(1.,1.);
    //fragNormal.xy =  (fragNormal.xy + one) * 0.5;
    
    //fragNormal.xy = normalize(fragNormal.xy) * sqrt(fragNormal.z * 0.5 + 0.5);
    
    //Encode Normal using Sphere Map Transform A La Cry Engine 3
    //fragNormal.xy = normalize(fragNormal.xy) *sqrt(-1.0 * fragNormal.z * 0.5 + 0.5);
    
    vec2 enc = normalize(fragNormal.xy) * (sqrt(-fragNormal.z*0.5 + 0.5));
    enc = enc * 0.5 + 0.5;
    
    //rgba.xyz = (ambient + diffuse) * rgba.xyz;
    //float atanYX = atan(fragNormal.y,fragNormal.x);
    //vec2 normalOut = vec2(atanYX / M_PI, fragNormal.z);
    //fragNormal.xy = (normalOut + 1.0) * 0.5;
    
    float packedNormalXY = pack_vec2_16b( enc );//vec2(enc.x, rgba.r) );

    //vec3 rgbEnc = normalize(rgba.rgb);
    //enc = normalize(rgbEnc.rg) * sqrt(rgbEnc.b*0.5+0.5);
    float packedColorRB = pack_vec2_16f( rgba.rb );//vec2(enc.y, rgba.g) );
    //float packedColorG = pack_vec2_16b( rgba.g );//vec2(fragNormal.z, rgba.b) );
    

    //vec2 unpackedNormalXY =   unpack_16f_vec2_normal(packedNormalXY);
    //vec2 unpackedColorRG =    unpack_16f_vec2(packedColorRG);
    //vec2 unpackedColorBA =    unpack_16f_vec2(packedColorBA);

    if( rgba.a < 0.75 ) { discard; }
    //gl_FragColor = vec4(enc.x, enc.y, packedColorRB, rgba.g);//vec4( (fragNormal.x + 1. ) * 0.5, (fragNormal.y+1.)*0.5, (fragNormal.z + 1.) * 0.5, 1.0);
    gl_FragColor = rgba;
}
