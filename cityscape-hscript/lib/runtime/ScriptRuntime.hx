package runtime;

import hscript.Expr;
import hscriptls.ScriptApi;

/**
 * A drawing command of a script.
 */
enum DrawCommand {
    Clear(color:Int);
    Circle(x:Float, y:Float, radius:Float, color:Int);
    Rect(x:Float, y:Float, width:Float, height:Float, color:Int);
    Line(x1:Float, y1:Float, x2:Float, y2:Float, color:Int, thickness:Float);
}

/**
 * What a script did, in order: a drawing command or a line printed, with
 * the line of the script that did it (1 based), for the playback and its
 * execution highlight.
 */
typedef ScriptStep = {
    var line:Int;
    @:optional var draw:DrawCommand;
    @:optional var print:String;
}

/**
 * A runtime error: its message and its range in the script (offsets, end
 * excluded) and line (1 based).
 */
typedef ScriptError = {
    var message:String;
    var start:Int;
    var end:Int;
    var line:Int;
}

/**
 * The result of a run.
 */
typedef ScriptRun = {
    var steps:Array<ScriptStep>;
    var error:Null<ScriptError>;
}

/**
 * Thrown when a script runs too long (an endless loop).
 */
private class StepLimit {
    public function new() {}
    public function toString():String {
        return 'StepLimit';
    }
}

/**
 * hscript's `Interp`, counting the expressions it evaluates (a script that
 * loops forever is stopped) and keeping the calls being evaluated, so that
 * each drawing command knows the line of its call.
 */
private class RecordingInterp extends hscript.Interp {

    public var limit:Int = 0;
    public var count:Int = 0;
    public final calls:Array<Expr> = [];

    /** The innermost call that threw (not a `return` or `break`). */
    public var failedCall:Null<Expr> = null;

    override public function expr(e:Expr):Dynamic {
        if (++count > limit) {
            // thrown again by every next expression: a `catch` of the
            // script cannot swallow it
            throw new StepLimit();
        }
        switch e.e {
            case ECall(_, _):
                calls.push(e);
                final result:Dynamic = try super.expr(e) catch (err:Dynamic) {
                    if (failedCall == null && !Reflect.isEnumValue(err)) {
                        failedCall = e;
                    }
                    calls.pop();
                    #if neko neko.Lib.rethrow(err); #else throw err; #end
                };
                calls.pop();
                return result;
            case _:
                return super.expr(e);
        }
    }

    /** The innermost call being evaluated, else the current expression. */
    public function currentExpr():Null<Expr> {
        if (calls.length > 0) {
            return calls[calls.length - 1];
        }
        return failedCall != null ? failedCall : curExpr;
    }

}

/**
 * Runs scripts with hscript's `Interp` and the API of `ScriptApi.drawing()`:
 * the functions record drawing commands and printed lines instead of
 * drawing at once, so the app plays them back over time with the line of
 * each one highlighted.
 */
class ScriptRuntime {

    public static inline final WIDTH = 400;
    public static inline final HEIGHT = 400;

    /** The most expressions a run may evaluate. */
    public static var maxExpressions:Int = 3000000;

    /** The most steps (drawing commands and prints) a run may record. */
    public static var maxSteps:Int = 50000;

    final api:ScriptApi;
    final code:String;
    final steps:Array<ScriptStep> = [];
    final lineStarts:Array<Int> = [0];
    var interp:RecordingInterp;

    // the turtle
    var turtle:Dynamic;
    var tx:Float = 200;
    var ty:Float = 200;
    var angle:Float = 0;
    var penDown:Bool = true;
    var penColor:Int = 0xffffff;
    var penSize:Float = 2;

    public static function run(code:String, ?functionName:String, ?api:ScriptApi):ScriptRun {
        return new ScriptRuntime(code, api != null ? api : ScriptApi.drawing()).execute(functionName);
    }

    function new(code:String, api:ScriptApi) {
        this.code = code;
        this.api = api;
        for (i in 0...code.length) {
            if (StringTools.fastCodeAt(code, i) == '\n'.code) {
                lineStarts.push(i + 1);
            }
        }
    }

    function lineOf(offset:Int):Int {
        var line = 0;
        while (line + 1 < lineStarts.length && lineStarts[line + 1] <= offset) {
            line++;
        }
        return line + 1;
    }

    function execute(functionName:Null<String>):ScriptRun {
        final parser = new hscript.Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;
        var program:Expr;
        try {
            program = parser.parseString(code, 'script');
        }
        catch (e:hscript.Expr.Error) {
            return {steps: steps, error: {message: 'The script does not parse: ' + hscript.Printer.errorToString(e), start: e.pmin, end: e.pmax + 1, line: lineOf(e.pmin)}};
        }
        interp = new RecordingInterp();
        interp.limit = maxExpressions;
        bind();
        var error:Null<ScriptError> = null;
        try {
            interp.execute(program);
            if (functionName != null) {
                final f:Dynamic = interp.variables.get(functionName);
                if (f == null) {
                    throw 'No function `$functionName` at the top level';
                }
                Reflect.callMethod(null, f, []);
            }
        }
        catch (e:Dynamic) {
            error = toError(e);
        }
        return {steps: steps, error: error};
    }

    function toError(e:Dynamic):ScriptError {
        if (Std.isOfType(e, hscript.Expr.Error)) {
            final err:hscript.Expr.Error = e;
            final message = switch err.e {
                case EUnknownVariable(v): 'Unknown variable `$v`';
                case EInvalidAccess(f): 'Cannot access the field `$f` of null';
                case EInvalidOp(op): 'Invalid operation `$op`';
                case EInvalidIterator(v): 'Cannot iterate over `$v`';
                case ECustom(msg): msg;
                case _: hscript.Printer.errorToString(err);
            };
            return {message: message, start: err.pmin, end: err.pmax + 1, line: lineOf(err.pmin)};
        }
        final at = interp.currentExpr();
        final start = at != null ? at.pmin : 0;
        final end = at != null ? at.pmax + 1 : 0;
        final message = Std.isOfType(e, StepLimit)
            ? 'The script was stopped after ${maxExpressions} steps: is there an endless loop?'
            : Std.string(e);
        return {message: message, start: start, end: end, line: lineOf(start)};
    }

    //#region API

    function currentLine():Int {
        final e = interp.currentExpr();
        return e != null ? lineOf(e.pmin) : 1;
    }

    function record(step:ScriptStep):Void {
        if (steps.length >= maxSteps) {
            throw 'Too many drawing commands (more than $maxSteps)';
        }
        steps.push(step);
    }

    function draw(command:DrawCommand):Void {
        record({line: currentLine(), draw: command});
    }

    /**
     * A function of the API: checks the number of arguments like the
     * language server does, then calls `impl`.
     */
    function bindFunction(entry:ApiEntry, owner:Null<String>, impl:(args:Array<Dynamic>) -> Dynamic):Dynamic {
        final arity = ScriptApi.arity(entry);
        final label = owner != null ? owner + '.' + entry.name : entry.name;
        return Reflect.makeVarArgs(args -> {
            if (args.length < arity.min || args.length > arity.max) {
                final expected = arity.min == arity.max ? '${arity.min}' : '${arity.min} to ${arity.max}';
                throw '`$label` expects $expected argument' + (arity.max == 1 ? '' : 's') + ', got ${args.length}';
            }
            for (i in 0...args.length) {
                final type = entry.params[i].type;
                if ((type == 'Float' || type == 'Int' || type == 'Color') && !isNumber(args[i])) {
                    throw '`$label`: `${entry.params[i].name}` must be a number, got ${Std.string(args[i])}';
                }
            }
            return impl(args);
        });
    }

    static function isNumber(value:Dynamic):Bool {
        return Std.isOfType(value, Float) || Std.isOfType(value, Int);
    }

    function functions(owner:Null<String>, entries:Array<ApiEntry>, impls:Map<String, (args:Array<Dynamic>) -> Dynamic>):Dynamic {
        final object:Dynamic = {};
        for (entry in entries) {
            final impl = impls.get(entry.name);
            if (entry.kind == ApiKind.Function && impl != null) {
                Reflect.setField(object, entry.name, bindFunction(entry, owner, impl));
            }
        }
        return object;
    }

    function bind():Void {
        final printImpl = (args:Array<Dynamic>) -> {
            record({line: currentLine(), print: Std.string(args[0])});
            return null;
        };
        final globals:Map<String, (args:Array<Dynamic>) -> Dynamic> = [
            'print' => printImpl,
            'trace' => printImpl,
            'random' => args -> args[0] + Math.random() * (args[1] - args[0]),
            'randomInt' => args -> {
                final min:Int = Std.int(args[0]);
                final max:Int = Std.int(args[1]);
                return min + Std.random(max - min + 1);
            },
            'clear' => args -> {
                draw(Clear(args[0]));
                return null;
            },
            'rgb' => args -> (clampByte(args[0]) << 16) | (clampByte(args[1]) << 8) | clampByte(args[2]),
            'hsl' => args -> hslToRgb(args[0], args[1], args[2]),
            'circle' => args -> {
                draw(Circle(args[0], args[1], args[2], args[3]));
                return null;
            },
            'rect' => args -> {
                draw(Rect(args[0], args[1], args[2], args[3], args[4]));
                return null;
            },
            'line' => args -> {
                draw(Line(args[0], args[1], args[2], args[3], args[4], args.length > 5 ? args[5] : 2.0));
                return null;
            }
        ];
        for (entry in api.globals) {
            switch entry.kind {
                case ApiKind.Function:
                    final impl = globals.get(entry.name);
                    if (impl != null) {
                        interp.variables.set(entry.name, bindFunction(entry, null, impl));
                    }
                case ApiKind.Constant:
                    interp.variables.set(entry.name, entry.name == 'WIDTH' ? WIDTH : HEIGHT);
                case ApiKind.Object if (entry.name == 'turtle'):
                    turtle = functions('turtle', entry.fields, turtleImpls());
                    syncTurtle();
                    interp.variables.set('turtle', turtle);
                case ApiKind.Object if (entry.name == 'Math'):
                    final math = functions('Math', entry.fields, [
                        'sin' => args -> Math.sin(args[0]),
                        'cos' => args -> Math.cos(args[0]),
                        'tan' => args -> Math.tan(args[0]),
                        'atan2' => args -> Math.atan2(args[0], args[1]),
                        'sqrt' => args -> Math.sqrt(args[0]),
                        'pow' => args -> Math.pow(args[0], args[1]),
                        'abs' => args -> Math.abs(args[0]),
                        'floor' => args -> Math.floor(args[0]),
                        'round' => args -> Math.round(args[0]),
                        'min' => args -> Math.min(args[0], args[1]),
                        'max' => args -> Math.max(args[0], args[1])
                    ]);
                    Reflect.setField(math, 'PI', Math.PI);
                    interp.variables.set('Math', math);
                case ApiKind.Object if (entry.name == 'Std'):
                    interp.variables.set('Std', functions('Std', entry.fields, [
                        'int' => args -> Std.int(args[0]),
                        'string' => args -> Std.string(args[0]),
                        'parseInt' => args -> Std.parseInt(args[0]),
                        'parseFloat' => args -> Std.parseFloat(args[0])
                    ]));
                case _:
            }
        }
    }

    function turtleImpls():Map<String, (args:Array<Dynamic>) -> Dynamic> {
        return [
            'forward' => args -> {
                move(args[0]);
                return null;
            },
            'back' => args -> {
                move(-args[0]);
                return null;
            },
            'turn' => args -> {
                angle = (angle + args[0]) % 360;
                syncTurtle();
                return null;
            },
            'penColor' => args -> {
                penColor = args[0];
                return null;
            },
            'penSize' => args -> {
                penSize = args[0];
                return null;
            },
            'penUp' => args -> {
                penDown = false;
                return null;
            },
            'penDown' => args -> {
                penDown = true;
                return null;
            },
            'goTo' => args -> {
                lineTo(args[0], args[1]);
                return null;
            },
            'home' => args -> {
                tx = WIDTH / 2;
                ty = HEIGHT / 2;
                angle = 0;
                syncTurtle();
                return null;
            }
        ];
    }

    function move(distance:Float):Void {
        final radians = angle * Math.PI / 180;
        lineTo(tx + Math.sin(radians) * distance, ty - Math.cos(radians) * distance);
    }

    function lineTo(x:Float, y:Float):Void {
        if (penDown) {
            draw(Line(tx, ty, x, y, penColor, penSize));
        }
        tx = x;
        ty = y;
        syncTurtle();
    }

    function syncTurtle():Void {
        Reflect.setField(turtle, 'x', tx);
        Reflect.setField(turtle, 'y', ty);
        Reflect.setField(turtle, 'angle', angle);
    }

    //#endregion

    //#region colors

    static function clampByte(value:Float):Int {
        final v = Std.int(value);
        return v < 0 ? 0 : (v > 255 ? 255 : v);
    }

    public static function hslToRgb(hue:Float, saturation:Float, lightness:Float):Int {
        var h = (hue % 360) / 360;
        if (h < 0) {
            h += 1;
        }
        final s = saturation < 0 ? 0 : (saturation > 1 ? 1 : saturation);
        final l = lightness < 0 ? 0 : (lightness > 1 ? 1 : lightness);
        if (s == 0) {
            final v = Math.round(l * 255);
            return (v << 16) | (v << 8) | v;
        }
        final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        final p = 2 * l - q;
        function channel(t:Float):Int {
            if (t < 0) t += 1;
            if (t > 1) t -= 1;
            final c = if (t < 1 / 6) p + (q - p) * 6 * t else if (t < 1 / 2) q else if (t < 2 / 3) p + (q - p) * (2 / 3 - t) * 6 else p;
            return Math.round(c * 255);
        }
        return (channel(h + 1 / 3) << 16) | (channel(h) << 8) | channel(h - 1 / 3);
    }

    //#endregion

}
