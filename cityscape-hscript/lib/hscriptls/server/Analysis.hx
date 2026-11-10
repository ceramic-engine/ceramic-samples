package hscriptls.server;

import hscript.Expr;
import hscriptls.ScriptApi;

/**
 * What a declared name is.
 */
enum abstract SymbolKind(Int) {
    var Variable = 0;
    var Function = 1;
    var Parameter = 2;
    var LoopVariable = 3;
    var CatchVariable = 4;
}

/**
 * The kind of value the analyzer infers for an expression, when it is
 * cheap to know (literals, API calls, simple operators).
 */
enum ValueType {
    TUnknown;
    TNull;
    TInt;
    TFloat;
    TBool;
    TString;
    TArray;
    TMap;
    TObject(fields:Array<String>);
    TFunction(params:Array<String>);
    TApi(entry:ApiEntry);
}

/**
 * A parameter of a script function.
 */
typedef ParamInfo = {
    var name:String;
    var optional:Bool;
}

/**
 * A name declared by the script: a variable, a function, a parameter, a
 * loop or catch variable. Offsets count UTF-16 units from the start of the
 * text, ends excluded.
 */
class Symbol {

    public final name:String;
    public final kind:SymbolKind;
    public final nameStart:Int;
    public final nameEnd:Int;
    public final scope:Scope;

    /** The whole declaration (a `var` statement, a function). */
    public var declStart:Int;
    public var declEnd:Int;

    public var type:ValueType = TUnknown;

    /** The parameters, for functions and variables holding a function. */
    public var params:Null<Array<ParamInfo>> = null;

    /** The documentation comment before the declaration. */
    public var doc:Null<String> = null;

    /** A top level function, visible in the whole script. */
    public var hoisted:Bool = false;

    /** The function this symbol is declared in (null at the top level). */
    public var container:Null<Symbol> = null;

    public final children:Array<Symbol> = [];
    public final refs:Array<Reference> = [];
    public var reads:Int = 0;
    public var writes:Int = 0;

    public function new(name:String, kind:SymbolKind, nameStart:Int, nameEnd:Int, scope:Scope) {
        this.name = name;
        this.kind = kind;
        this.nameStart = nameStart;
        this.nameEnd = nameEnd;
        this.scope = scope;
        this.declStart = nameStart;
        this.declEnd = nameEnd;
    }

    public function isTopLevel():Bool {
        return container == null;
    }

}

/**
 * An occurrence of a name in the text: a declared symbol, a global of the
 * runtime API, or a field of a value.
 */
class Reference {

    public final start:Int;
    public final end:Int;
    public final symbol:Null<Symbol>;
    public final api:Null<ApiEntry>;

    /** For a field: the object it belongs to (`turtle`), or the built-in type name. */
    public final owner:Null<String>;

    public final write:Bool;
    public final declaration:Bool;

    public function new(start:Int, end:Int, symbol:Null<Symbol>, api:Null<ApiEntry>, owner:Null<String>, write:Bool, declaration:Bool) {
        this.start = start;
        this.end = end;
        this.symbol = symbol;
        this.api = api;
        this.owner = owner;
        this.write = write;
        this.declaration = declaration;
    }

}

/**
 * A block, a function body, a loop or a catch clause, with the names
 * declared in it so far.
 */
class Scope {

    public final parent:Null<Scope>;
    public final start:Int;
    public final end:Int;
    public final isFunction:Bool;
    public final symbols:Map<String, Symbol> = new Map();
    public final list:Array<Symbol> = [];
    public final children:Array<Scope> = [];

    public function new(parent:Null<Scope>, start:Int, end:Int, isFunction:Bool) {
        this.parent = parent;
        this.start = start;
        this.end = end;
        this.isFunction = isFunction;
        if (parent != null) {
            parent.children.push(this);
        }
    }

    public function lookup(name:String):Null<Symbol> {
        var s:Null<Scope> = this;
        while (s != null) {
            final symbol = s.symbols.get(name);
            if (symbol != null) {
                return symbol;
            }
            s = s.parent;
        }
        return null;
    }

}

/**
 * A call: its callee (a global of the API, a field of an API object, or a
 * script function) and its arguments, for signature help, inlay hints and
 * argument count checks.
 */
typedef CallInfo = {
    var start:Int;
    var end:Int;
    var args:Array<Expr>;
    @:optional var api:Null<ApiEntry>;
    @:optional var apiOwner:Null<String>;
    @:optional var symbol:Null<Symbol>;
}

typedef RelatedInfo = {
    var start:Int;
    var end:Int;
    var message:String;
}

/**
 * A problem found in the script. Severity is LSP's (1 error, 2 warning,
 * 3 information, 4 hint), tags too (1 unnecessary).
 */
typedef Diagnostic = {
    var start:Int;
    var end:Int;
    var severity:Int;
    var message:String;
    var code:String;
    @:optional var tags:Array<Int>;
    @:optional var data:Dynamic;
    @:optional var related:Array<RelatedInfo>;
}

/**
 * The result of analyzing one version of a script: its syntax tree (when
 * it parses, or what hscript's error recovery gives), the scopes, symbols
 * and references, the calls and the diagnostics.
 */
class Analysis {

    public final text:String;
    public final api:ScriptApi;
    public var ast:Null<Expr> = null;

    /** The statements of the top level. */
    public final statements:Array<Expr> = [];

    /** Whether `ast` is complete (the text parsed without error). */
    public var parsed:Bool = false;

    public final root:Scope;
    public final symbols:Array<Symbol> = [];
    public final references:Array<Reference> = [];
    public final calls:Array<CallInfo> = [];
    public final diagnostics:Array<Diagnostic> = [];

    /** The start offset of each line. */
    final lineStarts:Array<Int> = [0];

    public function new(text:String, api:ScriptApi) {
        this.text = text;
        this.api = api;
        root = new Scope(null, 0, text.length, true);
        for (i in 0...text.length) {
            if (StringTools.fastCodeAt(text, i) == '\n'.code) {
                lineStarts.push(i + 1);
            }
        }
    }

    //#region positions

    public function lineCount():Int {
        return lineStarts.length;
    }

    /** The 0 based line of an offset. */
    public function lineOf(offset:Int):Int {
        var lo = 0;
        var hi = lineStarts.length - 1;
        while (lo < hi) {
            final mid = (lo + hi + 1) >> 1;
            if (lineStarts[mid] <= offset) {
                lo = mid;
            }
            else {
                hi = mid - 1;
            }
        }
        return lo;
    }

    public function lineStart(line:Int):Int {
        return line < 0 ? 0 : (line >= lineStarts.length ? text.length : lineStarts[line]);
    }

    /** The end of a line, before its line break. */
    public function lineEnd(line:Int):Int {
        var end = line + 1 < lineStarts.length ? lineStarts[line + 1] - 1 : text.length;
        if (end > lineStart(line) && StringTools.fastCodeAt(text, end - 1) == '\r'.code) {
            end--;
        }
        return end;
    }

    /** An LSP position (`{line, character}`, 0 based). */
    public function positionAt(offset:Int):Dynamic {
        if (offset < 0) {
            offset = 0;
        }
        if (offset > text.length) {
            offset = text.length;
        }
        final line = lineOf(offset);
        return {line: line, character: offset - lineStarts[line]};
    }

    public function offsetAt(position:Dynamic):Int {
        final line:Int = position.line;
        final character:Int = position.character;
        if (line >= lineStarts.length) {
            return text.length;
        }
        final offset = lineStart(line) + character;
        final end = lineEnd(line);
        return offset > end ? end : offset;
    }

    public function rangeOf(start:Int, end:Int):Dynamic {
        return {start: positionAt(start), end: positionAt(end)};
    }

    //#endregion

    //#region queries

    /** The innermost scope holding an offset. */
    public function scopeAt(offset:Int):Scope {
        var scope = root;
        var found = true;
        while (found) {
            found = false;
            for (child in scope.children) {
                if (child.start <= offset && offset <= child.end) {
                    scope = child;
                    found = true;
                    break;
                }
            }
        }
        return scope;
    }

    /**
     * The names visible at an offset, innermost first: what is declared
     * before it in the enclosing scopes, and the top level functions.
     */
    public function visibleSymbols(offset:Int):Array<Symbol> {
        final result:Array<Symbol> = [];
        final seen = new Map<String, Bool>();
        var scope:Null<Scope> = scopeAt(offset);
        while (scope != null) {
            for (symbol in scope.list) {
                if (!seen.exists(symbol.name) && (symbol.hoisted || symbol.nameEnd <= offset)) {
                    seen.set(symbol.name, true);
                    result.push(symbol);
                }
            }
            scope = scope.parent;
        }
        return result;
    }

    /** The reference covering an offset (its end included, like a cursor after a name). */
    public function referenceAt(offset:Int):Null<Reference> {
        var best:Null<Reference> = null;
        for (ref in references) {
            if (ref.start <= offset && offset <= ref.end) {
                if (best == null || offset < ref.end) {
                    best = ref;
                }
            }
        }
        return best;
    }

    public function symbolAt(offset:Int):Null<Symbol> {
        final ref = referenceAt(offset);
        return ref != null ? ref.symbol : null;
    }

    //#endregion

    //#region types

    public static function typeLabel(type:ValueType):String {
        return switch type {
            case TUnknown: 'Dynamic';
            case TNull: 'Null';
            case TInt: 'Int';
            case TFloat: 'Float';
            case TBool: 'Bool';
            case TString: 'String';
            case TArray: 'Array';
            case TMap: 'Map';
            case TObject(fields): fields.length == 0 ? '{}' : '{ ' + fields.join(', ') + ' }';
            case TFunction(params): 'function(' + params.join(', ') + ')';
            case TApi(entry): entry.kind == Object ? entry.name : (entry.type != null ? entry.type : 'Dynamic');
        }
    }

    /** The value type of an API type name (`Float`, `Color`, `Array<String>`...). */
    public static function typeOfName(name:Null<String>):ValueType {
        if (name == null) {
            return TUnknown;
        }
        return switch name {
            case 'Int' | 'Color': TInt;
            case 'Float': TFloat;
            case 'Bool': TBool;
            case 'String': TString;
            case _ if (StringTools.startsWith(name, 'Array')): TArray;
            case _: TUnknown;
        }
    }

    /** The built-in type whose methods a value has (`String`, `Array`, `Map`). */
    public static function builtinTypeName(type:ValueType):Null<String> {
        return switch type {
            case TString: 'String';
            case TArray: 'Array';
            case TMap: 'Map';
            case _: null;
        }
    }

    //#endregion

}
