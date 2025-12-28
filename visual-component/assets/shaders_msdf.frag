#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;
uniform vec2 texSize;
uniform float pxRange;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void main(void) {
    vec2 msdfUnit;
    vec3 textureSample;
    msdfUnit = vec2(pxRange) / texSize;
    textureSample = texture(mainTex, tcoord).rgb;
    float sigDist = median(textureSample.r, textureSample.g, textureSample.b) - 0.5;
    sigDist *= dot(msdfUnit, vec2(0.5) / fwidth(tcoord));
    float opacity = clamp(sigDist + 0.5, 0.0, 1.0);
    vec4 bgColor = vec4(0.0, 0.0, 0.0, 0.0);
    fragColor = mix(bgColor, color, opacity);
}

