package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.SceneSystem;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new ElementsDemo();

    }

}
