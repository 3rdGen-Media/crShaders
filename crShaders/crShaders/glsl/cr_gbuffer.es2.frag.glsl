//#version 120
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision highp float;
precision highp int;
precision highp sampler2D;
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

//varying mat4 projectionViewMatrix;
varying mat4 inverseProjectionViewMatrix;


varying vec4 viewport;


//varying vec3 vertexViewPosToLight;
//varying vec3 vertexViewPosToCamera;
varying vec4 fragPos;
varying vec4 viewPos;
varying vec4 lightPos;
//varying vec3 sunDirection;

//The 2 varyings that are needed to calculate cosTheta for lighting calculations
varying vec3 vertexNormal;

//varying mat3 TBN;

//Texture Lookup Values from vertex shader
varying vec2 crFragmentTextureUV;



float length2(vec2 v)
{
    return v.x*v.x + v.y+v.y;
}

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

float LinearizeDepth(float depth)
{
    float zNear = 1.0;
    float zFar  = 100.;
    
    //float z_n = 2.0 * depth - 1.0;
    float z_e = zNear + (zFar - zNear) * depth;
    //float z = depth; // back to NDC
    return 1.0 - z_e;//(near * far) / (far + near - z * (far - near));
}

// this is supposed to get the world position from the depth buffer
vec3 WorldPosFromDepth(float depth) {
    //float z = depth * 2.0 - 1.0;

    
    //vec4 clipSpacePosition = vec4(gl_FragCoord.x/viewport.z * 2.0 - 1.0, gl_FragCoord.y/viewport.z * 2.0 - 1.0,  z, 1.0);
    vec4 clipSpacePosition = vec4( (gl_FragCoord.x - viewport.x)/(viewport.z) * 2.0 - 1., (gl_FragCoord.y - viewport.y)/(viewport.w ) * 2.0 - 1., 2.0 * depth - 1.0, 1.0);

    
    vec4 viewSpacePosition = inverseProjectionMatrix * clipSpacePosition;

    
    // Perspective division
    //viewSpacePosition /= viewSpacePosition.w;

    
    vec4 worldSpacePosition = inverseViewMatrix * viewSpacePosition;
    
    
    return worldSpacePosition.xyz;//worldSpacePosition.xyz;
}

float LinearToSRGB(float val)
{
    float oVal = 1.055 * pow(val, 1./2.4) - 0.055;//1.055 * pow(val,1.0/2.4) — 0.055;
    if( val < 0.0031308 ) { oVal = val * 12.92; }
    return oVal;
}


void main(void)
{
    //Initializations
    vec3 lightColor = vec3(1.,1.,1.);
    float lightPower = 30.;//vec3(60., 60., 60.);//60 W light source
    float specularStrength = 100.0;
    
    //Retrieve [GBUFFER] RGBA16F Source Texture color
    vec4 rgba = texture2D(crSourceTexture, crFragmentTextureUV);//* crRenderColorMult + crRenderColorAdd;//vec2(crFragmentTextureUV.x, crFragmentTextureUV.y));
    
    
    
    //rgba *= rgba.a;
    //rgba.xyz = rgba.xyz * rgba.w;
    //Unpack geometry normal from gbuffer texture sample
    vec2 unpackedNormalXY =   vec2(rgba.r, rgba.g);//unpack_vec2_16b(rgba.r);
    //Unpack geometry diffuse color from gbuffer texture sample
    vec2 unpackedColorRB =    unpack_16f_vec2(rgba.b);
    //vec2 unpackedColorBA =    unpack_vec2_16b(rgba.b);
    
    //vec2 unpackedNormalXY = vec2(unpackedNormalXR.x, unpackedColorYG.x);
    //vec2 unpackedColorRG = vec2(unpackedNormalXR.y, unpackedColorYG.y);
    //vec2 unpackedColorBA = vec2(unpackedColorZB.y, 1.0);

    //Decode Normal as Sphere Map
    //vec3 fragNormal = vec3( unpackedNormalXY, length2(unpackedNormalXY) * 2. - 1. );
    //fragNormal.xy = normalize(unpackedNormalXY) * sqrt(1. - fragNormal.z * fragNormal.z);
    
    //vec2 two = vec2(2.,2.);
    vec2 fenc = unpackedNormalXY * 4. - 2.;
    float f = dot(fenc,fenc);
    float g = sqrt(1.-f/4.);
    vec3 fragNormal;
    fragNormal.xy = fenc*g;
    fragNormal.z = 1.-f/2.;
    
    
    //vec2 angles = unpackedNormalXY * 2.0 - 1.0;
    //vec2 theta = vec2( sin(angles.x * M_PI), cos(angles.x*M_PI) );
    //sincos( angles.x * PI, theta.x, theta.y );
    //vec2 phi = vec2( sqrt( 1.0 - angles.y * angles.y ), angles.y );
    //vec3 fragNormal = vec3( theta.y * phi.x, theta.x * phi.x, phi.y );
    
    //vec3 fragNormal = vec3(unpackedNormalXY, length(unpackedNormalXY) * 2. - 1.);//vec3( unpackedNormalXY, sqrt(1.0 - (unpackedNormalXY.x * unpackedNormalXY.x + unpackedNormalXY.y * unpackedNormalXY.y)) );
    //fragNormal = normalize(fragNormal);
    //fragNormal.xy = normalize(unpackedNormalXY.xy) * sqrt(1. - fragNormal.z * fragNormal.z);
    
    

    //fragNormal.z = rgba.a;//(rgba.a/2.) - 1.0;
    vec4 diffuseColor = vec4(unpackedColorRB.x, rgba.a, unpackedColorRB.y, 1.0);
    
    
    //Calculate geometry fragment world position from depth buffer + screen spaceNDC X,Y coordinates
    vec4 depthBuffer = texture2D(crNormalTexture, crFragmentTextureUV);
    float depth  = depthBuffer.r;//)/100.0;// + depthBuffer.g + depthBuffer.b;// * 256. * 256. * 256.;//+ 2.0 / 2.;
    
    //calculate the world space fragment position
    
    vec3 phongColor = vec3(0.,0.,0.);// (ambient + diffuse) * diffuseColor.xyz;

    
    vec4 NDC = vec4( (gl_FragCoord.x - viewport.x)/(viewport.z) * 2.0 - 1., (gl_FragCoord.y - viewport.y)/(viewport.w ) * 2.0 - 1., 2.0 * depth - 1.0, 1.0);

    vec4 wVector = NDC;
    //if( wVector.w != 0.0 )
    //{
        
        //wVector.w = 1.0/wVector.w;
        vec4 worldVector = inverseProjectionMatrix * NDC;//vec4(WorldPosFromDepth(depth),1.);//vec4(wVector.xyz * wVector.w, 1.0);
        worldVector = inverseViewMatrix * worldVector;
        worldVector.w = 1./worldVector.w;
        worldVector.xyz = worldVector.xyz * worldVector.w;
     
    
    //float nearPlane = 1.0;
    //float farPlane  = 100.;
    //    depth = nearPlane + ( farPlane - nearPlane ) * depth;
    //worldVector.x = rgba.b;
    //worldVector.y = rgba.a;
    //worldVector.z = LinearizeDepth(depth);
        

        //Calculate Tangent Space for Normal
        vec3 viewDir = normalize(viewPos.xyz - worldVector.xyz);//normalize(-fragPos.xyz); // the viewer is always at (0,0,0) in view-space, so viewDir is (0,0,0) - Position => -Position
        //vec3 fragNormal =  perturb_normal( vertexNormal, viewDir, crFragmentTextureUV );//normalize(fragNormal);
        //vec2 unpackedNormalXY =   unpack_16f_vec2_normal(rgba.r);
        //vec3 fragNormal = vec3( unpackedNormalXY, sqrt(1.0 - (unpackedNormalXY.x * unpackedNormalXY.x + unpackedNormalXY.y * unpackedNormalXY.y)) );
        
        //CALCULATE LIGHTING (WORLD SPACE)
                               
        //calculate ambient lighting for phong model
    float ambientStrength = 0.15;
        vec3  ambient = ambientStrength * lightColor;

        //Calculate the vector from the light to the fragment positition (in our desired coordinate space for lighting)
    vec3 fragToLightVec = lightPos.xyz - worldVector.xyz;
        float dist = length(fragToLightVec);
        float distSquared = dist * dist;
        
        // diffuse
        vec3 norm = fragNormal;//normalize(vertexNormal);
        vec3 lightDir = normalize(fragToLightVec);
    float diff = lightPower * clamp(dot(norm, lightDir), 0.0, 1.0) / distSquared;
        vec3 diffuse = diff * lightColor;
         
    //}

    
    
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
     
    phongColor =  (ambient + diffuse) * diffuseColor.xyz;
     
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
        
    //vec2 unpackedColorRG =    unpack_16f_vec2(rgba.g);
    //vec2 unpackedColorBA =    unpack_16f_vec2(rgba.b);
    //vec4 diffuseColor = vec4(unpackedColorRG, unpackedColorBA);
        
    
    

    
    
    /*
    const float gamma = 2.2;
    vec3 hdrColor = phongColor.rgb;//texture(hdrBuffer, TexCoords).rgb;
    
      // reinhard tone mapping
      vec3 mapped = hdrColor / (hdrColor + vec3(1.0));
      // gamma correction
      mapped = pow(mapped, vec3(1.0 / gamma));
    
      gl_FragColor = vec4(mapped, 1.0);
    
    */
    //outColor.z = sqrt(1.0 - (outColor.r * outColor.r + outColor.g*outColor.g));
    
    
    
    //gl_FragColor = vec4(LinearToSRGB(diffuseColor.x), LinearToSRGB(diffuseColor.y), LinearToSRGB(diffuseColor.z), 1.);//rgba;//vec4(phongColor.xyz, 1.0);//rgba;//vec4(rgba.rgb, 1.0);
    gl_FragColor = rgba;
}
