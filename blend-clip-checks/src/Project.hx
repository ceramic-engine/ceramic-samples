package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Blend Clip Checks';
        settings.background = Color.BLACK;
        settings.targetWidth = 256;
        settings.targetHeight = 256;
        settings.antialiasing = 0;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new ChecksScene();

    }

}
