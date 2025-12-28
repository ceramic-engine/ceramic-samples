package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.SceneSystem;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 4;
        settings.background = 0x222222;
        settings.targetWidth = 800;
        settings.targetHeight = 600;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new GraphicsDemo();

    }

}