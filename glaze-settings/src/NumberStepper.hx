package;

import glaze.App;
import glaze.Component;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.button.Button;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * An integer value with a minus and a plus button.
 *
 * The constructor's parameters become those of `NumberStepper.component(id)`.
 * The id names the root element, which keeps the ids of the two buttons
 * distinct between several steppers on the same page.
 *
 * The value is controlled: the component shows `value` and reports a change
 * through `onChange`; the parent writes the new value into the model, and the
 * component is drawn again with it.
 */
class NumberStepper extends Component {

    @prop var value:Int = 0;

    @prop var min:Int = 0;

    @prop var max:Int = 100;

    @prop var step:Int = 1;

    @prop var onChange:(value:Int) -> Void = null;

    final id:ElementIdArg;

    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    function set(next:Int):Void {
        if (next < min) next = min;
        if (next > max) next = max;
        if (next != value && onChange != null) onChange(next);
    }

    function render(window:Window, cx:App):IntoElement {
        return hFlex().id(id).itemsCenter().gap1()
            .child(Button.component('minus').outline().small().icon(IconName.Minus)
                .disabled(value <= min)
                .onClick(() -> set(value - step)))
            .child(div().w(px(36)).textCenter().textSm().child(Std.string(value)))
            .child(Button.component('plus').outline().small().icon(IconName.Plus)
                .disabled(value >= max)
                .onClick(() -> set(value + step)));
    }

}
