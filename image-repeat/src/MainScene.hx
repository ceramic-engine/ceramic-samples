package;

import ceramic.Repeat;
import ceramic.Scene;
import ceramic.Timer;
import ceramic.Utils;
import elements.Im;

class MainScene extends Scene {

    var repeat:Repeat;

    override function preload() {

        // Add any asset you want to load here

        assets.add(Images.CERAMIC_MINI);

    }

    override function create() {

        // Create repeat
        repeat = new Repeat();
        repeat.texture = assets.texture(Images.CERAMIC_MINI);
        repeat.pos(10, 10);
        add(repeat);

    }

    override function update(delta:Float) {

        // Settings UI
        Im.begin('Settings');

        Im.beginRow();
        Im.text('Mirror');
        Im.check('X', Im.bool(repeat.mirrorX));
        Im.check('Y', Im.bool(repeat.mirrorY));
        Im.endRow();

        Im.beginRow();
        Im.slideFloat('Spacing X', Im.float(repeat.spacingX), 0, 32, 1);
        Im.endRow();

        Im.beginRow();
        Im.slideFloat('Spacing Y', Im.float(repeat.spacingY), 0, 32, 1);
        Im.endRow();

        Im.end();

        // Size animation
        var ratio1 = Utils.sinRatio((Timer.now * 0.1) % 1.0);
        var ratio2 = Utils.sinRatio((Timer.now * 0.1 * 0.5) % 1.0);

        repeat.width = repeat.texture.width * 0.5 + (width - 20 - repeat.texture.width * 0.5) * ratio1;
        repeat.height = repeat.texture.height * 0.5 + (height - 20 - repeat.texture.height * 0.5) * ratio2;

    }

}
