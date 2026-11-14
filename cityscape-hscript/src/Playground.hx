package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.KeyCodes.KeyCode;
import cityscape.base.common.KeyCodes.KeyMod;
import cityscape.base.common.Uri;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Range;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import cityscape.standalone.common.VSCodeDefaultThemes;
import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabBar;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import hscriptls.HscriptClient;
import hscriptls.HscriptLanguage;
import runtime.ScriptRuntime;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * The colors of the interface around the editor, close to VS Code's.
 */
typedef Chrome = {
    var bg:Int;
    var panel:Int;
    var border:Int;
    var text:Int;
    var dim:Int;
    var error:Int;
    var canvas:Int;
    var status:Int;
    var statusText:Int;
}

/**
 * The hscript playground: a toolbar (examples, Run, theme), the Cityscape
 * editor with the hscript language server, and an output panel (the canvas
 * the script draws on and its console), above a status bar.
 *
 * Running a script records what it does (`ScriptRuntime`), then plays it
 * back: the drawing appears step by step while the editor highlights the
 * line of each step. A runtime error becomes a marker and an inline
 * highlight at its range, like a diagnostic.
 */
class Playground extends Component {

    static final DARK:Chrome = {bg: 0x181818, panel: 0x1f1f1f, border: 0x2b2b2b, text: 0xcccccc, dim: 0x8b8b8b, error: 0xf48771, canvas: 0x111111, status: 0x007acc, statusText: 0xffffff};
    static final LIGHT:Chrome = {bg: 0xf8f8f8, panel: 0xf3f3f3, border: 0xe0e0e0, text: 0x333333, dim: 0x717171, error: 0xc72e0f, canvas: 0xffffff, status: 0x007acc, statusText: 0xffffff};

    /** The marker owner of runtime errors (the server's is `hscript`). */
    public static inline final RUNTIME_OWNER = 'hscript-runtime';

    /** The width of the cursor label of the status bar (room for `Ln 99999, Col 9999`). */
    static inline final STATUS_CURSOR_WIDTH = 120;

    /** How long the playback of a run lasts at most, in seconds. */
    static inline final PLAYBACK_SECONDS = 1.6;

    public final context:Cityscape;
    public final language:HscriptClient;
    public final examples = Examples.all();
    final models:Array<ITextModel> = [];

    @observe public var dark:Bool = true;
    @observe public var exampleIndex:Int = 0;
    /** Bumped when the run changes (started, ended): the output panel and the status bar read it. */
    @observe var revision:Int = 0;

    /** Bumped when the markers change: only the status bar counts them. */
    @observe var markersRevision:Int = 0;

    /**
     * The status bar, a component of its own (set by its `init`, null before
     * its first render and after it left the tree). It holds the cursor
     * position: a cursor move renders the status bar alone, not the
     * playground.
     */
    var status:Null<StatusBar> = null;

    /** The steps of the last run shown so far. */
    @observe var shown:Int = 0;

    public var editor(default, null):Null<CityscapeEditor> = null;

    /**
     * The options of the editor, built once: they depend on no observable.
     * (If they do one day: a `@compute`, so that they change only when
     * their sources do.)
     */
    final editorOptions:IEditorOptions = {
        fontSize: 14,
        lineHeight: 21,
        lineNumbers: 'on',
        padding: {top: 6},
        scrollBeyondLastLine: false,
        showFoldingControls: 'always',
        stickyScroll: {enabled: true},
        guides: {indentation: true},
        inlayHints: {enabled: 'on', padding: true},
        codeLens: true,
        semanticHighlighting: {enabled: true},
        renderLineHighlight: 'all'
    };

    /**
     * Called with the playground and its editor once the editor exists (the
     * captures of `MainScene` drive it from there).
     */
    public static var onEditorReady:Null<(playground:Playground, editor:CityscapeEditor) -> Void> = null;

    var run:Null<ScriptRun> = null;
    var runModel:Null<ITextModel> = null;
    var runFunction:Null<String> = null;
    var playing:Bool = false;
    var playStart:Float = 0;
    var executionLine:Null<Int> = null;
    var executionDecorations:Array<String> = [];
    var errorDecorations:Array<String> = [];

    /** The paths of the turtle's lines, built once per run and canvas size. */
    final paths:Map<Int, glaze.Path> = new Map();
    var pathsKey:String = '';

    public function new(dark:Bool = true, exampleIndex:Int = 0) {
        super();
        this.dark = dark;
        this.exampleIndex = exampleIndex;
        context = new Cityscape();
        language = new HscriptClient(context);
        VSCodeDefaultThemes.apply(context, dark);
        for (example in examples) {
            models.push(context.modelService.createModel(example.code, HscriptLanguage.LANGUAGE_ID, Uri.parse('file:///examples/' + example.name + '.hscript')));
        }
        // the `Run` code lens above the functions
        context.commandsRegistry.registerCommandHandler('hscript.runFunction', (_, args) -> {
            if (args != null && args.length > 0) {
                start(Std.string(args[0]));
            }
        });
        // the status bar counts the diagnostics
        Cityscape.onDidChangeMarkers(_ -> markersRevision++, context);
        for (model in models) {
            // an edit ends the run shown in the editor
            model.onDidChangeContent(_ -> if (model == runModel) clearRunDecorations());
        }
    }

    override public function init(window:Window, cx:App):Void {
        ceramic.App.app.onUpdate(null, update);
    }

    override public function destroy():Void {
        ceramic.App.app.offUpdate(update);
        language.dispose();
    }

    public function currentModel():ITextModel {
        return models[exampleIndex];
    }

    //#region running

    /**
     * Runs the current script (then calls `functionName` when given) and
     * starts the playback.
     */
    public function start(?functionName:String):Void {
        clearRunDecorations();
        final model = currentModel();
        runModel = model;
        runFunction = functionName;
        run = ScriptRuntime.run(model.getValue(), functionName, language.server.api);
        paths.clear();
        pathsKey = '';
        shown = 0;
        playing = true;
        playStart = haxe.Timer.stamp();
        revision++;
    }

    /** True once the playback of the last run is over. */
    public function finished():Bool {
        return run != null && !playing;
    }

    function update(delta:Float):Void {
        final r = run;
        if (!playing || r == null) {
            return;
        }
        final total = r.steps.length;
        final progress = Math.min(1, (haxe.Timer.stamp() - playStart) / Math.max(0.3, Math.min(PLAYBACK_SECONDS, total * 0.012)));
        final next = Std.int(Math.ceil(progress * total));
        if (next != shown) {
            shown = next;
        }
        if (shown > 0 && shown <= total) {
            setExecutionLine(r.steps[shown - 1].line);
        }
        if (progress >= 1) {
            playing = false;
            setExecutionLine(null);
            if (r.error != null) {
                showRuntimeError(r.error);
            }
            revision++;
        }
    }

    function setExecutionLine(line:Null<Int>):Void {
        final e = editor;
        if (e == null || line == executionLine || e.getModel() != runModel) {
            return;
        }
        executionLine = line;
        executionDecorations = e.deltaDecorations(executionDecorations, line == null ? [] : [{
            range: new Range(line, 1, line, 1),
            options: {
                description: 'hscript-execution',
                isWholeLine: true,
                lineStyle: {background: dark ? 'rgba(255, 255, 120, 0.10)' : 'rgba(255, 200, 0, 0.18)'},
                linesDecorationsStyle: {background: dark ? '#e2c08d' : '#bf8803', width: 3}
            }
        }]);
        if (line != null) {
            e.revealLineInCenterIfOutsideViewport(line);
        }
    }

    function showRuntimeError(error:ScriptError):Void {
        final model = runModel;
        final e = editor;
        if (model == null || e == null) {
            return;
        }
        final start = model.getPositionAt(error.start);
        final end = model.getPositionAt(error.end > error.start ? error.end : error.start + 1);
        final range = new Range(start.lineNumber, start.column, end.lineNumber, end.column);
        errorDecorations = e.deltaDecorations(errorDecorations, [{
            range: range,
            options: {
                description: 'hscript-runtime-error',
                style: {background: dark ? 'rgba(244, 71, 71, 0.25)' : 'rgba(229, 20, 0, 0.15)', borderRadius: 3}
            }
        }]);
        Cityscape.setModelMarkers(model, RUNTIME_OWNER, [{
            severity: MarkerSeverity.Error,
            message: 'Runtime error: ' + error.message,
            source: 'run',
            startLineNumber: range.startLineNumber,
            startColumn: range.startColumn,
            endLineNumber: range.endLineNumber,
            endColumn: range.endColumn
        }]);
        e.revealLineInCenterIfOutsideViewport(range.startLineNumber);
    }

    function clearRunDecorations():Void {
        final e = editor;
        if (e != null) {
            executionDecorations = e.deltaDecorations(executionDecorations, []);
            errorDecorations = e.deltaDecorations(errorDecorations, []);
        }
        executionLine = null;
        for (model in models) {
            Cityscape.setModelMarkers(model, RUNTIME_OWNER, []);
        }
    }

    function selectExample(index:Int):Void {
        if (index == exampleIndex) {
            return;
        }
        clearRunDecorations();
        playing = false;
        run = null;
        runModel = null;
        shown = 0;
        exampleIndex = index;
    }

    function setDark(value:Bool, cx:App):Void {
        dark = value;
        VSCodeDefaultThemes.apply(context, value);
        Theme.setMode(value ? ThemeMode.Dark : ThemeMode.Light, cx);
    }

    //#endregion

    //#region view

    public function render(window:Window, cx:App):IntoElement {
        final redraw = revision; // the run changes outside of the observed fields
        final c = dark ? DARK : LIGHT;
        return div().flex().flexCol().sizeFull().bg(rgb(c.bg)).textColor(rgb(c.text))
            .child(toolbar(c))
            .child(div().flex().flexRow().flex1().minH0()
                .child(editorArea(c))
                .child(outputPanel(c, cx)))
            .child(StatusBar.component(this));
    }

    function toolbar(c:Chrome):IntoElement {
        final tabs = TabBar.component('examples').segmented().selectedIndex(exampleIndex)
            .onClick((index, _, _) -> selectExample(index));
        for (example in examples) {
            tabs.child(glaze.kit.tab.Tab.component().label(example.name));
        }
        return div().flex().flexRow().itemsCenter().gap3().px3().py2().bg(rgb(c.panel)).borderB1().borderColor(rgb(c.border))
            .child(div().textSm().fontSemibold().child('hscript playground'))
            .child(div().textXs().textColor(rgb(c.dim)).child('Cityscape + a language server in Haxe'))
            .child(div().flex1())
            .child(tabs)
            .child(Button.component('run').primary().icon(IconName.Play).label('Run').tooltip('Run the script (Cmd+Enter)')
                .onClick((_, _, _) -> start()))
            .child(Button.component('theme').ghost().icon(dark ? IconName.Sun : IconName.Moon).tooltip(dark ? 'Light+ theme' : 'Dark+ theme')
                .onClick((_, _, cx) -> setDark(!dark, cx)));
    }

    function editorArea(c:Chrome):IntoElement {
        return div().flex().flex1().minW0()
            .child(CityscapeEditor.component().at('editor')
                .model(currentModel())
                .context(context)
                .options(editorOptions)
                .onCreate(created)
                .flex1());
    }

    function created(e:CityscapeEditor):Void {
        editor = e;
        e.addCommand(KeyMod.CtrlCmd | KeyCode.Enter, (_, _) -> start());
        e.onDidChangeCursorPosition(event -> {
            final s = status;
            if (s != null) {
                s.cursorLine = event.position.lineNumber;
                s.cursorColumn = event.position.column;
            }
        });
        syncStatusCursor();
        if (onEditorReady != null) {
            onEditorReady(this, e);
        }
    }

    function outputPanel(c:Chrome, cx:App):IntoElement {
        final r = run;
        final panel = div().flex().flexCol().w(px(440)).flexShrink0().bg(rgb(c.panel)).borderL1().borderColor(rgb(c.border));
        panel.child(div().px3().py2().textXs().textColor(rgb(c.dim)).child('CANVAS'));
        panel.child(div().px5().child(div().w(px(400)).h(px(400)).overflowHidden().roundedMd().border1().borderColor(rgb(c.border))
            .child(canvas((_, _, _) -> null, (bounds, _, window, _) -> paintCanvas(bounds, c, window)).sizeFull())));
        panel.child(div().px3().pt3().pb1().textXs().textColor(rgb(c.dim)).child('CONSOLE'));
        final consoleView = div().id('console').flex().flexCol().flex1().minH0().overflowYScroll().px3().pb2().gap0p5()
            .textXs().fontFamily(Theme.global(cx).monoFontFamily);
        if (r == null) {
            consoleView.child(div().textColor(rgb(c.dim)).child('Press Run (Cmd+Enter) to run the script.'));
        }
        else {
            var count = 0;
            for (i in 0...shown) {
                final step = r.steps[i];
                if (step.print != null) {
                    count++;
                    consoleView.child(consoleLine(c, 'print-$i', step.print, step.line, false));
                }
            }
            if (!playing) {
                if (r.error != null) {
                    consoleView.child(consoleLine(c, 'error', r.error.message, r.error.line, true));
                }
                else if (count == 0) {
                    consoleView.child(div().textColor(rgb(c.dim)).child('(nothing printed)'));
                }
            }
        }
        panel.child(consoleView);
        return panel;
    }

    function consoleLine(c:Chrome, id:String, text:String, line:Int, isError:Bool):IntoElement {
        return div().id(id).flex().flexRow().gap2().cursorPointer()
            .onClick(_ -> {
                final e = editor;
                if (e != null) {
                    e.revealLineInCenterIfOutsideViewport(line);
                    e.setPosition({lineNumber: line, column: 1});
                    e.focus();
                }
            })
            .child(div().flex1().textColor(rgb(isError ? c.error : c.text)).child(text))
            .child(div().textColor(rgb(c.dim)).child('line ' + line));
    }

    /**
     * Gives the status bar the cursor position of the editor (when one was
     * created before the other: afterwards the cursor events keep it).
     */
    function syncStatusCursor():Void {
        final s = status;
        final e = editor;
        final position = e != null ? e.getPosition() : null;
        if (s != null && position != null) {
            s.cursorLine = position.lineNumber;
            s.cursorColumn = position.column;
        }
    }

    /**
     * The content of the status bar, rendered by `StatusBar`: what it reads
     * here (the theme, the markers, the run, the example) is observed by
     * the status bar itself.
     */
    function statusBar(c:Chrome, cursorLine:Int, cursorColumn:Int):IntoElement {
        // the markers and the run change outside of the observed fields;
        // `shown` moves the line of the playback
        final redraw = markersRevision + revision + shown;
        var errors = 0;
        var warnings = 0;
        for (m in Cityscape.getModelMarkers({resource: currentModel().uri}, context)) {
            if (m.severity == MarkerSeverity.Error) {
                errors++;
            }
            else if (m.severity == MarkerSeverity.Warning) {
                warnings++;
            }
        }
        final r = run;
        final runState = r == null ? 'Not run yet'
            : (playing ? 'Running line ' + (executionLine != null ? executionLine : 1)
                : (r.error != null ? 'Stopped with an error on line ' + r.error.line : 'Ran ' + r.steps.length + ' steps' + (runFunction != null ? ' (' + runFunction + ')' : '')));
        // The bar takes the width of the window whatever it shows, and the
        // cursor label sits in a box of fixed width: the bounds of the
        // status bar do not change when the cursor moves (Glaze renders a
        // view alone only while its bounds stay the same)
        return div().flex().flexRow().itemsCenter().gap4().px3().h(px(24)).wFull().minW0().overflowHidden().flexShrink0().textXs()
            .bg(rgb(c.status)).textColor(rgb(c.statusText))
            .child(div().w(px(STATUS_CURSOR_WIDTH)).flexShrink0().child('Ln ' + cursorLine + ', Col ' + cursorColumn))
            .child((errors == 1 ? '1 error' : errors + ' errors') + ', ' + (warnings == 1 ? '1 warning' : warnings + ' warnings'))
            .child(runState)
            .child(div().flex1())
            .child('hscript')
            .child(dark ? 'Dark+' : 'Light+');
    }

    //#endregion

    //#region canvas

    function paintCanvas(bounds:glaze.Bounds, c:Chrome, window:Window):Void {
        final x0 = bounds.origin.x;
        final y0 = bounds.origin.y;
        final scale = bounds.size.width / ScriptRuntime.WIDTH;
        window.paintQuad(fill(bounds, rgb(c.canvas)));
        final r = run;
        if (r == null) {
            return;
        }
        final key = x0 + ',' + y0 + ',' + scale;
        if (key != pathsKey) {
            paths.clear();
            pathsKey = key;
        }
        for (i in 0...shown) {
            final draw = r.steps[i].draw;
            if (draw == null) {
                continue;
            }
            switch draw {
                case Clear(color):
                    window.paintQuad(fill(bounds, rgb(color)));
                case Circle(x, y, radius, color):
                    final rr = Math.max(0, radius * scale);
                    final quad = new glaze.PaintQuad(glaze.Bounds.fromCorners(point(x0 + x * scale - rr, y0 + y * scale - rr), point(x0 + x * scale + rr, y0 + y * scale + rr)), glaze.Corners.all(rr));
                    quad.background = glaze.Background.fromRgba(rgb(color));
                    window.paintQuad(quad);
                case Rect(x, y, width, height, color):
                    window.paintQuad(fill(glaze.Bounds.fromCorners(point(x0 + x * scale, y0 + y * scale), point(x0 + (x + width) * scale, y0 + (y + height) * scale)), rgb(color)));
                case Line(x1, y1, x2, y2, color, thickness):
                    var path = paths.get(i);
                    if (path == null) {
                        final options = new glaze.Path.StrokeOptions(Math.max(0.5, thickness * scale), glaze.Path.LineJoin.Round, glaze.Path.LineCap.Round, glaze.Path.LineCap.Round);
                        final builder = new glaze.PathBuilder(glaze.PathBuilder.PathStyle.Stroke(options));
                        builder.moveTo(point(x0 + x1 * scale, y0 + y1 * scale));
                        builder.lineTo(point(x0 + x2 * scale, y0 + y2 * scale));
                        try {
                            path = builder.build();
                        }
                        catch (_:Dynamic) {
                            continue;
                        }
                        paths.set(i, path);
                    }
                    window.paintPath(path, rgb(color));
            }
        }
    }

    //#endregion

}

/**
 * The status bar of the playground, a persistent component of its own. It
 * holds the cursor position, which changes at every keystroke: only this
 * component renders then. Everything else it shows is read from the
 * playground's observable fields in its own render, so it follows them too.
 */
@:access(Playground)
class StatusBar extends Component {

    @observe public var cursorLine:Int = 1;
    @observe public var cursorColumn:Int = 1;

    final playground:Playground;

    public function new(playground:Playground) {
        super();
        this.playground = playground;
    }

    override public function init(window:Window, cx:App):Void {
        playground.status = this;
        playground.syncStatusCursor();
    }

    override public function destroy():Void {
        if (playground.status == this) {
            playground.status = null;
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        final p = playground;
        return p.statusBar(p.dark ? Playground.DARK : Playground.LIGHT, cursorLine, cursorColumn);
    }

}
