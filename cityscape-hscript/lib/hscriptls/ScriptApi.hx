package hscriptls;

/**
 * What a global of the runtime API is.
 */
enum abstract ApiKind(String) to String {
    var Function = 'function';
    var Object = 'object';
    var Constant = 'constant';
    var Property = 'property';
}

/**
 * A parameter of an API function.
 */
typedef ApiParam = {
    var name:String;
    var type:String;
    var doc:String;
    @:optional var optional:Bool;
}

/**
 * A global (or a field of a global object) that scripts can use. The same
 * description feeds the language server (completion, hover, signature help,
 * inlay hints, argument count checks) and the runtime (the sample binds an
 * implementation to every function by name).
 */
typedef ApiEntry = {
    var name:String;
    var kind:ApiKind;
    var doc:String;
    /** Functions: the parameters. */
    @:optional var params:Array<ApiParam>;
    /** Functions: the type returned; constants and properties: their type. */
    @:optional var type:String;
    /** Objects: their fields. */
    @:optional var fields:Array<ApiEntry>;
}

/**
 * The description of a runtime API: the globals a script sees, plus the
 * methods of the built-in values (strings, arrays, maps) for completion.
 *
 * `ScriptApi.drawing()` is the API of this sample (a canvas, a turtle and a
 * few helpers); a host plugging another API gives the server its own list.
 */
class ScriptApi {

    public final globals:Array<ApiEntry>;

    final byName:Map<String, ApiEntry> = new Map();

    public function new(globals:Array<ApiEntry>) {
        this.globals = globals;
        for (entry in globals) {
            byName.set(entry.name, entry);
        }
    }

    public function get(name:String):Null<ApiEntry> {
        return byName.get(name);
    }

    public static function field(entry:Null<ApiEntry>, name:String):Null<ApiEntry> {
        if (entry == null || entry.fields == null) {
            return null;
        }
        for (f in entry.fields) {
            if (f.name == name) {
                return f;
            }
        }
        return null;
    }

    /**
     * The fewest and the most arguments a function takes.
     */
    public static function arity(entry:ApiEntry):{min:Int, max:Int} {
        var min = 0;
        final params = entry.params != null ? entry.params : [];
        for (p in params) {
            if (p.optional != true) {
                min++;
            }
        }
        return {min: min, max: params.length};
    }

    /**
     * `circle(x:Float, y:Float, radius:Float, color:Color):Void`, with the
     * `[start, end)` offsets of each parameter in the label when
     * `offsets` is given.
     */
    public static function signature(entry:ApiEntry, ?prefix:String, ?offsets:Array<Array<Int>>):String {
        final buf = new StringBuf();
        if (prefix != null) {
            buf.add(prefix);
        }
        buf.add(entry.name);
        buf.add('(');
        var length = (prefix != null ? prefix.length : 0) + entry.name.length + 1;
        final params = entry.params != null ? entry.params : [];
        for (i in 0...params.length) {
            if (i > 0) {
                buf.add(', ');
                length += 2;
            }
            final p = params[i];
            final text = (p.optional == true ? '?' : '') + p.name + ':' + p.type;
            if (offsets != null) {
                offsets.push([length, length + text.length]);
            }
            buf.add(text);
            length += text.length;
        }
        buf.add('):');
        buf.add(entry.type != null ? entry.type : 'Void');
        return buf.toString();
    }

    /**
     * The markdown documentation of an entry: its doc and its parameters.
     */
    public static function documentation(entry:ApiEntry):String {
        final buf = new StringBuf();
        buf.add(entry.doc);
        if (entry.params != null && entry.params.length > 0) {
            buf.add('\n\n');
            for (p in entry.params) {
                buf.add('*@param* `' + p.name + '`');
                if (p.doc != '') {
                    buf.add(': ' + p.doc);
                }
                buf.add('  \n');
            }
        }
        return StringTools.trim(buf.toString());
    }

    static function fn(name:String, doc:String, params:Array<ApiParam>, ?type:String):ApiEntry {
        return {name: name, kind: Function, doc: doc, params: params, type: type != null ? type : 'Void'};
    }

    static function p(name:String, type:String, doc:String, optional:Bool = false):ApiParam {
        return optional ? {name: name, type: type, doc: doc, optional: true} : {name: name, type: type, doc: doc};
    }

    /**
     * The API of this sample: drawing on a 400 x 400 canvas, a turtle,
     * colors, random numbers, the console, `Math` and `Std`.
     */
    public static function drawing():ScriptApi {
        return new ScriptApi([
            fn('print', 'Writes a value to the console panel.', [p('value', 'Dynamic', 'The value to print.')]),
            fn('trace', 'Writes a value to the console panel (hscript\'s built-in `trace`).', [p('value', 'Dynamic', 'The value to print.')]),
            fn('random', 'A random number between `min` (included) and `max` (excluded).', [p('min', 'Float', 'The smallest value.'), p('max', 'Float', 'The upper bound (excluded).')], 'Float'),
            fn('randomInt', 'A random integer between `min` and `max`, both included.', [p('min', 'Int', 'The smallest value.'), p('max', 'Int', 'The largest value.')], 'Int'),
            fn('clear', 'Fills the whole canvas with a color and removes what was drawn.', [p('color', 'Color', 'The background color, like `0x1e1e2e` or `rgb(30, 30, 46)`.')]),
            fn('rgb', 'A color from its red, green and blue components (0 to 255).', [p('r', 'Int', 'Red, 0 to 255.'), p('g', 'Int', 'Green, 0 to 255.'), p('b', 'Int', 'Blue, 0 to 255.')], 'Color'),
            fn('hsl', 'A color from its hue (0 to 360), saturation and lightness (0 to 1).', [p('hue', 'Float', 'The hue in degrees, 0 to 360.'), p('saturation', 'Float', 'The saturation, 0 to 1.'), p('lightness', 'Float', 'The lightness, 0 to 1.')], 'Color'),
            fn('circle', 'Draws a filled circle.', [p('x', 'Float', 'The center, from the left of the canvas.'), p('y', 'Float', 'The center, from the top of the canvas.'), p('radius', 'Float', 'The radius.'), p('color', 'Color', 'The fill color.')]),
            fn('rect', 'Draws a filled rectangle.', [p('x', 'Float', 'The left edge.'), p('y', 'Float', 'The top edge.'), p('width', 'Float', 'The width.'), p('height', 'Float', 'The height.'), p('color', 'Color', 'The fill color.')]),
            fn('line', 'Draws a straight line.', [p('x1', 'Float', 'Start, from the left.'), p('y1', 'Float', 'Start, from the top.'), p('x2', 'Float', 'End, from the left.'), p('y2', 'Float', 'End, from the top.'), p('color', 'Color', 'The line color.'), p('thickness', 'Float', 'The line width (2 when omitted).', true)]),
            {name: 'WIDTH', kind: Constant, type: 'Int', doc: 'The width of the canvas: 400.'},
            {name: 'HEIGHT', kind: Constant, type: 'Int', doc: 'The height of the canvas: 400.'},
            {name: 'turtle', kind: Object, doc: 'A turtle that draws lines as it moves. It starts at the center of the canvas, facing up, its pen down.', fields: [
                fn('forward', 'Moves forward, drawing a line when the pen is down.', [p('distance', 'Float', 'How far to move.')]),
                fn('back', 'Moves backward, drawing a line when the pen is down.', [p('distance', 'Float', 'How far to move.')]),
                fn('turn', 'Turns clockwise (counterclockwise with a negative angle).', [p('degrees', 'Float', 'The angle in degrees.')]),
                fn('penColor', 'Sets the color of the lines drawn next.', [p('color', 'Color', 'The pen color.')]),
                fn('penSize', 'Sets the width of the lines drawn next.', [p('size', 'Float', 'The pen width.')]),
                fn('penUp', 'Lifts the pen: the turtle moves without drawing.', []),
                fn('penDown', 'Puts the pen down: the turtle draws as it moves.', []),
                fn('goTo', 'Moves to a point (drawing when the pen is down), keeping its heading.', [p('x', 'Float', 'From the left of the canvas.'), p('y', 'Float', 'From the top of the canvas.')]),
                fn('home', 'Goes back to the center, facing up, without drawing.', []),
                {name: 'x', kind: Property, type: 'Float', doc: 'The position of the turtle, from the left of the canvas.'},
                {name: 'y', kind: Property, type: 'Float', doc: 'The position of the turtle, from the top of the canvas.'},
                {name: 'angle', kind: Property, type: 'Float', doc: 'The heading in degrees (0 is up, 90 is right).'}
            ]},
            {name: 'Math', kind: Object, doc: 'Math functions and constants.', fields: [
                {name: 'PI', kind: Constant, type: 'Float', doc: 'The ratio of a circle\'s circumference to its diameter: 3.14159...'},
                fn('sin', 'The sine of an angle in radians.', [p('angle', 'Float', 'In radians.')], 'Float'),
                fn('cos', 'The cosine of an angle in radians.', [p('angle', 'Float', 'In radians.')], 'Float'),
                fn('tan', 'The tangent of an angle in radians.', [p('angle', 'Float', 'In radians.')], 'Float'),
                fn('atan2', 'The angle in radians of the point (x, y).', [p('y', 'Float', 'The y coordinate.'), p('x', 'Float', 'The x coordinate.')], 'Float'),
                fn('sqrt', 'The square root of a number.', [p('value', 'Float', 'A positive number.')], 'Float'),
                fn('pow', '`base` raised to the power `exponent`.', [p('base', 'Float', 'The base.'), p('exponent', 'Float', 'The exponent.')], 'Float'),
                fn('abs', 'The absolute value of a number.', [p('value', 'Float', 'A number.')], 'Float'),
                fn('floor', 'The largest integer less than or equal to a number.', [p('value', 'Float', 'A number.')], 'Int'),
                fn('round', 'A number rounded to the nearest integer.', [p('value', 'Float', 'A number.')], 'Int'),
                fn('min', 'The smaller of two numbers.', [p('a', 'Float', 'A number.'), p('b', 'Float', 'Another number.')], 'Float'),
                fn('max', 'The larger of two numbers.', [p('a', 'Float', 'A number.'), p('b', 'Float', 'Another number.')], 'Float')
            ]},
            {name: 'Std', kind: Object, doc: 'Conversions between numbers and strings.', fields: [
                fn('int', 'A number without its fractional part.', [p('value', 'Float', 'A number.')], 'Int'),
                fn('string', 'A value as text.', [p('value', 'Dynamic', 'Any value.')], 'String'),
                fn('parseInt', 'The integer written in a text, or null.', [p('text', 'String', 'Digits, like `"42"`.')], 'Null<Int>'),
                fn('parseFloat', 'The number written in a text (NaN when there is none).', [p('text', 'String', 'A number, like `"3.5"`.')], 'Float')
            ]}
        ]);
    }

    /**
     * The methods and fields of the built-in values, for completion and
     * hover after `.` on a value whose kind the analyzer knows.
     */
    public static function builtinFields(kind:String):Array<ApiEntry> {
        return switch kind {
            case 'String': [
                {name: 'length', kind: Property, type: 'Int', doc: 'The number of characters.'},
                fn('charAt', 'The character at a position.', [p('index', 'Int', 'The position, from 0.')], 'String'),
                fn('charCodeAt', 'The code of the character at a position.', [p('index', 'Int', 'The position, from 0.')], 'Null<Int>'),
                fn('indexOf', 'The position of the first occurrence of a text, or -1.', [p('text', 'String', 'The text to find.'), p('startIndex', 'Int', 'Where to start.', true)], 'Int'),
                fn('split', 'The parts of the string between the delimiters.', [p('delimiter', 'String', 'The separator.')], 'Array<String>'),
                fn('substr', 'A part of the string.', [p('pos', 'Int', 'The start.'), p('len', 'Int', 'The length.', true)], 'String'),
                fn('toUpperCase', 'The string in upper case.', [], 'String'),
                fn('toLowerCase', 'The string in lower case.', [], 'String')
            ];
            case 'Array': [
                {name: 'length', kind: Property, type: 'Int', doc: 'The number of elements.'},
                fn('push', 'Adds an element at the end; gives the new length.', [p('value', 'Dynamic', 'The element.')], 'Int'),
                fn('pop', 'Removes and gives the last element.', [], 'Dynamic'),
                fn('shift', 'Removes and gives the first element.', [], 'Dynamic'),
                fn('unshift', 'Adds an element at the start.', [p('value', 'Dynamic', 'The element.')]),
                fn('insert', 'Inserts an element at a position.', [p('pos', 'Int', 'The position.'), p('value', 'Dynamic', 'The element.')]),
                fn('remove', 'Removes the first occurrence of a value; true when found.', [p('value', 'Dynamic', 'The element.')], 'Bool'),
                fn('indexOf', 'The position of a value, or -1.', [p('value', 'Dynamic', 'The element.')], 'Int'),
                fn('contains', 'Whether the array holds a value.', [p('value', 'Dynamic', 'The element.')], 'Bool'),
                fn('join', 'The elements as text, separated by `sep`.', [p('sep', 'String', 'The separator.')], 'String'),
                fn('copy', 'A shallow copy of the array.', [], 'Array'),
                fn('reverse', 'Reverses the array in place.', []),
                fn('map', 'A new array of `f` applied to each element.', [p('f', 'Dynamic -> Dynamic', 'The function.')], 'Array'),
                fn('filter', 'A new array of the elements for which `f` is true.', [p('f', 'Dynamic -> Bool', 'The test.')], 'Array')
            ];
            case 'Map': [
                fn('get', 'The value of a key, or null.', [p('key', 'Dynamic', 'The key.')], 'Dynamic'),
                fn('set', 'Sets the value of a key.', [p('key', 'Dynamic', 'The key.'), p('value', 'Dynamic', 'The value.')]),
                fn('exists', 'Whether the map has a key.', [p('key', 'Dynamic', 'The key.')], 'Bool'),
                fn('remove', 'Removes a key; true when it was there.', [p('key', 'Dynamic', 'The key.')], 'Bool'),
                fn('keys', 'An iterator over the keys.', [], 'Iterator')
            ];
            case _: [];
        }
    }

}
