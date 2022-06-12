package;

import ceramic.Color;
import ceramic.GeometryUtils;
import ceramic.InputMap;
import ceramic.Point;
import ceramic.Pool;
import ceramic.Quad;
import ceramic.Scene;

enum InputActions {

    TURN_LEFT;

    TURN_RIGHT;

    SHOOT;

    TURN_AXIS;

}

class MainScene extends Scene {

    static final BULLET_SPEED:Float = 150.0;

    static final TURN_SPEED:Float = 240.0;

    static final RECYCLE_DISTANCE:Float = 600.0;

    static var _direction = new Point();

    /**
     * To display the spaceship
     */
    var spaceship:Quad;

    /**
     * To handle input from multiple input devices (keyboard, gamepad...)
     */
    var inputMap:InputMap<InputActions>;

    /**
     * An object pool to recycle bullet objects without creating new ones each time
     */
    var bulletPool = new Pool<Quad>();

    /**
     * Bullets currently being visible
     */
    var bullets:Array<Quad> = [];

    override function preload() {

        assets.add(Images.SPACESHIP);

    }

    override function create() {

        spaceship = new Quad();
        spaceship.texture = assets.texture(Images.SPACESHIP);
        spaceship.anchor(0.5, 0.5);
        spaceship.pos(width * 0.5, height * 0.5);
        add(spaceship);

        // Use input map to allow input from multiple input devices (keyboard, gamepad...)
        inputMap = new InputMap();

        // Keyboard input
        //
        inputMap.bindKeyCode(TURN_LEFT, LEFT);
        inputMap.bindKeyCode(TURN_RIGHT, RIGHT);
        inputMap.bindKeyCode(SHOOT, UP);
        inputMap.bindKeyCode(SHOOT, SPACE);

        inputMap.bindScanCode(TURN_LEFT, KEY_A);
        inputMap.bindScanCode(TURN_RIGHT, KEY_D);
        inputMap.bindScanCode(SHOOT, KEY_W);

        // Gamepad input
        //
        inputMap.bindGamepadButton(TURN_LEFT, DPAD_LEFT);
        inputMap.bindGamepadButton(TURN_RIGHT, DPAD_RIGHT);
        inputMap.bindGamepadButton(SHOOT, DPAD_UP);
        inputMap.bindGamepadButton(SHOOT, A);
        inputMap.bindGamepadButton(SHOOT, R2);

        inputMap.bindGamepadAxis(TURN_AXIS, LEFT_X);

    }

    override function update(delta:Float) {

        turnShipIfNeeded(delta);

        updateBullets(delta);

    }

    function turnShipIfNeeded(delta:Float) {

        var turnValue = 0.0;

        // Check buttons that can let the spaceship turn
        if (inputMap.pressed(TURN_LEFT)) {
            turnValue = -0.5;
        }
        else if (inputMap.pressed(TURN_RIGHT)) {
            turnValue = 0.5;
        }
        else {
            // No button pressed, read axis value and use it
            // unless its too close to zero
            var axisValue = inputMap.axisValue(TURN_AXIS);
            if (Math.abs(axisValue) >= 0.1) {
                turnValue = axisValue;
            }
        }

        if (turnValue != 0.0) {
            // Turn the ship
            spaceship.rotation = GeometryUtils.clampDegrees(
                spaceship.rotation + turnValue * delta * TURN_SPEED
            );
        }

    }

    function updateBullets(delta:Float) {

        // Check if we did shoot this frame
        if (inputMap.justPressed(SHOOT)) {
            shootBullet(spaceship.rotation);
        }

        // Move all bullets
        var i = 0;
        while (i < bullets.length) {
            var bullet = bullets[i];
            GeometryUtils.angleDirection(bullet.rotation, _direction);
            bullet.x += _direction.x * BULLET_SPEED * delta;
            bullet.y += _direction.y * BULLET_SPEED * delta;

            var distance = GeometryUtils.distance(spaceship.x, spaceship.y, bullet.x, bullet.y);
            if (distance > RECYCLE_DISTANCE) {
                recycleBullet(bullet);
                bullets.remove(bullet);
            }
            else {
                i++;
            }
        }

    }

    function shootBullet(rotation:Float) {

        // Create or reuse a bullet
        var bullet = bulletPool.get();
        if (bullet == null) {
            bullet = new Quad();
            bullet.color = Color.WHITE;
            bullet.size(4, 10);
            bullet.anchor(0.5, 0);
            add(bullet);
        }
        else {
            // Make this bullet visible again
            bullet.active = true;
        }

        // Place bullet in front of the ship
        GeometryUtils.angleDirection(rotation, _direction);
        bullet.rotation = rotation;
        bullet.pos(spaceship.x + _direction.x * 32, spaceship.y + _direction.y * 32);

        // Keep a reference to this bullet to move it over time
        bullets.push(bullet);

    }

    function recycleBullet(bullet:Quad) {

        // Make this bullet invisible as we don't use it anymore
        bullet.active = false;

        // Recycle it in the pool
        bulletPool.recycle(bullet);

    }

}
