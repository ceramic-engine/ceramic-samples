package;

import ceramic.Assets;
import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    var assets:Assets;

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 0;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.resizable = true;
        settings.scaling = FIT;
        settings.orientation = LANDSCAPE;
        settings.fullscreen = false;
        settings.targetDensity = 2;

        app.onceReady(this, ready);

    }

    function ready() {

        // Set Demo as the current scene (see Demo.hx)
        app.scenes.main = new Demo();

    }

}
