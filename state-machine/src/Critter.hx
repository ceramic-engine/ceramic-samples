package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.StateMachine;
import ceramic.Text;

enum abstract CritterState(Int) {

    /**
     * Wander peacefully between waypoints
     */
    var PATROL;

    /**
     * The pointer is nearby: chase it!
     */
    var CHASE;

    /**
     * The pointer got pressed close to the critter: run away!
     */
    var FLEE;

}

/**
 * A little square with a mind of its own, driven by a `StateMachine`.
 *
 * Because the machine is attached as a `Component`, methods named
 * `{STATE}_enter()`, `{STATE}_update(delta)` and `{STATE}_exit()`
 * are automatically wired to each state of the enum.
 */
class Critter extends Quad {

    @component var machine = new StateMachine<CritterState>();

    var label:Text;

    var patrolAngle:Float = 0;

    var patrolCenterX:Float;

    var patrolCenterY:Float;

    var fleeTime:Float = 0;

    /**
     * How close the pointer needs to be to trigger a chase
     */
    static final CHASE_DISTANCE:Float = 170;

    public function new(x:Float, y:Float) {

        super();

        size(32, 32);
        anchor(0.5, 0.5);
        pos(x, y);

        patrolCenterX = x;
        patrolCenterY = y;

        label = new Text();
        label.pointSize = 13;
        label.anchor(0.5, 1);
        label.pos(width * 0.5, -10);
        add(label);

        // React when the pointer is pressed anywhere on screen
        screen.onPointerDown(this, info -> {
            if (distanceToPointer() < CHASE_DISTANCE) {
                machine.state = FLEE;
            }
        });

        // Initial state
        machine.state = PATROL;

    }

    function distanceToPointer():Float {

        var dx = screen.pointerX - x;
        var dy = screen.pointerY - y;
        return Math.sqrt(dx * dx + dy * dy);

    }

    function moveToward(targetX:Float, targetY:Float, speed:Float, delta:Float) {

        var dx = targetX - x;
        var dy = targetY - y;
        var dist = Math.sqrt(dx * dx + dy * dy);
        if (dist > 1) {
            x += dx / dist * speed * delta;
            y += dy / dist * speed * delta;
        }

    }

/// PATROL

    function PATROL_enter() {

        color = Color.fromHSB(120, 0.6, 0.9);
        label.content = 'PATROL';
        label.color = color;

    }

    function PATROL_update(delta:Float) {

        // Wander in a circle around the patrol center
        patrolAngle += delta * 1.2;
        var targetX = patrolCenterX + Math.cos(patrolAngle) * 90;
        var targetY = patrolCenterY + Math.sin(patrolAngle) * 90;
        moveToward(targetX, targetY, 120, delta);

        // Transition: pointer came close
        if (distanceToPointer() < CHASE_DISTANCE) {
            machine.state = CHASE;
        }

    }

/// CHASE

    function CHASE_enter() {

        color = Color.fromHSB(35, 0.8, 1);
        label.content = 'CHASE';
        label.color = color;

        // A little jump on enter, to make the transition visible
        scale(1.35);
        tween(BACK_EASE_OUT, 0.3, 1.35, 1, (v, t) -> scale(v));

    }

    function CHASE_update(delta:Float) {

        moveToward(screen.pointerX, screen.pointerY, 180, delta);

        // Transition: pointer escaped
        if (distanceToPointer() > CHASE_DISTANCE * 1.2) {
            machine.state = PATROL;
        }

    }

/// FLEE

    function FLEE_enter() {

        color = Color.fromHSB(0, 0.8, 1);
        label.content = 'FLEE!';
        label.color = color;
        fleeTime = 0;

    }

    function FLEE_update(delta:Float) {

        // Run away from the pointer
        var dx = x - screen.pointerX;
        var dy = y - screen.pointerY;
        var dist = Math.max(1, Math.sqrt(dx * dx + dy * dy));
        x += dx / dist * 260 * delta;
        y += dy / dist * 260 * delta;

        // Stay on screen
        x = Math.max(20, Math.min(screen.width - 20, x));
        y = Math.max(20, Math.min(screen.height - 20, y));

        // Transition: calmed down after one second
        fleeTime += delta;
        if (fleeTime > 1.0) {
            patrolCenterX = x;
            patrolCenterY = y;
            machine.state = PATROL;
        }

    }

    function FLEE_exit() {

        // Just to demonstrate exit hooks
        log.info('Critter stopped fleeing');

    }

}
