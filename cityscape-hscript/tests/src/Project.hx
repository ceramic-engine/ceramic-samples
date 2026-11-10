package;

import ceramic.Entity;
import ceramic.InitSettings;

/**
 * Unit tests of the hscript language server (`lib/hscriptls`): the
 * analyzer, the features and the JSON-RPC server, without an editor.
 *
 * Node: `ceramic headless run node --setup --assets`
 * macOS: `ceramic clay build mac --setup --assets`, then
 * `project/mac/tests.app/Contents/MacOS/tests` (hidden window).
 */
class Project extends Entity {

    function new(settings:InitSettings) {
        super();
        settings.targetWidth = 320;
        settings.targetHeight = 240;
        app.onceReady(this, ready);
    }

    function ready() {
        final failures = AnalyzerTests.run() + RuntimeTests.run();
        #if js
        js.Syntax.code('process.exit({0})', failures == 0 ? 0 : 1);
        #else
        Sys.exit(failures == 0 ? 0 : 1);
        #end
    }

}
