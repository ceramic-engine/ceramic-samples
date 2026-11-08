package;

import glaze.App;
import glaze.Component;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.input.Input;
import glaze.kit.searchablelist.SearchableListItem.SearchableListItemBase;
import glaze.kit.select.Select;
import glaze.kit.slider.Slider;
import glaze.kit.switch_.Switch;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

/**
 * The three pages of the window. Each one is a component with a single prop,
 * the model, and a list of `LabeledRow`s holding kit controls.
 *
 * The controls are controlled: they show a value read from the model and
 * write it back in `onChange`. Since the model fields are observable, the
 * page is drawn again with the new value.
 */
class GeneralPage extends Component {

    @prop var settings:Settings;

    function render(window:Window, cx:App):IntoElement {
        return vFlex()
            .child(LabeledRow.component().label('Display name').hint('Shown to other people')
                // `Input.component()` creates its text state on the first render and keeps it
                // for as long as the input stays in the tree, under the identity of the call
                .child(div().w(px(240)).child(Input.component().at('name')
                    .placeholder('Your name')
                    .value(settings.displayName)
                    .onChange(v -> settings.displayName = v))))
            .child(LabeledRow.component().label('Language')
                .child(div().w(px(240)).child(Select.component().at('language')
                    .options([
                        new Choice('en', 'English'),
                        new Choice('fr', 'Français'),
                        new Choice('de', 'Deutsch'),
                        new Choice('ja', '日本語'),
                    ])
                    .value(settings.language)
                    .onChange(v -> settings.language = v))))
            .child(LabeledRow.component().label('Theme')
                .child(div().w(px(240)).child(Select.component().at('theme')
                    .options([
                        new Choice('dark', 'Dark'),
                        new Choice('light', 'Light'),
                    ])
                    .value(settings.theme)
                    .onChange(v -> {
                        settings.theme = v;
                        Theme.setMode(v == 'light' ? ThemeMode.Light : ThemeMode.Dark);
                    }))))
            .child(LabeledRow.component().label('Autosave').hint('Save documents while you type')
                .child(Switch.component('autosave')
                    .checked(settings.autosave)
                    .onChange(on -> settings.autosave = on)))
            // A conditional row: `null` adds nothing to the tree
            .child(settings.autosave
                ? LabeledRow.component().label('Autosave interval').hint('Minutes between two saves')
                    .child(NumberStepper.component('autosave-interval')
                        .value(settings.autosaveInterval).min(1).max(60)
                        .onChange(v -> settings.autosaveInterval = v))
                : null);
    }

}

class EditorPage extends Component {

    @prop var settings:Settings;

    function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return vFlex()
            .child(LabeledRow.component().label('Font size')
                .child(hFlex().itemsCenter().gap3()
                    .child(div().w(px(180)).child(Slider.component().at('font-size')
                        .min(10).max(24).step(1)
                        .value(settings.fontSize)
                        .onChange(v -> settings.fontSize = v)))
                    .child(div().w(px(40)).textSm().textColor(theme.mutedForeground).child('${settings.fontSize} px'))))
            .child(LabeledRow.component().label('Tab size').hint('Spaces per indentation level')
                .child(NumberStepper.component('tab-size')
                    .value(settings.tabSize).min(1).max(8)
                    .onChange(v -> settings.tabSize = v)))
            .child(LabeledRow.component().label('Line numbers')
                .child(Switch.component('line-numbers')
                    .checked(settings.lineNumbers)
                    .onChange(on -> settings.lineNumbers = on)))
            .child(LabeledRow.component().label('Word wrap').hint('Break long lines at the edge of the editor')
                .child(Switch.component('word-wrap')
                    .checked(settings.wordWrap)
                    .onChange(on -> settings.wordWrap = on)))
            .child(settings.wordWrap
                ? LabeledRow.component().label('Wrapped line indent').hint('Extra spaces in front of wrapped lines')
                    .child(NumberStepper.component('wrap-indent')
                        .value(settings.wrapIndent).min(0).max(8)
                        .onChange(v -> settings.wrapIndent = v))
                : null);
    }

}

class AdvancedPage extends Component {

    @prop var settings:Settings;

    function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        return vFlex()
            .child(LabeledRow.component().label('Hardware acceleration').hint('Takes effect after a restart')
                .child(Switch.component('hardware-acceleration')
                    .checked(settings.hardwareAcceleration)
                    .onChange(on -> settings.hardwareAcceleration = on)))
            .child(LabeledRow.component().label('Send usage statistics').hint('Anonymous, never includes your documents')
                .child(Switch.component('telemetry')
                    .checked(settings.telemetry)
                    .onChange(on -> settings.telemetry = on)))
            .child(LabeledRow.component().label('Cache size')
                .child(hFlex().itemsCenter().gap3()
                    .child(div().w(px(180)).child(Slider.component().at('cache-size')
                        .min(128).max(4096).step(128)
                        .value(settings.cacheSize)
                        .onChange(v -> settings.cacheSize = Std.int(v))))
                    .child(div().w(px(64)).textSm().textColor(theme.mutedForeground).child('${settings.cacheSize} MB'))))
            .child(LabeledRow.component().label('Log level')
                .child(div().w(px(240)).child(Select.component().at('log-level')
                    .options([
                        new Choice('error', 'Errors only'),
                        new Choice('warning', 'Warnings'),
                        new Choice('info', 'Information'),
                        new Choice('debug', 'Debug'),
                    ])
                    .value(settings.logLevel)
                    .onChange(v -> settings.logLevel = v))));
    }

}

/**
 * An option of a `Select`: the value stored in the model and the label shown.
 * (`Select.component().options([...])` accepts strings, or items like this one.)
 */
class Choice extends SearchableListItemBase {

    final choiceValue:String;

    final label:String;

    public function new(value:String, label:String) {
        this.choiceValue = value;
        this.label = label;
    }

    public function title():String {
        return label;
    }

    public function value():Any {
        return choiceValue;
    }

}
