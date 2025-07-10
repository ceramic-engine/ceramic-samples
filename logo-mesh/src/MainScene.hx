package;

import ceramic.Quad;
import ceramic.Scene;
import elements.Im;

class MainScene extends Scene {

    var ceramicLogo:ceramic.CeramicLogo = null;

    override function create() {

        ceramicLogo = new ceramic.CeramicLogo();
        ceramicLogo.wireframe = true;
        ceramicLogo.depth = 2;
        ceramicLogo.resolution = 1;
        ceramicLogo.scale(2);
        ceramicLogo.anchor(0.5, 0.5);
        ceramicLogo.pos(width * 0.75, height * 0.5);
        add(ceramicLogo);

    }

    override function update(delta:Float) {

        Im.begin('Settings', 250);

        Im.check('Wireframe', Im.bool(ceramicLogo.wireframe));

        Im.slideFloat('Resolution', Im.float(ceramicLogo.resolution), 0.5, 4);

        Im.slideFloat('Tilt', Im.float(ceramicLogo.tilt), 0, 9);

        Im.end();

        ceramicLogo.translateY = -(ceramicLogo.tilt - 1) * ceramicLogo.height * ceramicLogo.scaleY * 0.0125;

    }

}
