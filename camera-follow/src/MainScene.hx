package;

import ceramic.Camera;
import ceramic.Color;
import ceramic.Layer;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;

class MainScene extends Scene {

    static final WORLD_WIDTH:Float = 2000;

    static final WORLD_HEIGHT:Float = 1400;

    static final PLAYER_SPEED:Float = 320;

    var world:Layer;

    var player:Quad;

    var camera:Camera;

    override function create() {

        // The world layer contains everything the camera moves
        world = new Layer();
        world.size(WORLD_WIDTH, WORLD_HEIGHT);
        add(world);

        createWorldContent();

        // The player, moved with the keyboard
        player = new Quad();
        player.size(28, 28);
        player.anchor(0.5, 0.5);
        player.color = Color.WHITE;
        player.pos(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5);
        player.depth = 2;
        world.add(player);

        // The camera computes a transform that we assign to the world layer.
        // It smoothly tracks its target and stays inside the content bounds.
        camera = new Camera();
        camera.zoom = 1;
        camera.deadZoneX = 0.1;
        camera.deadZoneY = 0.15;
        world.transform = camera.contentTransform;

        // Start right on the player
        updateCamera(99999);

        var hint = new Text();
        hint.content = 'Move with WASD or arrow keys';
        hint.pointSize = 14;
        hint.color = Color.WHITE;
        hint.pos(16, 12);
        hint.depth = 10;
        add(hint);

    }

    function createWorldContent() {

        // A grid of lines so that motion is visible
        var gridStep = 100;
        var cols = Std.int(WORLD_WIDTH / gridStep);
        var rows = Std.int(WORLD_HEIGHT / gridStep);

        for (i in 0...cols + 1) {
            var line = new Quad();
            line.size(1, WORLD_HEIGHT);
            line.pos(i * gridStep, 0);
            line.color = 0x2a2a34;
            world.add(line);
        }
        for (j in 0...rows + 1) {
            var line = new Quad();
            line.size(WORLD_WIDTH, 1);
            line.pos(0, j * gridStep);
            line.color = 0x2a2a34;
            world.add(line);
        }

        // Some colored landmarks scattered around
        for (i in 0...60) {
            var quad = new Quad();
            var size = 12 + (i * 7) % 36;
            quad.size(size, size);
            quad.anchor(0.5, 0.5);
            quad.rotation = (i * 61) % 360;
            quad.color = Color.fromHSB((i * 47) % 360, 0.55, 0.85);
            quad.pos(
                60 + ((i * 733) % Std.int(WORLD_WIDTH - 120)),
                60 + ((i * 517) % Std.int(WORLD_HEIGHT - 120))
            );
            world.add(quad);
        }

    }

    override function update(delta:Float) {

        // Move the player with WASD (scan codes: layout independent) or arrows
        var moveX = 0.0;
        var moveY = 0.0;
        if (input.scanPressed(KEY_A) || input.scanPressed(LEFT)) moveX -= 1;
        if (input.scanPressed(KEY_D) || input.scanPressed(RIGHT)) moveX += 1;
        if (input.scanPressed(KEY_W) || input.scanPressed(UP)) moveY -= 1;
        if (input.scanPressed(KEY_S) || input.scanPressed(DOWN)) moveY += 1;

        if (moveX != 0 || moveY != 0) {
            var len = Math.sqrt(moveX * moveX + moveY * moveY);
            player.x += moveX / len * PLAYER_SPEED * delta;
            player.y += moveY / len * PLAYER_SPEED * delta;
            player.x = Math.max(14, Math.min(WORLD_WIDTH - 14, player.x));
            player.y = Math.max(14, Math.min(WORLD_HEIGHT - 14, player.y));
        }

        updateCamera(delta);

    }

    function updateCamera(delta:Float) {

        // Describe the viewport & content to the camera, target the player...
        camera.viewportWidth = width;
        camera.viewportHeight = height;
        camera.contentX = 0;
        camera.contentY = 0;
        camera.contentWidth = WORLD_WIDTH;
        camera.contentHeight = WORLD_HEIGHT;
        camera.followTarget = true;
        camera.target(player.x, player.y);

        // ... then let it compute the transform used by the world layer
        camera.update(delta);

    }

}
