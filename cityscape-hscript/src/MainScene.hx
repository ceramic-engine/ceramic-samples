package;

import ceramic.Scene;
import ceramic.Timer;
import cityscape.CityscapeEditor;
import glaze.Glaze;
import glaze.kit.Kit;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;

/**
 * Hosts the Glaze UI: the kit's window root around the `Playground`.
 *
 * With `out` (a PNG path, `CS_HSCRIPT_OUT`), plays a capture scene, writes
 * the pixels of the window there and quits (natively) or asks the Electron
 * runner for its screenshot (web). Scenes (`CS_HSCRIPT_SCENE`):
 *
 * - `run` (default): Spiral run, Dark+;
 * - `light`: Tree run, Light+;
 * - `completion`: `turtle.pe` typed in a function, the suggestions open;
 * - `suggest`: the suggestions of an empty line of a function (Ctrl+Space):
 *   variables, functions, objects, constants of the API, each kind with its
 *   codicon;
 * - `suggest-editor`: the same with `overflowWidgetsBounds: 'editor'` (the
 *   suggestions placed inside the editor, not the window);
 * - `codelens`: the code lenses above the functions (`$(play) Run main()`,
 *   the references);
 * - `signature`: `circle(` typed, the parameter hints open;
 * - `hover`: the hover of `hsl`, a function of the runtime API;
 * - `quickfix`: the Mistakes example, the hover of an unknown name with its
 *   quick fixes;
 * - `quickfix-menu`: the same, the quick fix menu open (Cmd+.);
 * - `error`: the Mistakes example run, its runtime error shown.
 */
class MainScene extends Scene {

    final scene:String;
    final out:Null<String>;

    var ui:Glaze;
    var playground:Null<Playground> = null;
    var elapsed:Float = 0;
    var sceneReady:Bool = false;
    var captured:Bool = false;

    public function new(scene:Null<String>, out:Null<String>) {
        super();
        this.scene = scene != null ? scene : 'run';
        this.out = out;
    }

    override function create() {

        final light = scene == 'light';
        final example = switch scene {
            case 'light': 1;
            case 'quickfix' | 'quickfix-menu' | 'error': 3;
            case _: 0;
        };
        Theme.setMode(light ? ThemeMode.Light : ThemeMode.Dark);
        if (out != null) {
            Playground.onEditorReady = (p, editor) -> {
                playground = p;
                Timer.delay(this, 1.0, () -> play(editor));
            };
        }
        ui = new Glaze(Kit.window(Playground.component(!light, example)));
        ui.size(width, height);
        add(ui);

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

    /**
     * Drives a capture scene, then marks it ready after the widgets and
     * the language server had the time to answer.
     */
    function play(editor:CityscapeEditor):Void {
        editor.focus();
        final settle = (seconds:Float) -> Timer.delay(this, seconds, () -> sceneReady = true);
        switch scene {
            case 'run' | 'light' | 'error':
                playground.start();
                // the playback lasts up to 1.6 s
                settle(3.0);
            case 'completion':
                // a new line at the end of the `turtle.penSize(3);` line
                final line = lineOf(editor, 'turtle.penSize(3);');
                editor.setPosition({lineNumber: line, column: editor.getModel().getLineMaxColumn(line)});
                editor.trigger('keyboard', 'type', {text: '\n'});
                typeText(editor, 'turtle.pe', () -> settle(1.5));
            case 'signature':
                final line = lineOf(editor, 'turtle.home();');
                editor.setPosition({lineNumber: line, column: editor.getModel().getLineMaxColumn(line)});
                editor.trigger('keyboard', 'type', {text: '\n'});
                typeText(editor, 'circle(200, ', () -> settle(1.5));
            case 'suggest' | 'suggest-editor':
                if (scene == 'suggest-editor') {
                    // the widgets kept inside the editor (Cityscape option)
                    editor.updateOptions({overflowWidgetsBounds: 'editor'});
                }
                final line = lineOf(editor, 'turtle.penSize(3);');
                editor.setPosition({lineNumber: line, column: editor.getModel().getLineMaxColumn(line)});
                editor.trigger('keyboard', 'type', {text: '\n'});
                editor.trigger('capture', 'editor.action.triggerSuggest', null);
                settle(1.5);
            case 'codelens':
                final line = lineOf(editor, 'function main()');
                editor.setPosition({lineNumber: line, column: 1});
                editor.revealLineInCenter(line);
                settle(1.5);
            case 'hover':
                final line = lineOf(editor, 'return hsl(');
                editor.setPosition({lineNumber: line, column: editor.getModel().getLineContent(line).indexOf('hsl') + 2});
                editor.trigger('capture', 'editor.action.showHover', null);
                settle(1.5);
            case 'quickfix' | 'quickfix-menu':
                final line = lineOf(editor, 'raduis');
                editor.setPosition({lineNumber: line, column: editor.getModel().getLineContent(line).indexOf('raduis') + 3});
                // the diagnostics come 0.25 s after the server opened the model
                Timer.delay(this, 0.8, () -> {
                    editor.trigger('capture', scene == 'quickfix' ? 'editor.action.showHover' : 'editor.action.quickFix', null);
                    settle(1.5);
                });
            case _:
                settle(1.0);
        }
    }

    static function lineOf(editor:CityscapeEditor, text:String):Int {
        final model = editor.getModel();
        for (line in 1...model.getLineCount() + 1) {
            if (model.getLineContent(line).indexOf(text) >= 0) {
                return line;
            }
        }
        return 1;
    }

    function typeText(editor:CityscapeEditor, text:String, done:() -> Void):Void {
        var i = 0;
        function next() {
            if (i >= text.length) {
                done();
                return;
            }
            editor.trigger('keyboard', 'type', {text: text.charAt(i++)});
            Timer.delay(this, 0.12, next);
        }
        next();
    }

    override function update(delta:Float) {

        elapsed += delta;
        if (out == null || captured || !sceneReady) {
            return;
        }
        captured = true;
        final path:String = out;
        screen.toPng(path, () -> {
            log.success('Captured $path');
            #if web
            final runner = backend.ElectronRunner.electronRunner;
            if (runner != null && runner.takeScreenshot != null) {
                runner.takeScreenshot();
            }
            #else
            Sys.exit(0);
            #end
        });

    }

}
