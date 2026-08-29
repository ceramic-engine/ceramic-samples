package;

import ceramic.Color;
import ceramic.Scene;
import ceramic.Sprite;
import ceramic.SpriteSheet;
import ceramic.Text;

class MainScene extends Scene {

    static final CHARACTERS:Int = 4;

    var sprite:Sprite;

    var character:Int = 0;

    var currentAnimText:Text;

    var instructions:Text;

    override function preload() {

        // The sprite sheet texture: a grid of 24x24 frames
        assets.add(Images.CHARACTERS);

    }

    override function create() {

        // Build a sprite sheet from the texture, in code.
        // (Sheets can also be loaded from aseprite files with the `ase` plugin)
        var texture = assets.texture(Images.CHARACTERS);
        texture.filter = NEAREST; // Crisp pixel art scaling

        var sheet = new SpriteSheet();
        sheet.texture = texture;
        sheet.grid(24, 24);

        // Each character uses two frames: standing and walking.
        // We register an 'idle' and a 'walk' animation per character.
        for (i in 0...CHARACTERS) {
            sheet.addGridAnimation('idle' + i, [i * 2], 0);
            sheet.addGridAnimation('walk' + i, [i * 2, i * 2 + 1], 0.15);
        }

        // Create and position the sprite
        sprite = new Sprite();
        sprite.sheet = sheet;
        sprite.anchor(0.5, 1);
        sprite.pos(width * 0.5, height * 0.55);
        sprite.scale(6); // Scale up for visibility
        sprite.animation = 'walk0';
        add(sprite);

        // UI text
        currentAnimText = new Text();
        currentAnimText.pointSize = 20;
        currentAnimText.color = Color.WHITE;
        currentAnimText.anchor(0.5, 0);
        currentAnimText.pos(width * 0.5, height * 0.62);
        add(currentAnimText);

        instructions = new Text();
        instructions.pointSize = 14;
        instructions.color = 0xcccccc;
        instructions.align = CENTER;
        instructions.anchor(0.5, 0);
        instructions.pos(width * 0.5, height * 0.72);
        add(instructions);

        updateTexts();

        // Keyboard input.
        // 'W' and 'I' are mnemonic shortcuts (Walk, Idle), so they are
        // matched by keyCode: the typed character, whatever the keyboard
        // layout. The digits row is positional, so it is matched by
        // scanCode: on layouts like AZERTY, that row types other
        // characters unless shift is held.
        input.onKeyDown(this, key -> {
            switch key.keyCode {

                case SPACE:
                    // Switch to the next character
                    character = (character + 1) % CHARACTERS;
                    sprite.animation = 'walk' + character;
                    updateTexts();

                case KEY_I:
                    sprite.animation = 'idle' + character;
                    updateTexts();

                case KEY_W:
                    sprite.animation = 'walk' + character;
                    updateTexts();

                case _:
            }
            switch key.scanCode {

                case KEY_1: sprite.timeScale = 0.5; updateTexts();
                case KEY_2: sprite.timeScale = 1.0; updateTexts();
                case KEY_3: sprite.timeScale = 1.5; updateTexts();
                case KEY_4: sprite.timeScale = 2.0; updateTexts();

                case _:
            }
        });

        // Clicking/tapping also switches character (for touch devices)
        screen.onPointerDown(this, _ -> {
            character = (character + 1) % CHARACTERS;
            sprite.animation = 'walk' + character;
            updateTexts();
        });

    }

    function updateTexts() {

        currentAnimText.content = 'animation: ' + sprite.animation;
        instructions.content =
            'SPACE or click: next character\n' +
            'W: walk, I: idle\n' +
            '1-4: speed (current: ' + sprite.timeScale + 'x)';

    }

    override function resize(width:Float, height:Float) {

        if (sprite != null) sprite.pos(width * 0.5, height * 0.55);
        if (currentAnimText != null) currentAnimText.pos(width * 0.5, height * 0.62);
        if (instructions != null) instructions.pos(width * 0.5, height * 0.72);

    }

}
