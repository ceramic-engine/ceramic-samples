#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D tex3;
uniform sampler2D tex4;
uniform sampler2D tex5;
uniform sampler2D tex6;
uniform sampler2D tex7;

in vec2 tcoord;
in vec4 color;
in float textureId;

out vec4 fragColor;

void main(void) {
    vec4 texColor = vec4(0.0);
    if (textureId == 0.0) {
        texColor = texture(mainTex, tcoord);
    }
    else if (textureId == 1.0) {
        texColor = texture(tex1, tcoord);
    }
    else if (textureId == 2.0) {
        texColor = texture(tex2, tcoord);
    }
    else if (textureId == 3.0) {
        texColor = texture(tex3, tcoord);
    }
    else if (textureId == 4.0) {
        texColor = texture(tex4, tcoord);
    }
    else if (textureId == 5.0) {
        texColor = texture(tex5, tcoord);
    }
    else if (textureId == 6.0) {
        texColor = texture(tex6, tcoord);
    }
    else if (textureId == 7.0) {
        texColor = texture(tex7, tcoord);
    }
    fragColor = color * texColor;
}

