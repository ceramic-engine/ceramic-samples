package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.interpolate(Color.BLUE, Color.PURPLE, 0.2);
        settings.targetWidth = 160;
        settings.targetHeight = 120;
        settings.windowWidth = 800;
        settings.windowHeight = 600;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

}