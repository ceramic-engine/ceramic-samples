package;

import arcade.Body;
import arcade.Direction;
import ceramic.ArcadeWorld;
import ceramic.Assets;
import ceramic.Group;
import ceramic.InputMap;
import ceramic.Sprite;
import ceramic.SpriteSheet;
import ceramic.StateMachine;
import ceramic.Tilemap;
import ceramic.VisualArcadePhysics;

/**
 * The different states the player can have.
 */
enum abstract PlayerState(Int) {

    /**
     * Player's default state: walking or not moving at all
     */
    var DEFAULT;

    /**
     * Player is jumping
     */
    var JUMP;

}

/**
 * The input keys that will make player interaction
 */
enum abstract PlayerInput(Int) {

    var RIGHT;

    var LEFT;

    var DOWN;

    var UP;

    var JUMP;

}

class Player extends Sprite {

    var ladderSpeed:Float = 50;

    var tileWidth:Int = 18;

    var tileHeight:Int = 18;

    var tilemap:Tilemap = null;

    /**
     * A state machine plugged as a `Component` to `Player` using `PlayerState`
     * as an enum that provides the different possible states.
     *
     * Because this state machine is here, `{STATE}_enter()/update()/exit()` are
     * automatically called if they exist in the `Player` class and the corresponding
     * state is the current machine's state.
     */
    @component var machine = new StateMachine<PlayerState>();

    var inputMap = new InputMap<PlayerInput>();

    public var isBottomOnLadder:Bool = false;

    public var isTopOnLadder:Bool = false;

    /**
     * A smaller physics body used to know
     * if the player bottom is on a ladder or not
     */
    public var dotBodyBottom(default, null) = new Body(0, 0, 2, 2);

    /**
     * A smaller physics body used to know
     * if the player top is on a ladder or not
     */
    public var dotBodyTop(default, null) = new Body(0, 0, 2, 2);

    public function new(assets:Assets) {

        super();

        // We'll set size ourself
        autoComputeSize = false;

        // Ensure physics are enabled
        initArcadePhysics();

        // Make this body collide with world bounds
        body.collideWorldBounds = true;

        // Create sprite sheet needed for this player
        sheet = new SpriteSheet();
        sheet.texture = assets.texture(Images.CHARACTERS);
        sheet.grid(24, 24);
        sheet.addGridAnimation('idle', [0], 0);
        sheet.addGridAnimation('walk', [1, 0], 0.1);
        sheet.addGridAnimation('jump', [1], 0);

        // Correct anchor
        anchor(0.5, 1);

        // Ensure the final/visible position will always be rounded
        quad.roundTranslation = 1;

        // Set player gravity
        gravityY = 400;

        // Default animation
        animation = 'idle';

        // Default direction
        scaleX = -1;

        // Actual size used by physics
        size(18, 22);
        frameOffset(-3, -2);

        // Init input
        bindInput();

        // Default state
        machine.state = DEFAULT;

    }

    public function updatePhysics(delta:Float, world:ArcadeWorld, tilemap:Tilemap, boxes:Group<Box>) {

        // Keep tilemap up to date
        this.tilemap = tilemap;

        // Update dot body
        updateDotBodies();

        // Check if player is on a ladder
        isBottomOnLadder = world.overlap(dotBodyBottom, tilemap.layer('ladders'));
        isTopOnLadder = world.overlap(dotBodyTop, tilemap.layer('ladders'));

        // Update ladder state
        updateLadder();

        // Collide player with boxes
        world.collide(this, boxes);

        // Collide player with tilemap at each frame
        world.collide(this, tilemap);

    }

    function updateDotBodies() {

        dotBodyBottom.x = x - dotBodyBottom.width * 0.5;
        dotBodyBottom.y = y - dotBodyBottom.height;

        dotBodyTop.x = x - dotBodyTop.width * 0.5;
        dotBodyTop.y = y - height;

    }

    function updateLadder() {

        // Handle ladder specifics
        if (isBottomOnLadder && (machine.state == DEFAULT || isTopOnLadder)) {
            forceX = true;
            gravityY = 0;
            velocity(0, 0);
        }
        else {
            forceX = false;
            gravityY = 400;
        }

    }

    override function update(delta:Float) {

        // Update sprite
        super.update(delta);

    }

    function bindInput() {

        // Bind keyboard
        //
        inputMap.bindKeyCode(RIGHT, RIGHT);
        inputMap.bindKeyCode(LEFT, LEFT);
        inputMap.bindKeyCode(DOWN, DOWN);
        inputMap.bindKeyCode(UP, UP);
        inputMap.bindKeyCode(JUMP, SPACE);
        // We use scan code for these so that it
        // will work with non-qwerty layouts as well
        inputMap.bindScanCode(RIGHT, KEY_D);
        inputMap.bindScanCode(LEFT, KEY_A);
        inputMap.bindScanCode(DOWN, KEY_S);
        inputMap.bindScanCode(UP, KEY_W);

        // Bind gamepad
        //
        inputMap.bindGamepadAxisToButton(RIGHT, LEFT_X, 0.25);
        inputMap.bindGamepadAxisToButton(LEFT, LEFT_X, -0.25);
        inputMap.bindGamepadAxisToButton(DOWN, LEFT_Y, 0.25);
        inputMap.bindGamepadAxisToButton(UP, LEFT_Y, -0.25);
        inputMap.bindGamepadButton(RIGHT, DPAD_RIGHT);
        inputMap.bindGamepadButton(LEFT, DPAD_LEFT);
        inputMap.bindGamepadButton(DOWN, DPAD_DOWN);
        inputMap.bindGamepadButton(UP, DPAD_UP);
        inputMap.bindGamepadButton(JUMP, A);

    }

    @:allow(Box)
    function triggerBox(box:Box) {

        log.debug('Player triggers box. (it doesn\'t do anything in this sample, just showcasing the raw feature)');

    }

    function DEFAULT_update(delta) {

        testMove(delta);
        testJump();

    }

    function JUMP_enter() {

        velocityY = -180;

    }

    function JUMP_update(delta:Float) {

        if (isTopOnLadder || (isBottomOnLadder && velocityY > 0) || body.blockedDown) {
            machine.state = DEFAULT;
        }

        testMove(delta);

    }

/// Helpers

    function testJump() {

        if (!isTopOnLadder && (inputMap.justPressed(JUMP) || (!isBottomOnLadder && inputMap.justPressed(UP))) && (body.blockedDown || isBottomOnLadder)) {
            machine.state = JUMP;
            animation = 'jump';
        }

    }

    function testMove(delta:Float) {

        var blockedDown = body.blockedDown;
        var canMoveLeftRight = (!isBottomOnLadder || (!inputMap.pressed(UP) && !inputMap.pressed(DOWN)));

        if (inputMap.pressed(RIGHT) && canMoveLeftRight) {
            velocityX = 120;
            if (machine.state == DEFAULT) {
                animation = blockedDown || isBottomOnLadder ? 'walk' : 'jump';
            }
            scaleX = -1;
        }
        else if (inputMap.pressed(LEFT) && canMoveLeftRight) {
            velocityX = -120;
            if (machine.state == DEFAULT) {
                animation = blockedDown || isBottomOnLadder ? 'walk' : 'jump';
            }
            scaleX = 1;
        }
        else {
            velocityX = 0;
            if (machine.state == DEFAULT) {
                if (!isBottomOnLadder || (!inputMap.pressed(UP) && !inputMap.pressed(DOWN) && !inputMap.pressed(LEFT) && !inputMap.pressed(RIGHT))) {
                    animation = 'idle';
                    x = Math.round(x);
                }
            }
        }

        if (isBottomOnLadder) {
            /*
            if (inputMap.pressed(DOWN) || inputMap.pressed(UP)) {
                var betterX = Math.floor(x / 18) * 18 + 9;
                if (betterX > x + 1.5) {
                    x += Math.min(betterX - x, 1) * delta * 60;
                }
                else if (betterX < x - 1.5) {
                    x -= Math.min(x - betterX, 1) * delta * 60;
                }
                else {
                    x = betterX;
                }
            }
            if (inputMap.pressed(DOWN)) {
                velocityY = 50;
                if (machine.state == DEFAULT) {
                    animation = 'walk';
                }
            }
            else if (inputMap.pressed(UP)) {
                velocityY = -50;
                if (machine.state == DEFAULT) {
                    animation = 'walk';
                }
            }
            */
            if (inputMap.pressed(DOWN) || inputMap.pressed(UP)) {
                var betterX = Math.floor(x / tileWidth) * tileWidth + tileWidth * 0.5;
                if (betterX > x + 1.5) {
                    x += Math.min(betterX - x, 1) * delta * 60;
                }
                else if (betterX < x - 1.5) {
                    x -= Math.min(x - betterX, 1) * delta * 60;
                }
                else {
                    x = betterX;
                }
            }
            if (inputMap.pressed(DOWN)) {
                velocityY = ladderSpeed;
                if (machine.state == DEFAULT) {
                    animation = 'walk';
                }
            }
            else if (inputMap.pressed(UP)) {
                velocityY = -ladderSpeed;
                if (machine.state == DEFAULT) {
                    animation = 'walk';
                }
            }
            else if ((inputMap.pressed(RIGHT) && body.blockedRight) || (inputMap.pressed(LEFT) && body.blockedLeft)) {

                var playerCenterY = (y - height * 0.4);
                var betterTileY = Math.floor(playerCenterY / tileHeight);
                var betterTileX = Math.floor(x / tileWidth);
                if (inputMap.pressed(RIGHT))
                    betterTileX++;
                else
                    betterTileX--;

                var betterTileY2 = if ((betterTileY + 0.5) * tileHeight < playerCenterY) {
                    betterTileY + 1;
                }
                else {
                    betterTileY - 1;
                }

                var direction:Direction = inputMap.pressed(RIGHT) ? RIGHT : LEFT;
                var testX = (betterTileX + 0.5) * tileWidth;
                var testY = (betterTileY + 0.5) * tileHeight;
                var testY2 = (betterTileY2 + 0.5) * tileHeight;
                var isWall = tilemap.shouldCollideAtPosition(testX, testY, direction);
                var isWall2 = tilemap.shouldCollideAtPosition(testX, testY2, direction);

                if (isWall && !isWall2) {
                    var betterTileTmp = betterTileY;
                    betterTileY = betterTileY2;
                    betterTileY2 = betterTileTmp;
                    isWall = false;
                    isWall2 = true;
                }

                if (!isWall && isWall2) {

                    var betterY = (betterTileY + 0.5) * tileHeight + y - playerCenterY;
                    if (betterY > y - 1.5) {
                        y += Math.min(betterY - y, 1) * delta * ladderSpeed;
                    }
                    else if (betterY < y + 1.5) {
                        y -= Math.min(y - betterY, 1) * delta * ladderSpeed;
                    }
                    else {
                        y = betterY;
                    }
                }
            }
        }

    }

}
