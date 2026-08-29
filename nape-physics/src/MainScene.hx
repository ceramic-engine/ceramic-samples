package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Timer;

class MainScene extends Scene {

    var spawned:Array<Quad> = [];

    override function create() {

        // Give some gravity to the default nape space
        app.nape.space.gravity.setxy(0, 600);

        // Static floor and walls: they collide but never move
        createStaticBox(width * 0.5, height - 10, width, 20);
        createStaticBox(10, height * 0.5, 20, height);
        createStaticBox(width - 10, height * 0.5, 20, height);

        // Two rotated bumpers in the middle
        createStaticBox(width * 0.3, height * 0.55, 200, 16, 24);
        createStaticBox(width * 0.7, height * 0.35, 200, 16, -24);

        var hint = new Text();
        hint.content = 'Click anywhere to drop boxes';
        hint.pointSize = 16;
        hint.color = Color.WHITE;
        hint.anchor(0.5, 0);
        hint.pos(width * 0.5, 16);
        hint.depth = 10;
        add(hint);

        // Drop a box wherever the pointer goes down
        screen.onPointerDown(this, info -> {
            spawnBox(info.x, info.y);
        });

        // Drop a first batch automatically so something happens right away
        for (i in 0...12) {
            Timer.delay(this, 0.15 * i, () -> {
                spawnBox(width * 0.25 + Math.random() * width * 0.5, -30);
            });
        }

    }

    function createStaticBox(x:Float, y:Float, w:Float, h:Float, rotation:Float = 0) {

        var box = new Quad();
        box.size(w, h);
        box.anchor(0.5, 0.5);
        box.pos(x, y);
        box.rotation = rotation;
        box.color = 0x3a3a46;
        add(box);

        // A STATIC body: part of the simulation, but immovable
        box.initNapePhysics(STATIC);

    }

    function spawnBox(x:Float, y:Float) {

        var size = 16 + Math.random() * 28;

        var box = new Quad();
        box.size(size, size);
        box.anchor(0.5, 0.5);
        box.pos(x, y);
        box.rotation = Math.random() * 90;
        box.color = Color.fromHSB(Math.random() * 360, 0.6, 0.95);
        add(box);

        // A DYNAMIC body: fully simulated (gravity, collisions, rotation).
        // The visual follows the physics body automatically.
        box.initNapePhysics(DYNAMIC);

        // Keep the amount of live bodies under control
        spawned.push(box);
        if (spawned.length > 80) {
            var oldest = spawned.shift();
            oldest.destroy();
        }

    }

}
