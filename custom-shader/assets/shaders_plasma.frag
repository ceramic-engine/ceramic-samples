#version 300 es

#ifdef GL_ES
precision highp float;
#else
#define mediump
#define highp
#endif

uniform sampler2D mainTex;
uniform float time;
uniform vec2 resolution;

in vec2 tcoord;
in vec4 color;
in vec2 quadPos;

out vec4 fragColor;

void main(void) {
    float uvX = quadPos.x / resolution.x * (resolution.x / resolution.y);
    float uvY = quadPos.y / resolution.y;
    float v = 0.0;
    v += sin(uvX * 6.0 + time);
    v += sin(uvY * 5.0 + time * 1.3);
    v += sin((uvX + uvY) * 5.0 + time * 0.7);
    float cx = uvX + 0.5 * sin(time * 0.4);
    float cy = uvY + 0.5 * cos(time * 0.5);
    v += sin(sqrt(cx * cx + cy * cy) * 12.0 + time);
    v *= 0.25;
    vec3 rgb = vec3(0.5 + 0.5 * sin(3.14159265359 * v), 0.5 + 0.5 * sin(3.14159265359 * v + 2.094), 0.5 + 0.5 * sin(3.14159265359 * v + 4.188));
    fragColor = color * texture(mainTex, tcoord) * vec4(rgb, 1.0);
}

