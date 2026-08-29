package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Text;
import ceramic.TouchInfo;

/**
 * A minimal horizontal slider: drag the knob (or click the track)
 * to change the value between `minValue` and `maxValue`.
 */
class UiSlider extends Quad {

    @event function valueChange(value:Float);

    public var value(default, set):Float;
    function set_value(value:Float):Float {
        value = Math.max(minValue, Math.min(maxValue, value));
        if (this.value != value) {
            this.value = value;
            updateKnob();
            emitValueChange(value);
        }
        return value;
    }

    var minValue:Float;

    var maxValue:Float;

    var knob:Quad;

    var label:Text;

    var title:String;

    public function new(title:String, minValue:Float, maxValue:Float, value:Float, width:Float = 260) {

        super();

        this.title = title;
        this.minValue = minValue;
        this.maxValue = maxValue;
        this.value = value;

        size(width, 6);
        color = 0x3a3a46;

        knob = new Quad();
        knob.size(14, 22);
        knob.color = Color.WHITE;
        knob.anchor(0.5, 0.5);
        knob.depth = 2;
        add(knob);

        label = new Text();
        label.pointSize = 12;
        label.color = Color.GRAY;
        label.anchor(0, 0.5);
        label.pos(width + 12, height * 0.5);
        add(label);

        // Handle both click and drag: while the pointer is down,
        // follow its moves at screen level (see quad-drag sample)
        onPointerDown(this, info -> {
            handlePointer(info);
            screen.onPointerMove(this, handlePointer);
            screen.oncePointerUp(this, _ -> {
                screen.offPointerMove(handlePointer);
            });
        });

        updateKnob();

    }

    static var _point = new ceramic.Point();

    function handlePointer(info:TouchInfo) {

        // Convert screen coordinates to this slider's local coordinates
        screenToVisual(info.x, info.y, _point);

        value = minValue + (maxValue - minValue) * Math.max(0, Math.min(1, _point.x / width));

    }

    function updateKnob() {

        if (knob == null) return;
        var ratio = (value - minValue) / (maxValue - minValue);
        knob.pos(width * ratio, height * 0.5);
        label.content = title + ': ' + Math.round(value * 100) / 100;

    }

}
