package;

import runtime.ScriptRuntime;

/**
 * Tests of the sample's runtime: hscript's Interp with the drawing API,
 * recording the commands of a script with their lines.
 */
class RuntimeTests {

    static var failures = 0;
    static var passed = 0;

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
            println('FAIL [runtime] line ${pos.lineNumber}: $message');
        }
    }

    public static function run():Int {
        try {
            tests();
        }
        catch (e:Dynamic) {
            failures++;
            println('FAIL [runtime] threw ' + Std.string(e) + '\n' + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
        }
        println('runtime tests: $passed passed, $failures failed');
        return failures;
    }

    static function tests():Void {
        final simple = ScriptRuntime.run('clear(0x101010);\nvar r = 10;\ncircle(1, 2, r, rgb(255, 0, 0));\nprint("hello " + r);');
        check(simple.error == null, 'no error: ' + (simple.error != null ? simple.error.message : ''));
        check(simple.steps.length == 3, 'three steps');
        check(simple.steps[1].line == 3, 'the circle comes from line 3');
        switch simple.steps[1].draw {
            case Circle(x, y, radius, color):
                check(x == 1 && y == 2 && radius == 10 && color == 0xff0000, 'circle arguments');
            case _:
                check(false, 'a circle');
        }
        check(simple.steps[2].print == 'hello 10', 'print');

        // the turtle draws lines and updates its position
        final turtle = ScriptRuntime.run('turtle.forward(100);\nturtle.turn(90);\nturtle.forward(50);\nprint(Math.round(turtle.x) + "," + Math.round(turtle.y));');
        check(turtle.error == null, 'turtle runs: ' + (turtle.error != null ? turtle.error.message : ''));
        check(turtle.steps.length == 3, 'two lines and a print');
        check(turtle.steps[2].print == '250,100', 'the turtle went up then right: ' + turtle.steps[2].print);

        // arguments checked like the language server
        final arity = ScriptRuntime.run('var a = 1;\ncircle(1, 2, 3);');
        check(arity.error != null && arity.error.message.indexOf('`circle` expects 4 arguments, got 3') >= 0, 'argument count error: ' + (arity.error != null ? arity.error.message : 'none'));
        check(arity.error != null && arity.error.line == 2, 'on line 2');
        check(arity.error != null && arity.error.start == 11 && arity.error.end == 26, 'the range of the whole call: ' + (arity.error != null ? arity.error.start + '-' + arity.error.end : ''));

        final unknown = ScriptRuntime.run('var x = 1;\nprint(y);');
        check(unknown.error != null && unknown.error.message == 'Unknown variable `y`', 'unknown variable: ' + (unknown.error != null ? unknown.error.message : 'none'));
        check(unknown.error != null && unknown.error.start == 17 && unknown.error.end == 18, 'its range');

        // an endless loop is stopped, even inside try / catch
        ScriptRuntime.maxExpressions = 20000;
        final endless = ScriptRuntime.run('var i = 0;\nwhile (true) {\n  try { i++; } catch (e:Dynamic) {}\n}');
        ScriptRuntime.maxExpressions = 3000000;
        check(endless.error != null && endless.error.message.indexOf('endless loop') >= 0, 'endless loop stopped');

        // a function of the script run by name (the Run code lens)
        final named = ScriptRuntime.run('function hello() { print("hi"); }\nprint("top");', 'hello');
        check(named.error == null && named.steps.length == 2 && named.steps[1].print == 'hi', 'run a function by name');

        // maps and the iterator of their keys
        final maps = ScriptRuntime.run('var m = ["a" => 1, "b" => 2];\nvar total = 0;\nfor (k in m.keys()) total += m.get(k);\nprint(total);');
        check(maps.error == null && maps.steps[0].print == '3', 'maps: ' + (maps.error != null ? maps.error.message : maps.steps[0].print));

        // the examples run without error
        for (example in Examples.all()) {
            final result = ScriptRuntime.run(example.code);
            if (example.name == 'Mistakes') {
                check(result.error != null, 'Mistakes fails at runtime');
            }
            else {
                check(result.error == null, example.name + ' runs: ' + (result.error != null ? result.error.message + ' line ' + result.error.line : ''));
                check(result.steps.length > 10, example.name + ' draws');
            }
        }

        check(ScriptRuntime.hslToRgb(0, 1, 0.5) == 0xff0000, 'hsl red');
        check(ScriptRuntime.hslToRgb(120, 1, 0.5) == 0x00ff00, 'hsl green');
    }

}
