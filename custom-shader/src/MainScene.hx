package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;

class MainScene extends Scene {

    // Typed shade shader: its @param uniforms become typed methods
    var plasmaShader:shaders.Plasma;

    var elapsed:Float = 0;

    override function preload() {

        // Our custom shader is written in Haxe with the cross-platform
        // shader system (see src/shaders/Plasma.hx). It is transpiled
        // to each backend's native shader language at build time.
        assets.add(shaders.Plasma);

    }

    override function create() {

        plasmaShader = assets.shader(shaders.Plasma);

        // A full-scene quad displaying our shader
        var quad = new Quad();
        quad.size(width, height);
        quad.color = Color.WHITE;
        quad.shader = plasmaShader;
        add(quad);

        var label = new Text();
        label.content = 'This animation runs on the GPU\nwith a custom shader written in Haxe (Plasma.hx)';
        label.align = CENTER;
        label.pointSize = 16;
        label.color = Color.WHITE;
        label.anchor(0.5, 0.5);
        label.pos(width * 0.5, height * 0.5);
        add(label);

    }

    override function update(delta:Float) {

        elapsed += delta;

        // Feed our custom uniforms every frame, using the typed setters
        // that shade generated from the @param declarations in Plasma.hx
        plasmaShader.time(elapsed);
        plasmaShader.resolution(width, height);

    }

}
