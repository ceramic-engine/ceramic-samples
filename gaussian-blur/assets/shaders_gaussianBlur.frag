#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;
uniform vec2 resolution;
uniform vec2 blurSize;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

void main(void) {
    vec2 radius = blurSize / resolution.xy;
    vec4 pixel = texture(mainTex, tcoord);
    float d = 0.0;
    while (d < 6.28318530718) {
        vec2 dir = vec2(cos(d), sin(d)) * radius;
        float i = 0.25;
        while (i <= 1.0) {
            pixel = pixel + texture(mainTex, tcoord + dir * i);
            i += 0.25;
        }
        d += 0.39269908169875;
    }
    pixel = pixel / 64.;
    fragColor = color * pixel;
}

