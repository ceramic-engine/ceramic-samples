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
    vec4 pixel = texture(mainTex, tcoord);
    float uvX = tcoord.x;
    float uvY = tcoord.y;
    vec4 sum = vec4(0.0, 0.0, 0.0, 0.0);
    int n = 0;
    while (n < 9) {
        uvY = tcoord.y + blurSize.y * (float(n) - 4.0) / resolution.y;
        vec4 hSum = vec4(0.0, 0.0, 0.0, 0.0);
        hSum = hSum + texture(mainTex, vec2(uvX - 4.0 * blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX - 3.0 * blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX - 2.0 * blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX - blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX + blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX + 2.0 * blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX + 3.0 * blurSize.x / resolution.x, uvY));
        hSum = hSum + texture(mainTex, vec2(uvX + 4.0 * blurSize.x / resolution.x, uvY));
        sum = sum + hSum / 9.0;
        n++;
    }
    pixel = sum / 9.0;
    fragColor = color * pixel;
}

