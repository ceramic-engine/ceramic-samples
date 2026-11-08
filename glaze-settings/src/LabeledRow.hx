package;

import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * A settings row: a label (and an optional hint) on the left, the control on
 * the right.
 *
 * A component with props and children. `@prop` fields become chained setters
 * on `LabeledRow.component()`, and `children` is filled by the parent's
 * `.child(...)` / `.children(...)`. This class has no state of its own, so
 * the parent rebuilds it on every render, like a plain element.
 */
class LabeledRow extends Component {

    @prop var label:String = '';

    @prop var hint:String = null;

    function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return hFlex().itemsCenter().gap6().py3()
            .borderB1().borderColor(theme.border)
            .child(vFlex().gap0p5().w(px(280)).flexShrink0()
                .child(div().textSm().child(label))
                // A null child is skipped: `cond ? element : null` is the way to write a conditional child
                .child(hint != null ? div().textXs().textColor(theme.mutedForeground).child(hint) : null))
            .child(hFlex().itemsCenter().justifyEnd().flex1().children(children));
    }

}
