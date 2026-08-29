package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Text;

class MenuScene extends TransitionScene {

    override function create() {

        // A full-size opaque background, so the scene reads as a
        // solid panel while it slides during the push transition
        var background = new Quad();
        background.size(width, height);
        background.color = Color.fromHSB(210, 0.35, 0.28);
        background.depth = -10;
        add(background);

        var title = new Text();
        title.content = 'MENU';
        title.pointSize = 52;
        title.color = Color.WHITE;
        title.anchor(0.5, 0.5);
        title.pos(width * 0.5, height * 0.35);
        add(title);

        // A few decorative quads
        for (i in 0...5) {
            var quad = new Quad();
            quad.size(24, 24);
            quad.color = Color.fromHSB(200 + i * 24, 0.5, 0.9);
            quad.anchor(0.5, 0.5);
            quad.pos(width * 0.5 + (i - 2) * 48, height * 0.5);
            quad.rotation = 45;
            add(quad);
        }

        var startButton = new UiButton('Start game');
        startButton.anchor(0.5, 0.5);
        startButton.pos(width * 0.5, height * 0.65);
        startButton.onClick(this, () -> {
            // Replacing the main scene automatically triggers
            // the fade-out of this scene and the fade-in of the new one.
            // Push to the left when going forward.
            TransitionScene.direction = 1;
            app.scenes.main = new GameScene();
        });
        add(startButton);

    }

}
