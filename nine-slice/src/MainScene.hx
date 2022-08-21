package;

import ceramic.NineSlice;
import ceramic.PixelArt;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Timer;
import ceramic.Utils;

class MainScene extends Scene {

    var pixelArt:PixelArt;

    var nineSlice:NineSlice;

    override function preload() {

        // Add any asset you want to load here

        assets.add(Images.YELLOW_BUTTON);

    }

    override function create() {

        // Render as low resolution / pixel art
        pixelArt = new PixelArt();
        pixelArt.size(width, height);
        app.scenes.filter = pixelArt;
        assets.texture(Images.YELLOW_BUTTON).filter = NEAREST;

        // Create nine slice
        nineSlice = new NineSlice();
        nineSlice.texture = assets.texture(Images.YELLOW_BUTTON);
        nineSlice.pos(10, 10);
        nineSlice.slice(
            5, // top
            6, // right
            9, // bottom
            6 // left
        );
        add(nineSlice);

    }

    override function update(delta:Float) {

        var ratio1 = Utils.sinRatio((Timer.now * 0.1) % 1.0);
        var ratio2 = Utils.sinRatio((Timer.now * 0.1 * 0.5) % 1.0);

        nineSlice.width = nineSlice.texture.width + (width - 20 - nineSlice.texture.width) * ratio1;
        nineSlice.height = nineSlice.texture.height + (height - 20 - nineSlice.texture.height) * ratio2;

    }

}
