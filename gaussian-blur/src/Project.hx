package;

import ceramic.Assets;
import ceramic.Color;
import ceramic.Entity;
import ceramic.Filter;
import ceramic.InitSettings;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 2;
        settings.background = Color.BLACK;
        settings.targetWidth = 640;
        settings.targetHeight = 480;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceDefaultAssetsLoad(this, loadAssets);
        app.onceReady(this, ready);

    }

    function loadAssets(assets:Assets) {

        assets.add(shaders.GaussianBlur);

    }

    function ready() {

        // Use a filter for all scenes
        var filter = new Filter();
        filter.bindToScreenSize();
        app.scenes.filter = filter;

        // Assign a gaussian blur shader
        var blur = app.assets.shader(shaders.GaussianBlur).clone();
        blur.setVec2('resolution', filter.width, filter.height);
        blur.setVec2('blurSize', 8.0, 8.0);
        filter.shader = blur;

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

}
