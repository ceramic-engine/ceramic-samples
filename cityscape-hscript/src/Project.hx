package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.Platform;

/**
 * A Cityscape sample: an editor for hscript, Haxe's scripting language,
 * with a language server written in Haxe, and a canvas the scripts draw on.
 *
 * Captures (`--variant capture`, see the README): `CS_HSCRIPT_OUT` is the
 * PNG path, `CS_HSCRIPT_SCENE` the scene (see `MainScene`).
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.fromRGB(0x18, 0x18, 0x18);
        settings.targetWidth = 1400;
        settings.targetHeight = 860;
        settings.scaling = RESIZE;
        settings.resizable = true;
        settings.title = 'Cityscape hscript';
        // A frame is drawn only when something changed: the latency of a keystroke
        // is lower when the app was at rest (see `ceramic.Settings.renderOnDemand`)
        settings.renderOnDemand = true;
        // Everything on screen is drawn by Glaze, which asks for its own renders: no
        // need to draw a frame each time a timer or a language server callback runs
        settings.renderAfterTimersAndInput = false;

        app.onceReady(this, ready);

    }

    function ready() {

        app.scenes.main = new MainScene(env('CS_HSCRIPT_SCENE'), env('CS_HSCRIPT_OUT'));

    }

    static function env(name:String):Null<String> {
        final value = Platform.getEnv(name);
        return value != null && value != '' ? value : null;
    }

}
