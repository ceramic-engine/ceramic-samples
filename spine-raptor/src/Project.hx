package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Spine Raptor';
        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FIT;
        settings.resizable = true;
        settings.targetDensity = 1;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new SpineRaptor();

    }

}
