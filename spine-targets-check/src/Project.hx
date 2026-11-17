package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Spine Targets Check';
        settings.background = Color.GRAY;
        settings.targetWidth = 1024;
        settings.targetHeight = 768;
        settings.scaling = FIT;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene();

    }

}
