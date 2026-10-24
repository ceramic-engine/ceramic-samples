#version 300 es

#ifdef GL_ES
precision highp float;
#else
#define mediump
#define highp
#endif

uniform sampler2D mainTex;
uniform sampler2D bloomTex;
uniform vec2 resolution;
uniform float outputScale;
uniform vec4 screenRect;
uniform float beamAmount;
uniform float hardPix;
uniform float sharpBand;
uniform float hardScan;
uniform float beamMin;
uniform float beamMax;
uniform float scanlineStrength;
uniform float maskType;
uniform float maskDark;
uniform float maskLight;
uniform float maskScale;
uniform float lcdGridStrength;
uniform float lcdSubpixelLow;
uniform float bloomAmount;
uniform float warpX;
uniform float warpY;
uniform float cornerRadius;
uniform float cornerSmooth;
uniform float vignetteStrength;
uniform float gamma;
uniform float brightness;
uniform mat3 colorMatrix;
uniform float luminance;
uniform float time;
uniform float noiseStrength;
uniform float flickerStrength;
uniform float quality;

in vec2 tcoord;
in vec4 color;

out vec4 fragColor;

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 toLinear(vec3 c) {
    vec3 result = c;
    if (gamma > 0.0) {
        result = pow(max(c, 0.0), vec3(gamma));
    }
    return result;
}

vec3 toDisplay(vec3 c) {
    vec3 result = c;
    if (gamma > 0.0) {
        result = pow(max(c, 0.0), vec3(1.0 / gamma));
    }
    return result;
}

vec3 fetch(vec2 pos, vec2 off) {
    vec2 p = (floor(pos * resolution + off) + 0.5) / resolution;
    return toLinear(texture(mainTex, p).rgb);
}

vec2 dist(vec2 pos) {
    vec2 p = pos * resolution;
    return -(p - floor(p) - 0.5);
}

float gaus(float pos, float scale) {
    return exp2(scale * pos * pos);
}

vec3 horz3(vec2 pos, float off) {
    vec3 b = fetch(pos, vec2(-1.0, off));
    vec3 c = fetch(pos, vec2(0.0, off));
    vec3 d = fetch(pos, vec2(1.0, off));
    float dst = dist(pos).x;
    float wb = gaus(dst - 1.0, hardPix);
    float wc = gaus(dst, hardPix);
    float wd = gaus(dst + 1.0, hardPix);
    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

vec3 horz5(vec2 pos, float off) {
    vec3 a = fetch(pos, vec2(-2.0, off));
    vec3 b = fetch(pos, vec2(-1.0, off));
    vec3 c = fetch(pos, vec2(0.0, off));
    vec3 d = fetch(pos, vec2(1.0, off));
    vec3 e = fetch(pos, vec2(2.0, off));
    float dst = dist(pos).x;
    float wa = gaus(dst - 2.0, hardPix);
    float wb = gaus(dst - 1.0, hardPix);
    float wc = gaus(dst, hardPix);
    float wd = gaus(dst + 1.0, hardPix);
    float we = gaus(dst + 2.0, hardPix);
    return (a * wa + b * wb + c * wc + d * wd + e * we) / (wa + wb + wc + wd + we);
}

float beamScale(vec3 c) {
    float lum = clamp(luma(c), 0.0, 1.0);
    return hardScan / max(mix(beamMin, beamMax, lum), 0.001);
}

float scan(vec2 pos, float off, float scale) {
    float dst = dist(pos).y;
    return gaus(dst + off, scale);
}

vec3 sharpTexel(vec2 pos) {
    vec2 p = pos * resolution + 0.5;
    vec2 fl = floor(p);
    vec2 fr = p - fl;
    float band = max(sharpBand, 0.001) / outputScale;
    fr = clamp((fr - 0.5) / band + 0.5, 0.0, 1.0);
    return toLinear(texture(mainTex, (fl + fr - 0.5) / resolution).rgb);
}

vec3 maskTriad(float x) {
    vec3 m = vec3(maskDark);
    float f = fract(x);
    if (f < 0.333) {
        m.r = maskLight;
    }
    else if (f < 0.666) {
        m.g = maskLight;
    }
    else {
        m.b = maskLight;
    }
    return m;
}

vec3 maskTv(vec2 pos) {
    float line = maskLight;
    float odd = 0.0;
    if (fract(pos.x / 6.0) < 0.5) {
        odd = 1.0;
    }
    if (fract((pos.y + odd) * 0.5) < 0.5) {
        line = maskDark;
    }
    return maskTriad(pos.x / 3.0) * line;
}

vec3 maskAperture(vec2 pos) {
    return maskTriad(pos.x / 3.0);
}

vec3 maskVgaStretched(vec2 pos) {
    return maskTriad((pos.x + pos.y * 3.0) / 6.0);
}

vec3 maskVga(vec2 pos) {
    vec2 p = floor(pos * vec2(1.0, 0.5));
    return maskTriad((p.x + p.y * 3.0) / 6.0);
}

vec3 maskLcd(vec2 uv) {
    vec2 f = fract(uv * resolution);
    vec3 m = vec3(lcdSubpixelLow);
    if (f.x < 0.333) {
        m.r = 1.0;
    }
    else if (f.x < 0.666) {
        m.g = 1.0;
    }
    else {
        m.b = 1.0;
    }
    float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * outputScale;
    m = m * mix(1.0 - lcdGridStrength, 1.0, clamp(edge, 0.0, 1.0));
    return m;
}

vec3 mask(vec2 uv, vec2 screenPos) {
    vec3 m = vec3(1.0);
    vec2 pos = screenPos / maskScale;
    if (maskType < 1.5) {
        m = maskTv(pos);
    }
    else if (maskType < 2.5) {
        m = maskAperture(pos);
    }
    else if (maskType < 3.5) {
        m = maskVgaStretched(pos);
    }
    else if (maskType < 4.5) {
        m = maskVga(pos);
    }
    else {
        m = maskLcd(uv);
    }
    return m;
}

vec2 warp(vec2 pos) {
    vec2 p = pos * 2.0 - 1.0;
    p = p * vec2(1.0 + p.y * p.y * warpX, 1.0 + p.x * p.x * warpY);
    return p * 0.5 + 0.5;
}

float cornerMask(vec2 uv) {
    vec2 halfSize = resolution * 0.5;
    vec2 q = abs((uv - 0.5) * resolution) - (halfSize - cornerRadius);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - cornerRadius;
    return clamp(-d / max(cornerSmooth, 0.001), 0.0, 1.0);
}

float vignette(vec2 uv) {
    return sqrt(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void main(void) {
    vec2 uv = tcoord;
    vec2 screenPos = screenRect.xy + tcoord * screenRect.zw;
    if (warpX > 0.0 || warpY > 0.0) {
        uv = warp(uv);
    }
    float frame = cornerMask(uv);
    vec3 sharp = vec3(0.0);
    vec3 beam = vec3(0.0);
    float scanSharp = 1.0;
    float scanBeam = 1.0;
    if (beamAmount < 1.0) {
        sharp = sharpTexel(uv);
        if (scanlineStrength > 0.0) {
            float scale = beamScale(sharp);
            scanSharp = scan(uv, -1.0, scale) + scan(uv, 0.0, scale) + scan(uv, 1.0, scale);
        }
    }
    if (beamAmount > 0.0) {
        vec3 b = vec3(0.0);
        if (quality < 1.5) {
            b = horz3(uv, 0.0);
        }
        else {
            b = horz5(uv, 0.0);
        }
        float wb = scan(uv, 0.0, beamScale(b));
        if (quality < 0.5) {
            float offA = 1.0;
            if (dist(uv).y > 0.0) {
                offA = -1.0;
            }
            vec3 a = horz3(uv, offA);
            float wa = scan(uv, offA, beamScale(a));
            beam = (a * wa + b * wb) / (wa + wb);
            scanBeam = wa + wb;
        }
        else {
            vec3 a = horz3(uv, -1.0);
            vec3 c = horz3(uv, 1.0);
            float wa = scan(uv, -1.0, beamScale(a));
            float wc = scan(uv, 1.0, beamScale(c));
            beam = (a * wa + b * wb + c * wc) / (wa + wb + wc);
            scanBeam = wa + wb + wc;
        }
    }
    vec3 rgb = mix(sharp, beam, beamAmount);
    float scanSum = mix(scanSharp, scanBeam, beamAmount);
    rgb = rgb * mix(1.0, scanSum, scanlineStrength);
    if (bloomAmount > 0.0) {
        rgb = rgb + toLinear(texture(bloomTex, uv).rgb) * bloomAmount;
    }
    if (maskType > 0.5) {
        rgb = rgb * mask(uv, screenPos);
    }
    rgb = rgb * brightness;
    if (vignetteStrength > 0.0) {
        rgb = rgb * mix(1.0, vignette(uv), vignetteStrength);
    }
    rgb = colorMatrix * (rgb * luminance);
    rgb = toDisplay(rgb);
    if (noiseStrength > 0.0) {
        rgb = rgb + (hash(floor(screenPos) + fract(time) * 100.0) - 0.5) * noiseStrength;
    }
    if (flickerStrength > 0.0) {
        rgb = rgb * (1.0 + flickerStrength * sin(time * 120.0));
    }
    rgb = rgb * frame;
    fragColor = color * vec4(clamp(rgb, 0.0, 1.0), texture(mainTex, uv).a);
}

