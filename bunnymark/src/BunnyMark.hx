package;

import ceramic.Color;
import ceramic.MouseButton;
import ceramic.PixelArt;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.SeedRandom;
import ceramic.Text;

using ceramic.Extensions;

class Bunny extends Quad {

    public var velocityX:Float = 0;

    public var velocityY:Float = 0;

}

class BunnyMark extends Scene {

    static final bunnyKinds = [Images.BUNNY_1, Images.BUNNY_2, Images.BUNNY_3, Images.BUNNY_4, Images.BUNNY_5];

    var pixelArt:PixelArt = null;

    var background:Quad = null;

    var bunnies:Array<Bunny> = [];

    var random:SeedRandom = new SeedRandom(Math.random() * 1234567);

    var info:Text = null;

    var infoBg:Quad = null;

    var moving:Bool = true;

    var initialBunnies:Int = 10;

    override function preload() {

        for (kind in bunnyKinds) {
            assets.add(kind);
        }

    }

    override function create() {

        transparent = true;

        pixelArt = new PixelArt();
        pixelArt.size(width, height);
        pixelArt.depth = 1;
        add(pixelArt);

        background = new Quad();
        background.size(width, height);
        background.color = 0x333333;
        background.depth = 0;

        pixelArt.content.add(background);
        pixelArt.content.size(width, height);

        for (i in 0...initialBunnies) {
            createBunny();
        }

        info = new Text();
        info.content = '';
        info.pointSize = 16;
        info.anchor(1, 0);
        info.pos(width - 6, 3);
        info.color = Color.WHITE;
        info.depth = 2;
        add(info);

        infoBg = new Quad();
        infoBg.color = Color.BLACK;
        infoBg.alpha = 0.6;
        infoBg.depth = 1.9;
        infoBg.anchor(1, 0);
        infoBg.pos(width, 0);
        add(infoBg);

        screen.onPointerDown(this, info -> {
            if (info.buttonId == MouseButton.RIGHT) {
                moving = !moving;
            }
        });

    }

    override function resize(width:Float, height:Float) {

        if (pixelArt != null) {
            pixelArt.size(width, height);
            pixelArt.content.size(width, height);
        }

    }

    function createBunny() {

        var bunny = new Bunny();
        bunny.texture = assets.texture(bunnyKinds.randomElement());
        bunny.roundTranslation = 1;
        bunny.anchor(0.5, 0.5);
        bunny.depth = bunnies.length + 1;

        bunny.velocityX = random.random() * 12 - 6;
        bunny.y = height - bunny.height * 0.5;
        bunny.velocityY = -5;

        pixelArt.content.add(bunny);
        bunnies.push(bunny);

    }

    override function update(delta:Float) {

        info.content = 'FPS ${app.computedFps} / ${bunnies.length} bunnies';
        infoBg.size(info.width + 12, info.height + 6);

        // Moving?
        if (!moving) return;

        // Add bunnies
        if (screen.isPointerDown && !screen.mousePressed(MouseButton.RIGHT)) {
            for (i in 0...64) {
                createBunny();
            }
        }

        // Apply speed
        delta *= 32;

        // Screen boundaries
        var maxX = width;
        var maxY = height;

        // Physics constants
        var gravity = 0.5;
        var bounce = 0.95;
        var maxSpeed = 15;

        // Minimum velocity threshold for horizontal movement
        var minVelocity = 1.5;

        // Update each bunny
        for (i in 0...bunnies.length) {
            final bunny = bunnies[i];

            // Apply gravity
            bunny.velocityY += gravity * delta;

            // Ensure horizontal movement
            if (Math.abs(bunny.velocityX) < minVelocity) {
                // Give a stronger horizontal push
                bunny.velocityX += (random.random() * 4 - 2);
            }

            // Randomly add small velocity changes to horizontal movement only
            if (random.random() < 0.03) {
                bunny.velocityX += (random.random() * 3 - 1.5);
            }

            // Limit max speed for horizontal movement
            bunny.velocityX = Math.max(-maxSpeed, Math.min(maxSpeed, bunny.velocityX));

            // Update position
            var newX = bunny.x + bunny.velocityX * delta;
            var newY = bunny.y + bunny.velocityY * delta;

            // Check for edge collisions
            var halfWidth = bunny.width * 0.5;
            var halfHeight = bunny.height * 0.5;

            // Boolean to track if bunny is on the floor
            var isOnFloor = false;

            // Right edge
            if (newX + halfWidth > maxX) {
                newX = maxX - halfWidth;
                bunny.velocityX *= -bounce;
                bunny.velocityX -= 0.5; // Extra push away from wall
            }
            // Left edge
            else if (newX - halfWidth < 0) {
                newX = halfWidth;
                bunny.velocityX *= -bounce;
                bunny.velocityX += 0.5; // Extra push away from wall
            }

            // Bottom edge - ONLY place where jumping occurs
            if (newY + halfHeight > maxY) {
                newY = maxY - halfHeight;
                isOnFloor = true;

                // Only apply jumping velocity if on floor
                // Calculate velocity needed to reach top of screen
                var jumpHeight = maxY - 20; // Slightly less than full height
                var jumpVelocity = (gravity * jumpHeight * 0.1) * (0.55 + random.random() * 0.55); // Factor for reliable height

                // Set upward velocity - jumping!
                bunny.velocityY = -jumpVelocity;

                // Add horizontal jitter when jumping from ground
                bunny.velocityX += (random.random() * 5 - 2.5);

                // Ensure horizontal velocity doesn't get too small
                if (Math.abs(bunny.velocityX) < 3) {
                    bunny.velocityX = (bunny.velocityX > 0) ? 3 : -3;
                }
            }
            // Top edge
            else if (newY - halfHeight < 0) {
                newY = halfHeight;
                bunny.velocityY *= -bounce;
            }

            // Apply new position
            bunny.pos(newX, newY);
        }

    }

}
