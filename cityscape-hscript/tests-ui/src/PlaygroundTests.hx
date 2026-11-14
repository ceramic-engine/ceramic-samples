package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import cityscape.view.CityscapeView;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.Kit;

/**
 * The status bar of the playground is a component of its own: a cursor move
 * renders it without the playground. It must still follow everything it
 * shows: the cursor position, the markers count, the run state, the theme
 * and the example.
 *
 * Each step changes one of them, draws, and relies on Glaze's cache check
 * (`glaze_verify_cache`): a view kept from the cache while it would render
 * differently is reported, and a frame drawn in place is compared with a
 * full frame. The frame is also compared with the one a full redraw gives.
 */
@:access(Playground)
class PlaygroundTests {

    static var failures = 0;
    static var passed = 0;
    static final cacheMessages:Array<String> = [];

    static function println(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

    static function check(condition:Bool, message:String, ?pos:haxe.PosInfos):Void {
        if (condition) {
            passed++;
        }
        else {
            failures++;
            println('FAIL [playground] line ${pos.lineNumber}: $message');
        }
    }

    public static function run():Int {
        try {
            tests();
        }
        catch (e:Dynamic) {
            failures++;
            println('FAIL [playground] threw ' + Std.string(e) + '\n' + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        }
        println('playground tests: $passed passed, $failures failed');
        return failures;
    }

    static var app:glaze.App;
    static var window:Window;

    /** Draws until nothing is dirty; the number of frames drawn. */
    static function settle():Int {
        var frames = 0;
        ceramic.App.app.flushImmediate();
        while (frames < 10 && window.drawIfDirty()) {
            frames++;
            ceramic.App.app.flushImmediate();
        }
        return frames;
    }

    static function scene():String {
        return glaze.scene.SceneDump.toJson(window.renderedScene(), 2800, 1720);
    }

    /**
     * After a change: the window draws, nothing kept from the cache is
     * stale, and the frame is the one a full redraw gives.
     */
    static function checkFrame(step:String, ?before:String):String {
        final messages = cacheMessages.length;
        settle();
        final drawn = scene();
        if (before != null) {
            check(drawn != before, step + ': the frame changed');
        }
        window.refresh();
        window.draw();
        check(scene() == drawn, step + ': the frame of a full redraw is the same');
        for (i in messages...cacheMessages.length) {
            check(false, step + ': cache check: ' + cacheMessages[i]);
        }
        settle();
        return scene();
    }

    static function tests():Void {
        Window.onCacheVerificationFailure = message -> cacheMessages.push(message);
        app = new glaze.App(new TestDispatcher());
        app.update(cx -> Kit.init(cx));
        var playground:Null<Playground> = null;
        var editor:Null<CityscapeEditor> = null;
        Playground.onEditorReady = (p, e) -> {
            playground = p;
            editor = e;
        };
        window = Window.open(app, {width: 1400, height: 860, scaleFactor: 2, autoDraw: false, bindInput: false}, Kit.window(Playground.component(true, 0)));
        settle();
        check(playground != null && editor != null, 'the editor is created');
        if (playground == null || editor == null) {
            return;
        }
        final status = playground.status;
        check(status != null, 'the status bar registered itself');
        final view:CityscapeView = editor.getView();
        app.update(_ -> view.focusHandle.focus(window, app));
        settle();
        var frame = checkFrame('start');
        check(cacheMessages.length == 0, 'nothing stale at start');

        // the cursor: the status bar holds it, and renders without the playground
        var inPlace = window.inPlaceFrameCount;
        editor.setPosition({lineNumber: 3, column: 5});
        final moved = editor.getPosition();
        check(moved.lineNumber == 3, 'the cursor moved');
        check(status.cursorLine == moved.lineNumber && status.cursorColumn == moved.column, 'the status bar has the cursor position');
        final cursorFrames = settle();
        check(cursorFrames == 1, 'a cursor move draws one frame (' + cursorFrames + ')');
        check(window.inPlaceFrameCount > inPlace, 'a cursor move is drawn in place (the playground does not render)');
        frame = checkFrame('cursor move', frame);
        // a much longer label: the bar keeps its bounds, still in place
        inPlace = window.inPlaceFrameCount;
        final lastLine = editor.getModel().getLineCount();
        editor.setPosition({lineNumber: lastLine, column: editor.getModel().getLineMaxColumn(lastLine)});
        check(status.cursorLine == lastLine, 'the status bar has the last line');
        settle();
        check(window.inPlaceFrameCount > inPlace, 'a longer cursor label is drawn in place too');
        frame = checkFrame('cursor at the end', frame);

        // typing
        inPlace = window.inPlaceFrameCount;
        editor.setPosition({lineNumber: 1, column: 1});
        settle();
        view.type('/');
        view.type('/');
        check(status.cursorColumn == 3, 'typing moves the cursor of the status bar');
        frame = checkFrame('typing', frame);

        // the markers count
        final model = playground.currentModel();
        Cityscape.setModelMarkers(model, 'test', [{
            severity: MarkerSeverity.Error,
            message: 'a test error',
            startLineNumber: 2,
            startColumn: 1,
            endLineNumber: 2,
            endColumn: 4
        }]);
        frame = checkFrame('an error marker', frame);
        Cityscape.setModelMarkers(model, 'test', [{
            severity: MarkerSeverity.Warning,
            message: 'a test warning',
            startLineNumber: 2,
            startColumn: 1,
            endLineNumber: 2,
            endColumn: 4
        }]);
        frame = checkFrame('a warning marker instead', frame);
        Cityscape.setModelMarkers(model, 'test', []);
        frame = checkFrame('no marker', frame);

        // the run state: started, each step of the playback, ended
        playground.start();
        frame = checkFrame('run started', frame);
        final deadline = haxe.Timer.stamp() + 5;
        var steps = 0;
        while (!playground.finished() && haxe.Timer.stamp() < deadline) {
            final shown = playground.shown;
            playground.update(0.016);
            if (playground.shown != shown || playground.finished()) {
                steps++;
                frame = checkFrame('playback step ' + steps, frame);
            }
        }
        check(playground.finished(), 'the run ended');
        check(steps > 1, 'the playback had several steps (' + steps + ')');

        // the theme
        app.update(cx -> playground.setDark(false, cx));
        frame = checkFrame('light theme', frame);
        app.update(cx -> playground.setDark(true, cx));
        frame = checkFrame('dark theme', frame);

        // another example (its own markers and no run)
        playground.selectExample(3);
        frame = checkFrame('another example', frame);
        check(playground.status == status, 'the same status bar');

        window.destroy();
        ceramic.App.app.flushImmediate();
        check(playground.status == null, 'the status bar unregistered itself');
        println('cache check: ' + Window.cacheVerifications + ' cached renderings compared, ' + Window.cacheVerificationFailures + ' different; in place: '
            + Window.inPlaceFramesDrawn + ' frames, ' + Window.inPlaceVerifications + ' compared with a full frame, ' + Window.inPlaceVerificationFailures + ' different');
        check(Window.cacheVerificationFailures == 0 && Window.inPlaceVerificationFailures == 0, 'the cache check found nothing');
    }

}
