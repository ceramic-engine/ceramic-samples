package;

import ceramic.Text;
import ceramic.Entity;
import ceramic.Color;
import ceramic.InitSettings;
import ceramic.Shortcuts.*;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.title = 'Hello World';
        settings.antialiasing = 4;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FILL;

        app.onceReady(this, ready);

    }

    function ready() {

        // Add a "Hello World" text
        var text = new Text();
        text.color = Color.WHITE;
        text.content = 'Hello World';
        text.pointSize = 48;
        text.anchor(0.5, 0.5);
        text.pos(screen.width * 0.5, screen.height * 0.5);

    }

}
