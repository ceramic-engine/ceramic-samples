package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Text;

class GameScene extends TransitionScene {

    var spinner:Quad;

    override function create() {

        // A full-size opaque background, so the scene reads as a
        // solid panel while it slides during the push transition
        var background = new Quad();
        background.size(width, height);
        background.color = Color.fromHSB(140, 0.35, 0.28);
        background.depth = -10;
        add(background);

        var title = new Text();
        title.content = 'GAME';
        title.pointSize = 52;
        title.color = Color.fromHSB(120, 0.5, 1);
        title.anchor(0.5, 0.5);
        title.pos(width * 0.5, height * 0.3);
        add(title);

        spinner = new Quad();
        spinner.size(64, 64);
        spinner.color = Color.fromHSB(120, 0.5, 0.9);
        spinner.anchor(0.5, 0.5);
        spinner.pos(width * 0.5, height * 0.5);
        add(spinner);

        var backButton = new UiButton('Back to menu');
        backButton.anchor(0.5, 0.5);
        backButton.pos(width * 0.5, height * 0.7);
        backButton.onClick(this, () -> {
            // Push to the right when going back, so the transition
            // plays as the reverse of the forward one
            TransitionScene.direction = -1;
            app.scenes.main = new MenuScene();
        });
        add(backButton);

    }

    override function update(delta:Float) {

        // Some in-game motion, to make both scenes clearly different
        spinner.rotation += delta * 90;

    }

}
