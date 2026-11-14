package;

import ceramic.Entity;
import ceramic.InitSettings;

/**
 * Tests of the playground's interface (`../src/Playground.hx`) in a
 * headless Glaze window.
 *
 * Node: `ceramic headless run node --setup --assets`
 */
class Project extends Entity {

    function new(settings:InitSettings) {
        super();
        settings.targetWidth = 320;
        settings.targetHeight = 240;
        app.onceReady(this, ready);
    }

    function ready() {
        final failures = PlaygroundTests.run();
        #if js
        js.Syntax.code('process.exit({0})', failures == 0 ? 0 : 1);
        #else
        Sys.exit(failures == 0 ? 0 : 1);
        #end
    }

}
