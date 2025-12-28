#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;

in vec2 tcoord;
in vec4 color;
in vec4 darkColor;

out vec4 fragColor;

void main(void) {
    vec4 texColor = vec4(0.0);
    texColor = texture(mainTex, tcoord);
    vec4 result = vec4((vec3((texColor.a - 1.0) * darkColor.a + 1.0) - texColor.rgb) * darkColor.rgb + texColor.rgb * color.rgb, texColor.a * color.a);
    fragColor = result;
}

