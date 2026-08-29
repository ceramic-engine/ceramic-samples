package;

import ceramic.Scene;
import ceramic.Tween;

/**
 * A base scene implementing a custom "push" transition.
 *
 * `fadeIn()` is called automatically when the scene has finished
 * loading, and `fadeOut()` when it gets replaced as the main scene:
 * overriding them is all it takes to get scene transitions.
 *
 * Both scenes animate at the same time, but instead of cross-fading
 * on top of each other, they slide by the exact same amount with the
 * same easing and duration: the outgoing scene exits on one side
 * while the incoming one enters from the other, edge to edge. They
 * never overlap, and the whole transition still takes a single slide.
 *
 * `direction` is set just before replacing the main scene, so going
 * forward pushes to the left and going back pushes to the right.
 */
class TransitionScene extends Scene {

    static final TRANSITION_DURATION = 0.5;

    /**
     * The direction of the next push: `1` pushes to the left (forward),
     * `-1` pushes to the right (back). Both the outgoing and incoming
     * scene read it, so they always slide the same way.
     */
    public static var direction:Int = 1;

    override function fadeIn(done:()->Void) {

        // Enter from the side we are pushing towards, fully opaque
        x = width * direction;

        Tween.start(this, QUAD_EASE_IN_OUT, TRANSITION_DURATION, 0, 1, (value, time) -> {
            x = width * direction * (1 - value);
        }).onceComplete(this, done);

    }

    override function fadeOut(done:()->Void) {

        // Exit the opposite way in lockstep with the incoming scene,
        // so the two edges meet without ever overlapping
        Tween.start(this, QUAD_EASE_IN_OUT, TRANSITION_DURATION, 0, 1, (value, time) -> {
            x = -width * direction * value;
        }).onceComplete(this, done);

    }

}
