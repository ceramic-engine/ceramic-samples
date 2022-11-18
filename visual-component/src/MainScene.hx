package;

import ceramic.Quad;
import ceramic.Scene;

class MainScene extends Scene {

    var logo:Quad;

    override function preload() {

        assets.add(Images.CERAMIC);

    }

    override function create() {

        // Display logo
        logo = new Quad();
        logo.texture = assets.texture(Images.CERAMIC);
        logo.anchor(0.5, 0.5);
        logo.pos(width * 0.5, height * 0.5);
        add(logo);

        // Attach a RotateVisual component to it
        var rotateVisual = new RotateVisual();
        logo.component('rotateVisual', rotateVisual);

    }

}
