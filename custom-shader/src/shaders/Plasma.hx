package shaders;

/**
 * A plasma effect, written with ceramic's cross-platform
 * shader system: this Haxe code is transpiled to the native
 * shader language of each backend (GLSL, ShaderLab...).
 */
class Plasma extends Shader<Plasma_Vert, Plasma_Frag> {}

class Plasma_Vert extends Vert {

    @param var projectionMatrix:Mat4;
    @param var modelViewMatrix:Mat4;

    @in var vertexPosition:Vec3;
    @in var vertexTCoord:Vec2;
    @in var vertexColor:Vec4;

    @out var tcoord:Vec2;
    @out var color:Vec4;
    // The vertex position, in quad space, forwarded to the fragment shader
    @out var quadPos:Vec2;

    function main():Vec4 {

        tcoord = vertexTCoord;
        color = vertexColor;
        quadPos = vertexPosition.xy;

        return projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);

    }

}

class Plasma_Frag extends Frag {

    @param var mainTex:Sampler2D;

    // Custom uniforms, set from Haxe code with setFloat()/setVec2()
    @param var time:Float;
    @param var resolution:Vec2;

    @in var tcoord:Vec2;
    @in var color:Vec4;
    @in var quadPos:Vec2;

    inline static final PI:Float = 3.14159265359;

    function main():Vec4 {

        // Normalized coordinates inside the quad
        var uvX:Float = (quadPos.x / resolution.x) * (resolution.x / resolution.y);
        var uvY:Float = quadPos.y / resolution.y;

        // A classic "plasma": several sine waves added together
        var v:Float = 0.0;
        v += sin((uvX * 6.0) + time);
        v += sin((uvY * 5.0) + time * 1.3);
        v += sin((uvX + uvY) * 5.0 + time * 0.7);
        var cx:Float = uvX + 0.5 * sin(time * 0.4);
        var cy:Float = uvY + 0.5 * cos(time * 0.5);
        v += sin(sqrt(cx * cx + cy * cy) * 12.0 + time);
        v *= 0.25;

        var rgb:Vec3 = vec3(
            0.5 + 0.5 * sin(PI * v),
            0.5 + 0.5 * sin(PI * v + 2.094),
            0.5 + 0.5 * sin(PI * v + 4.188)
        );

        return color * texture(mainTex, tcoord) * vec4(rgb, 1.0);

    }

}
