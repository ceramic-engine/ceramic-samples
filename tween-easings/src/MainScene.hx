package;

import ceramic.Color;
import ceramic.Easing;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Timer;
import ceramic.Tween;

class MainScene extends Scene {

    /**
     * Every easing displayed in the gallery, with its label
     */
    static final EASINGS:Array<{name:String, easing:Easing}> = [
        { name: 'LINEAR', easing: LINEAR },
        { name: 'QUAD_EASE_IN', easing: QUAD_EASE_IN },
        { name: 'QUAD_EASE_OUT', easing: QUAD_EASE_OUT },
        { name: 'QUAD_EASE_IN_OUT', easing: QUAD_EASE_IN_OUT },
        { name: 'CUBIC_EASE_IN', easing: CUBIC_EASE_IN },
        { name: 'CUBIC_EASE_OUT', easing: CUBIC_EASE_OUT },
        { name: 'CUBIC_EASE_IN_OUT', easing: CUBIC_EASE_IN_OUT },
        { name: 'QUART_EASE_IN_OUT', easing: QUART_EASE_IN_OUT },
        { name: 'QUINT_EASE_IN_OUT', easing: QUINT_EASE_IN_OUT },
        { name: 'EXPO_EASE_IN', easing: EXPO_EASE_IN },
        { name: 'EXPO_EASE_OUT', easing: EXPO_EASE_OUT },
        { name: 'EXPO_EASE_IN_OUT', easing: EXPO_EASE_IN_OUT },
        { name: 'SINE_EASE_IN_OUT', easing: SINE_EASE_IN_OUT },
        { name: 'BACK_EASE_IN', easing: BACK_EASE_IN },
        { name: 'BACK_EASE_OUT', easing: BACK_EASE_OUT },
        { name: 'BACK_EASE_IN_OUT', easing: BACK_EASE_IN_OUT },
        { name: 'BOUNCE_EASE_IN', easing: BOUNCE_EASE_IN },
        { name: 'BOUNCE_EASE_OUT', easing: BOUNCE_EASE_OUT },
        { name: 'ELASTIC_EASE_IN', easing: ELASTIC_EASE_IN },
        { name: 'ELASTIC_EASE_OUT', easing: ELASTIC_EASE_OUT },
        { name: 'ELASTIC_EASE_IN_OUT', easing: ELASTIC_EASE_IN_OUT },
        { name: 'BEZIER(0.7, 0, 0.3, 1)', easing: BEZIER(0.7, 0, 0.3, 1) }
    ];

    /**
     * How much room (as a fraction of the track) is reserved on each side for
     * easings that overshoot below 0 or above 1 (BACK, ELASTIC...). The tween
     * value 0..1 is mapped into the middle of the track so that even the largest
     * overshoot stays inside the track and never draws over the labels.
     */
    static inline final OVERSHOOT:Float = 0.4;

    static inline final DURATION:Float = 2.2;

    var dots:Array<Quad> = [];

    var trackStartX:Float = 0;

    var trackWidth:Float = 0;

    var forward:Bool = true;

    override function create() {

        var rows = EASINGS.length;
        var topMargin = 24.0;
        var bottomMargin = 16.0;
        var rowHeight = (height - topMargin - bottomMargin) / rows;
        var labelWidth = 172.0;
        var dotSize = Math.min(9, rowHeight - 2);

        // Leave a small gap after the labels: the mapping guarantees dots stay
        // within [trackStartX, trackStartX + trackWidth], i.e. never on the labels.
        trackStartX = labelWidth + 12;
        trackWidth = width - trackStartX - 18;

        // Title
        var title = new Text();
        title.content = 'Every Tween easing, side by side';
        title.pointSize = 14;
        title.color = Color.WHITE;
        title.anchor(0.5, 0.5);
        title.pos(width * 0.5, topMargin * 0.5);
        add(title);

        for (i in 0...rows) {

            var y = topMargin + rowHeight * (i + 0.5);

            // Easing name label
            var label = new Text();
            label.content = EASINGS[i].name;
            label.pointSize = 10;
            label.color = Color.GRAY;
            label.anchor(1, 0.5);
            label.pos(labelWidth, y);
            add(label);

            // Track line: only spans the normal 0 -> 1 travel, so overshoots
            // are visible as the dot leaving the line into the surrounding room.
            var lineStart = valueToX(0);
            var lineEnd = valueToX(1);
            var track = new Quad();
            track.color = Color.interpolate(Color.BLACK, Color.WHITE, 0.15);
            track.size(lineEnd - lineStart, 1);
            track.anchor(0, 0.5);
            track.pos(lineStart, y);
            add(track);

            // Moving dot, colored by row
            var dot = new Quad();
            dot.color = Color.fromHSB(360 * i / rows, 0.6, 1);
            dot.size(dotSize, dotSize);
            dot.anchor(0.5, 0.5);
            dot.pos(lineStart, y);
            add(dot);
            dots.push(dot);

        }

        // Start the animation loop
        animate();

    }

    /**
     * Map a tween value (which may go below 0 or above 1 when overshooting)
     * to an x position kept safely inside the track.
     */
    function valueToX(value:Float):Float {

        var norm = (value + OVERSHOOT) / (1 + 2 * OVERSHOOT);
        norm = Math.max(0, Math.min(1, norm));
        return trackStartX + trackWidth * norm;

    }

    function animate() {

        for (i in 0...dots.length) {

            var dot = dots[i];
            var from = forward ? 0.0 : 1.0;
            var to = forward ? 1.0 : 0.0;

            // Tween.start() is the low level way of creating tweens.
            // On visuals, you can also use the visual.tween(...) shorthand.
            Tween.start(this, EASINGS[i].easing, DURATION, from, to, (value, time) -> {
                dot.x = valueToX(value);
            });

        }

        // Wait for the tweens to finish (plus a short pause), then go the other way
        Timer.delay(this, DURATION + 1.0, () -> {
            forward = !forward;
            animate();
        });

    }

}
