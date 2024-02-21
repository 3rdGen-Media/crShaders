#version 310 es

#ifdef GL_ES
precision highp float;
#else
#define highp
#define mediump
#define lowp
#endif


layout(location = 0) in vec4 fragColor;
layout(location = 1) in vec2 fragUV;

layout(location = 0) out vec4 outColor;

layout(set = 1, binding = 0) uniform sampler2D MESH_TEXTURES[2];

void main() 
{
    vec4 rgba = texture(MESH_TEXTURES[0], fragUV);

    if( rgba.a < 0.75f ) { discard; }
    outColor = rgba;//vec4(rgba.r, rgba.g, rgba.b, 1.0);
}
