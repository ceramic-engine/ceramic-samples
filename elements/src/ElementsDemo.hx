package;

import ceramic.Scene;
import elements.Im;

class ElementsDemo extends Scene {

    override function create() {

        //

    }

    override function update(delta:Float) {

        Im.begin('Elements', 300);

        Im.editColor('Background color', Im.color(settings.background));

        Im.editText('App title', Im.string(settings.title));

        Im.end();

    }

}
