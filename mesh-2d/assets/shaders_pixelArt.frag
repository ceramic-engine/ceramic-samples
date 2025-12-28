#version 300 es

#ifdef GL_ES
precision mediump float;
#else
#define mediump
#endif

uniform sampler2D mainTex;
uniform vec2 resolution;
uniform float sharpness;
uniform float gridThickness;
uniform float gridAlpha;
uniform vec3 gridColor;
uniform float scanlineIntensity;
uniform float scanlineOffset;
uniform float scanlineCount;
uniform float scanlineShape;
uniform float verticalMaskIntensity;
uniform float verticalMaskOffset;
uniform float verticalMaskCount;
uniform float glowThresholdMin;
uniform float glowThresholdMax;
uniform float glowStrength;
uniform float chromaticAberration;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

float sharpen(float px) {
    float norm = (fract(px) - 0.5) * 2.0;
    float norm2 = norm * norm;
    return floor(px) + norm * pow(norm2, sharpness) / 2.0 + 0.5;
}

vec4 sampleSharpened(vec2 coord) {
    return texture(mainTex, vec2(sharpen(coord.x * resolution.x) / resolution.x, sharpen(coord.y * resolution.y) / resolution.y));
}

float grid(float gap, vec2 uv) {
    vec2 dist = mod(vec2(uv.x + 0.5, uv.y + 0.5), vec2(gap)) - vec2(0.5 * gap);
    return min(abs(dist.x), abs(dist.y));
}

void main(void) {
    vec4 texColor;
    if (chromaticAberration > 0.0) {
        vec2 aberr = vec2(chromaticAberration, 0.0);
        float r = sampleSharpened(tcoord + aberr).r;
        float g = sampleSharpened(tcoord).g;
        float b = sampleSharpened(tcoord - aberr).b;
        texColor = vec4(r, g, b, 1.0);
    }
    else {
        texColor = sampleSharpened(tcoord);
    }
    if (gridThickness > 0.0) {
        vec2 uv = vec2(tcoord.x * resolution.x, tcoord.y * resolution.y);
        float gap = 1.0;
        float line = grid(gap, uv);
        float aa = smoothstep(0.0, 0.5, gridThickness - line);
        aa *= gridAlpha;
        texColor.rgb = mix(texColor.rgb, gridColor, aa);
    }
    float lum = dot(texColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    if (scanlineCount > 0.0) {
        float scanY = sin((scanlineOffset / scanlineCount + tcoord.y) * scanlineCount * 3.14159);
        scanY = scanY * 0.5 + 0.5;
        scanY = pow(scanY, mix(scanlineShape, min(scanlineShape, 1.0), lum));
        float scanFactor = mix(scanlineIntensity, 1.0, scanY);
        texColor.rgb = texColor.rgb * scanFactor;
    }
    if (verticalMaskCount > 0.0) {
        float scanX = sin((verticalMaskOffset / verticalMaskCount + tcoord.x) * verticalMaskCount * 3.14159);
        float maskFactor = mix(verticalMaskIntensity, 1.0, scanX * 0.5 + 0.5);
        texColor.rgb = texColor.rgb * maskFactor;
    }
    if (glowStrength > 0.0) {
        float glowFactor = smoothstep(glowThresholdMin, glowThresholdMax, lum);
        if (glowFactor > 0.0) {
            vec2 texel = vec2(1.0) / resolution;
            vec3 blur = texture(mainTex, tcoord + vec2(texel.x, 0.0)).rgb;
            blur = blur + texture(mainTex, tcoord - vec2(texel.x, 0.0)).rgb;
            blur = blur + texture(mainTex, tcoord + vec2(0.0, texel.y)).rgb;
            blur = blur + texture(mainTex, tcoord - vec2(0.0, texel.y)).rgb;
            blur = blur + texColor.rgb;
            blur = blur / 5.0;
            texColor.rgb = mix(texColor.rgb, blur, glowFactor * glowStrength);
        }
    }
    texColor.a = 1.0;
    fragColor = color * texColor;
}

