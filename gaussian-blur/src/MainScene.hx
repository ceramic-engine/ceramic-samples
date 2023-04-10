package;

import ceramic.Quad;
import ceramic.Scene;
import elements.Im;

class MainScene extends Scene {

    var visual1:Quad;

    var visual2:Quad;

    var blurSize:Float = 8.0;

    override function preload() {

        assets.add(Images.CERAMIC);

    }

    override function create() {

        visual1 = new Quad();
        visual1.texture = assets.texture(Images.CERAMIC);
        visual1.anchor(0.5, 0.5);
        visual1.pos(width * 0.3, height * 0.65);
        visual1.rotation = -25;
        add(visual1);

        visual2 = new Quad();
        visual2.texture = assets.texture(Images.CERAMIC);
        visual2.anchor(0.5, 0.5);
        visual2.pos(width * 0.7, height * 0.35);
        visual2.rotation = 25;
        add(visual2);

    }

    override function update(delta:Float) {

        Im.begin('Settings');

        if (Im.slideFloat('Blur', Im.float(blurSize), 0, 8, 10)) {
            // Update blur shader blur size (shader initialized in Project.hx)
            app.scenes.filter.shader.setVec2('blurSize', blurSize, blurSize);
        }

        Im.end();

    }

}
