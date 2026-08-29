package;

import ceramic.Color;
import ceramic.Scene;
import ceramic.Text;

class MainScene extends Scene {

    override function create() {

        var critter = new Critter(width * 0.5, height * 0.5);
        add(critter);

        var hint = new Text();
        hint.content = 'Move the pointer near the critter to get chased.\nClick close to it to scare it away.';
        hint.align = CENTER;
        hint.pointSize = 14;
        hint.color = Color.WHITE;
        hint.anchor(0.5, 0);
        hint.pos(width * 0.5, 16);
        add(hint);

    }

}
