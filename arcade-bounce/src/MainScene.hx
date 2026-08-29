package;

import ceramic.Color;
import ceramic.Group;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Visual;

class MainScene extends Scene {

    var balls:Group<Visual>;

    var zone:Quad;

    override function create() {

        // The default arcade world bounds follow the screen size
        var world = app.arcade.world;

        // A group gathers visuals that are tested for collisions together
        balls = new Group<Visual>('balls');

        for (i in 0...14) {
            spawnBall();
        }

        // An overlap zone: it doesn't block anything,
        // but we detect when a ball is inside it
        zone = new Quad();
        zone.size(180, 180);
        zone.anchor(0.5, 0.5);
        zone.pos(width * 0.5, height * 0.5);
        zone.color = 0x2a2a36;
        zone.depth = -1;
        add(zone);
        zone.initArcadePhysics();
        zone.immovable = true;
        zone.arcade.body.allowGravity = false;

        var zoneLabel = new Text();
        zoneLabel.content = 'overlap zone';
        zoneLabel.pointSize = 14;
        zoneLabel.color = Color.GRAY;
        zoneLabel.anchor(0.5, 0.5);
        zoneLabel.pos(width * 0.5, height * 0.5);
        zoneLabel.depth = 0;
        add(zoneLabel);

        var hint = new Text();
        hint.content = 'Click to add balls';
        hint.pointSize = 14;
        hint.color = Color.WHITE;
        hint.anchor(0, 0);
        hint.pos(16, 12);
        hint.depth = 10;
        add(hint);

        screen.onPointerDown(this, info -> {
            spawnBall(info.x, info.y);
        });

        // Physics run in the arcade update callback:
        // 1. balls collide (and bounce) against each other
        // 2. balls overlapping the zone get tinted red
        app.arcade.onUpdate(this, delta -> {

            // Make every ball collide (and bounce) with the others
            world.collide(balls);

            // Tint red the balls currently overlapping the zone.
            // overlap() only detects intersection, it doesn't move anything.
            for (ball in balls.items) {
                ball.asQuad.color = world.overlap(ball, zone) ? 0xE84855 : Color.WHITE;
            }

        });

    }

    function spawnBall(?x:Float, ?y:Float) {

        if (x == null) x = 40 + Math.random() * (width - 80);
        if (y == null) y = 40 + Math.random() * (height - 80);

        var size = 18 + Math.random() * 22;

        var ball = new Quad();
        ball.size(size, size);
        ball.anchor(0.5, 0.5);
        ball.pos(x, y);
        add(ball);

        // Enable physics on this visual, give it a velocity,
        // full bounce, and keep it inside the world bounds.
        // Arcade physics is axis-aligned (AABB): bodies never rotate,
        // which is what keeps it fast and predictable.
        ball.initArcadePhysics();
        var angle = Math.random() * Math.PI * 2;
        var speed = 120 + Math.random() * 160;
        ball.velocityX = Math.cos(angle) * speed;
        ball.velocityY = Math.sin(angle) * speed;
        ball.bounceX = 1;
        ball.bounceY = 1;
        ball.arcade.body.collideWorldBounds = true;

        balls.add(ball);

    }

}
