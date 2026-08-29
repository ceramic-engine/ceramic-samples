package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Text;
import ceramic.TouchInfo;

/**
 * A minimal clickable button made of a Quad and a Text.
 * Just enough for this sample: real projects may prefer
 * the `ui` plugin or the `elements` immediate mode API.
 */
class UiButton extends Quad {

    @event function click();

    var label:Text;

    public var content(get, set):String;
    function get_content():String return label.content;
    function set_content(content:String):String return label.content = content;

    public function new(content:String, width:Float = 170, height:Float = 32) {

        super();

        size(width, height);
        color = 0x3a3a46;

        label = new Text();
        label.content = content;
        label.pointSize = 14;
        label.color = Color.WHITE;
        label.anchor(0.5, 0.5);
        label.pos(width * 0.5, height * 0.5);
        add(label);

        onPointerDown(this, handlePointerDown);
        onPointerUp(this, handlePointerUp);

    }

    function handlePointerDown(info:TouchInfo) {

        color = 0x50505e;

    }

    function handlePointerUp(info:TouchInfo) {

        color = 0x3a3a46;

        if (hits(info.x, info.y)) {
            emitClick();
        }

    }

}
