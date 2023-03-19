package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.PixelArt;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 320;
        settings.targetHeight = 240;
        settings.windowWidth = 640;
        settings.windowHeight = 480;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        // Render as low resolution / pixel art
        var pixelArt = new PixelArt();
        pixelArt.bindToScreenSize();
        app.scenes.filter = pixelArt;

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

}
