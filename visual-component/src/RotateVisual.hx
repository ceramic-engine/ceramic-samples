package;

import ceramic.Visual;
import ceramic.Entity;
import ceramic.Component;
import ceramic.Timer;

/**
 * An example of component that creates a rotating
 * animation with the visual attached to it
 */
class RotateVisual extends Entity implements Component {

    /**
     * This will be the visual we attached to
     */
    @entity var visual:Visual;

    /**
     * The duration of each rotation
     */
    public var duration:Float;

    /**
     * The pause between each rotation
     */
    public var pause:Float;

    public function new(duration:Float = 2.0, pause:Float = 1.0) {

        super();

        this.duration = duration;
        this.pause = pause;

    }

    function bindAsComponent() {

        // Start rotating when the component
        // is attached to a visual
        rotateOnce();

    }

    function rotateOnce() {

        // Animate rotation
        visual.tween(ELASTIC_EASE_IN_OUT, duration, 0, 360, (value, time) -> {
            visual.rotation = value;
        })
        // And repeat
        .onceComplete(this, () -> {
            Timer.delay(this, pause, rotateOnce);
        });

    }

}