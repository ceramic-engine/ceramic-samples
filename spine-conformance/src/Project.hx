package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Spine Conformance';
        settings.background = Color.BLACK;
        settings.targetWidth = 1024;
        settings.targetHeight = 1024;
        settings.antialiasing = 0;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new ConformanceScene();

    }

}
