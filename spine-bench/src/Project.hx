package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Spine Bench';
        settings.background = Color.BLACK;
        settings.targetWidth = 1024;
        settings.targetHeight = 768;
        settings.antialiasing = 0;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new BenchScene();

    }

}
