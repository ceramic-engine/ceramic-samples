package;

import ceramic.Color;
import ceramic.Entity;
import ceramic.InitSettings;
import ceramic.PixelArt;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.antialiasing = 0;
        settings.background = Color.BLACK;
        settings.targetWidth = 320;
        settings.targetHeight = 240;
        settings.windowWidth = 800;
        settings.windowHeight = 600;
        settings.scaling = FIT;
        settings.resizable = true;

        app.onceReady(this, ready);

    }

    function ready() {

        setupResolution();

        // Set MainScene as the current scene (see MainScene.hx)
        app.scenes.main = new MainScene();

    }

    function setupResolution() {

        // Render as low resolution / pixel art,
        // But with a larger grid so that we get smoother scroll
        var pixelArt = new PixelArt();
        pixelArt.sharpness = 1.0;
        function pixelArtLayout() {
            var scale:Float = Math.floor(Math.min(
                Math.min(
                    screen.nativeWidth * screen.nativeDensity / screen.width,
                    screen.nativeHeight * screen.nativeDensity / screen.height
                ),
                4.0
            ));
            pixelArt.size(
                Math.round(screen.width * scale),
                Math.round(screen.height * scale)
            );
        }
        screen.onResize(this, pixelArtLayout);
        pixelArtLayout();
        app.scenes.filter = pixelArt;

    }

}
