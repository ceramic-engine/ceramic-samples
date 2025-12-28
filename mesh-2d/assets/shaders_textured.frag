#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

void main(void) {
    vec4 texColor = vec4(0.0);
    texColor = texture(mainTex, tcoord);
    fragColor = color * texColor;
}

