#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;
uniform vec2 resolution;
uniform float glowSize;
uniform vec3 glowColor;
uniform float glowIntensity;
uniform float glowThreshold;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

void main(void) {
    vec4 pixel = texture(mainTex, tcoord);
    if (pixel.a <= glowThreshold) {
        float uvX = tcoord.x;
        float uvY = tcoord.y;
        float sum = 0.0;
        int n = 0;
        while (n < 9) {
            uvY = tcoord.y + glowSize * (float(n) - 4.0) / resolution.y;
            float hSum = 0.0;
            hSum += texture(mainTex, vec2(uvX - 4.0 * glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX - 3.0 * glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX - 2.0 * glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX - glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX, uvY)).a;
            hSum += texture(mainTex, vec2(uvX + glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX + 2.0 * glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX + 3.0 * glowSize / resolution.x, uvY)).a;
            hSum += texture(mainTex, vec2(uvX + 4.0 * glowSize / resolution.x, uvY)).a;
            sum += hSum / 9.0;
            n++;
        }
        float a = sum / 9.0 * glowIntensity;
        vec3 tempVec3;
        {
            float lhs = a;
            vec3 rhs = glowColor;
            tempVec3 = rhs * lhs;
        }
        pixel = vec4(tempVec3, a);
    }
    fragColor = color * pixel;
}

