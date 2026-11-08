package;

import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.theme.Theme;
import Pages;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.WindowExt;
using glaze.kit.base.StyledExt;

/**
 * The settings window: a title, a tab strip, the selected page and a footer.
 *
 * This component has an `@observe` field, so it is persistent: it is created
 * the first time its parent renders it, kept and found again on the next
 * renders (by the position of the `SettingsWindow.component()` call in the
 * parent's code), and destroyed when the parent stops rendering it. Changing
 * `tab` redraws this component only.
 */
class SettingsWindow extends Component {

    @prop var settings:Settings;

    /** The selected tab. Internal state: the parent does not know about it. */
    @observe var tab:Int = 0;

    static final TABS = ['General', 'Editor', 'Advanced'];

    function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return vFlex().sizeFull().bg(theme.background).textColor(theme.foreground)
            // Title and tabs
            .child(vFlex().gap4().px8().pt8().pb4()
                .child(div().textXl().fontSemibold().child('Settings'))
                // In a loop, every call has the same position in the code: `.at(key)`
                // tells the instances apart (it also names the component's root element)
                .child(hFlex().gap1().p1().roundedLg().bg(theme.secondary).wFull()
                    .children([for (i => name in TABS)
                        TabButton.component().at(name)
                            .label(name)
                            .selected(i == tab)
                            .onClick(() -> tab = i)
                    ])))
            // The page of the selected tab
            .child(div().flex1().overflowYScroll().px8()
                .child(switch tab {
                    case 0: GeneralPage.component().settings(settings);
                    case 1: EditorPage.component().settings(settings);
                    case _: AdvancedPage.component().settings(settings);
                }))
            // Footer: how many settings changed, and a button to reset them
            .child(hFlex().itemsCenter().justifyBetween().px8().py4().borderT1().borderColor(theme.border)
                .child(div().textSm().textColor(theme.mutedForeground)
                    .child(switch settings.changedCount {
                        case 0: 'All settings have their default value';
                        case 1: '1 setting changed';
                        case n: '$n settings changed';
                    }))
                .child(Button.component('restore').outline().label('Restore defaults')
                    .disabled(settings.changedCount == 0)
                    .onClick((_, window, cx) -> confirmRestore(window, cx))));
    }

    /** The kit's alert dialog: it closes on OK, cancel, escape and a click outside. */
    function confirmRestore(window:Window, cx:App):Void {
        window.openAlertDialog(cx, (alert, _, _) -> alert
            .title('Restore the default settings?')
            .description('Every setting goes back to its default value. This cannot be undone.')
            .confirm()
            .okText('Restore')
            .okVariant(Danger)
            .onOk((_, _, _) -> {
                settings.restoreDefaults();
                return true;
            }));
    }

}

/**
 * One tab of the strip. Props only, so it is rebuilt on every render of the
 * window, like an element.
 */
class TabButton extends Component {

    @prop var label:String = '';

    @prop var selected:Bool = false;

    @prop var onClick:() -> Void = null;

    function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return div().flex1().py1p5().roundedMd().textSm().textCenter().cursorPointer()
            .bg(selected ? theme.tabActive : theme.transparent)
            .textColor(selected ? theme.tabActiveForeground : theme.mutedForeground)
            .hover(s -> selected ? s : s.textColor(theme.foreground))
            .onClick(() -> if (onClick != null) onClick())  // element listeners accept `() -> Void`, `event -> Void` or `(event, window, cx) -> Void`
            .child(label);
    }

}
