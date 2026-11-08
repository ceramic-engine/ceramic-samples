package;

import ceramic.Scene;
import glaze.Glaze;
import glaze.kit.IconName;
import glaze.kit.base.Root;
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

        // The kit initializes itself the first time it is used. `Glaze.app` is
        // the GPUI app context (the `cx` of the render signatures).
        Theme.change(ThemeMode.Dark, null, Glaze.app);

        // The kit's icons are SVG files: preload them (the web has no
        // synchronous file access), then open the window.
        IconName.preload(_ -> {
            // `Root` is the kit's root view: it applies the theme to the window.
            // `X.component()` places a component in the tree; its chained
            // setters are its props.
            ui = new Glaze(Root.builder(SettingsWindow.component().settings(settings)));
            ui.size(width, height);
            add(ui);
        });

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

}
