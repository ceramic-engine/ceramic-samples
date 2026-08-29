package;

import ceramic.Entity;
import ceramic.Color;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 1280;
        settings.targetHeight = 960;
        // RESIZE makes the logical screen size match the native screen size,
        // so the ImGui UI is displayed at its native scale (1 ImGui point =
        // 1 screen point), no matter how the window is sized. The game content
        // applies its own scaling instead (see MainScene).
        settings.scaling = RESIZE;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

}
