package;

import ceramic.Scene;
import glaze.Glaze;
import glaze.kit.Kit;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;

/**
 * A settings window written with Glaze components.
 *
 * The data lives in a small tracker model (`Settings`). The interface is a
 * tree of `glaze.Component` classes that read that model: when a value
 * changes, the components that read it are drawn again, nothing else.
 *
 * Read the files in this order: `Settings` (the model), `LabeledRow` and
 * `NumberStepper` (components with props and children), `Pages` (the kit
 * controls bound to the model) and `SettingsWindow` (a component with its
 * own state, and a confirmation dialog).
 */
class MainScene extends Scene {

    var ui:Glaze;

    var settings:Settings;

    override function create() {

        settings = new Settings();

        Theme.setMode(Dark);

        // `Kit.window()` adds what the kit components need around the view
        // (theme, dialogs, tooltips...)
        ui = new Glaze(Kit.window(SettingsWindow.component().settings(settings)));
        ui.size(width, height);
        add(ui);

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

}
