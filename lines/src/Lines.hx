package;

import ceramic.Color;
import ceramic.Line;
import ceramic.Scene;
import elements.Im;

class Lines extends Scene {

    var line1:Line;

    var line2:Line;

    var amplitude:Float = 50;

    var time:Float;

    override function create() {

        time = 0;

        line1 = new Line();
        line1.color = Color.WHITE;
        line1.thickness = 4;
        line1.points = [
            300, 50,
            600, 200
        ];
        add(line1);

        line2 = new Line();
        line2.color = Color.LIME;
        line2.thickness = 2;
        line2.points = [];
        updateLine2Points();
        add(line2);

    }

    override function update(delta:Float) {

        time += delta;

        updateLine2Points();

        debugUI();

    }

    function updateLine2Points() {

        var x = 50.0;
        var y = 350.0;
        var step = 2.0;
        var numSteps = 180;
        var points = line2.points;

        for (i in 0...numSteps) {

            points[i * 2] = x + i * step;
            points[i * 2 + 1] = y + Math.sin(time * 10 + i * 0.1) * amplitude;

        }

        line2.points = points;

    }

    function debugUI() {

        Im.begin('Line', 300);

        Im.text('Line 1');
        Im.editColor('Color', Im.color(line1.color));
        Im.slideFloat('Thickness', Im.float(line1.thickness), 4, 100, 0);

        Im.text('Line 2');
        Im.editColor('Color', Im.color(line2.color));
        Im.slideFloat('Thickness', Im.float(line2.thickness), 4, 100, 0);
        Im.slideFloat('Amplitude', Im.float(amplitude), 10, 80, 0);

        Im.end();

    }

}
