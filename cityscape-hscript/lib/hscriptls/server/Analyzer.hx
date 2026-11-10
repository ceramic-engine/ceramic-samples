package hscriptls.server;

import hscript.Expr;
import hscript.Parser;
import hscriptls.ScriptApi;
import hscriptls.server.Analysis;

/**
 * Where the walk is: inside how many functions and loops.
 */
private typedef WalkContext = {
    var functionDepth:Int;
    var loopDepth:Int;
    var container:Null<Symbol>;
}

/**
 * Analyzes an hscript script: parses it with hscript's own `Parser`
 * (positions on, types, JSON objects and metadata allowed, like the
 * sample's runtime), then walks the syntax tree with the scoping rules of
 * hscript's `Interp`:
 *
 * - a `var` is visible after its declaration, until the end of its block;
 * - a named function at the top level is a global, defined when its
 *   declaration runs: calling it from the top level before that line fails,
 *   calling it from another function is fine;
 * - a function sees the variables declared before it (Interp copies the
 *   locals when the function is created), not the ones declared after;
 * - default values of parameters are parsed but ignored: an omitted
 *   argument is null.
 *
 * Diagnostics: parse errors, unknown identifiers and fields, unused
 * variables and parameters, duplicate declarations in a scope, argument
 * counts of the API functions and of script functions, `break` outside a
 * loop, ignored default values, and names hiding a global of the API.
 */
class Analyzer {

    public static final KEYWORDS = [
        'var', 'function', 'if', 'else', 'for', 'in', 'while', 'do', 'switch', 'case', 'default',
        'break', 'continue', 'return', 'try', 'catch', 'throw', 'new', 'null', 'true', 'false', 'inline'
    ];

    final api:ScriptApi;
    var a:Analysis;
    var text:String;

    /** The top level functions, by the offset of their node. */
    final hoisted:Map<Int, Symbol> = new Map();

    /** The top level variables, name to declaration offset. */
    final topLevelVars:Map<String, Int> = new Map();

    public function new(api:ScriptApi) {
        this.api = api;
    }

    public static function analyze(text:String, api:ScriptApi):Analysis {
        return new Analyzer(api).run(text);
    }

    public function run(text:String):Analysis {
        this.text = text;
        a = new Analysis(text, api);
        parse();
        if (a.ast != null) {
            collectTopLevel();
            final ctx:WalkContext = {functionDepth: 0, loopDepth: 0, container: null};
            for (statement in a.statements) {
                walk(statement, a.root, ctx);
            }
            reportUnused();
        }
        if (!a.parsed) {
            // the tree of hscript's error recovery serves completion and the
            // outline; its other diagnostics would be noise around the error
            final kept = [for (d in a.diagnostics) if (d.code == 'parse-error') d];
            a.diagnostics.resize(0);
            for (d in kept) {
                a.diagnostics.push(d);
            }
        }
        a.diagnostics.sort((x, y) -> x.start - y.start);
        a.references.sort((x, y) -> x.start - y.start);
        return a;
    }

    //#region parsing

    static function newParser():Parser {
        final parser = new Parser();
        parser.allowTypes = true;
        parser.allowJSON = true;
        parser.allowMetadata = true;
        return parser;
    }

    function parse():Void {
        try {
            a.ast = newParser().parseString(text, 'script');
            a.parsed = true;
        }
        catch (e:hscript.Expr.Error) {
            reportParseError(e);
            // hscript's error recovery, for completion and the outline
            // while the text is being typed
            try {
                final parser = newParser();
                parser.resumeErrors = true;
                a.ast = parser.parseString(text, 'script');
            }
            catch (_:Dynamic) {
                a.ast = null;
            }
        }
        catch (e:Dynamic) {
            a.diagnostics.push({start: 0, end: 0, severity: 1, message: Std.string(e), code: 'parse-error'});
        }
        final ast = a.ast;
        if (ast == null) {
            return;
        }
        // `parseString` gives the only statement, or a block of all of them
        // (a block made by the parser, not a `{` of the text)
        switch ast.e {
            case EBlock(list) if (ast.pmin >= text.length || StringTools.fastCodeAt(text, ast.pmin) != '{'.code):
                for (e in list) {
                    if (e != null) {
                        a.statements.push(e);
                    }
                }
            case _:
                a.statements.push(ast);
        }
    }

    function reportParseError(e:hscript.Expr.Error):Void {
        var start = e.pmin;
        var end = e.pmax + 1;
        final message = switch e.e {
            case EInvalidChar(c): 'Invalid character `' + String.fromCharCode(c) + '`';
            case EUnexpected(s) if (s == '<eof>'): 'Unexpected end of script';
            case EUnexpected(s): 'Unexpected `' + s + '`';
            case EUnterminatedString:
                end = a.lineEnd(a.lineOf(start));
                'Unterminated string';
            case EUnterminatedComment:
                end = a.lineEnd(a.lineOf(start));
                'Unterminated comment';
            case EInvalidPreprocessor(msg): 'Invalid preprocessor directive: ' + msg;
            case ECustom(msg): msg;
            case _: hscript.Printer.errorToString(e);
        }
        if (start > text.length) {
            start = text.length;
        }
        if (end > text.length) {
            end = text.length;
        }
        if (end <= start) {
            // the end of the script: underline the last character
            if (start >= text.length && text.length > 0) {
                start = text.length - 1;
                while (start > 0 && isSpace(StringTools.fastCodeAt(text, start))) {
                    start--;
                }
            }
            end = start + 1 > text.length ? text.length : start + 1;
        }
        a.diagnostics.push({start: start, end: end, severity: 1, message: message, code: 'parse-error'});
    }

    //#endregion

    //#region declarations

    function collectTopLevel():Void {
        for (statement in a.statements) {
            switch statement.e {
                case EFunction(args, _, name, _) if (name != null):
                    final symbol = declareFunction(statement, name, args, a.root, null);
                    if (symbol != null) {
                        symbol.hoisted = true;
                        hoisted.set(statement.pmin, symbol);
                    }
                case EVar(name, _, _):
                    if (!topLevelVars.exists(name)) {
                        topLevelVars.set(name, statement.pmin);
                    }
                case _:
            }
        }
    }

    function declare(scope:Scope, name:String, kind:SymbolKind, nameStart:Int, container:Null<Symbol>):Symbol {
        final symbol = new Symbol(name, kind, nameStart, nameStart + name.length, scope);
        symbol.container = container;
        final existing = scope.symbols.get(name);
        if (existing != null && !isGenerated(name)) {
            final line = a.lineOf(existing.nameStart) + 1;
            if (kind == SymbolKind.Parameter && existing.kind == SymbolKind.Parameter) {
                a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 1, code: 'duplicate-declaration',
                    message: 'Duplicate parameter `$name`.'});
            }
            else {
                a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 2, code: 'duplicate-declaration',
                    message: '`$name` is already declared in this scope (line $line).',
                    related: [{start: existing.nameStart, end: existing.nameEnd, message: 'First declaration of `$name`'}]});
            }
        }
        final global = api.get(name);
        if (global != null && !isGenerated(name)) {
            a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 2, code: 'shadowed-global',
                message: '`$name` hides the global `$name` of the runtime API.'});
        }
        scope.symbols.set(name, symbol);
        scope.list.push(symbol);
        if (!isGenerated(name)) {
            a.symbols.push(symbol);
            final ref = new Reference(symbol.nameStart, symbol.nameEnd, symbol, null, null, false, true);
            symbol.refs.push(ref);
            a.references.push(ref);
            if (container != null) {
                container.children.push(symbol);
            }
        }
        return symbol;
    }

    function declareFunction(e:Expr, name:String, args:Array<Argument>, scope:Scope, container:Null<Symbol>):Null<Symbol> {
        final keyword = findWord('function', e.pmin, e.pmax + 1);
        final nameStart = findWord(name, keyword >= 0 ? keyword + 8 : e.pmin, e.pmax + 1);
        if (nameStart < 0) {
            return null;
        }
        final symbol = declare(scope, name, SymbolKind.Function, nameStart, container);
        symbol.declStart = e.pmin;
        symbol.declEnd = e.pmax + 1;
        symbol.params = [for (arg in args) {name: arg.name, optional: arg.opt == true || arg.value != null}];
        symbol.type = TFunction([for (arg in args) arg.name]);
        symbol.doc = docBefore(e.pmin);
        return symbol;
    }

    static inline function isGenerated(name:String):Bool {
        // the temporary variables of `?.` and array comprehensions
        return StringTools.startsWith(name, '__a_');
    }

    //#endregion

    //#region walk

    function walk(e:Null<Expr>, scope:Scope, ctx:WalkContext):Void {
        if (e == null) {
            return;
        }
        switch e.e {
            case EConst(_):
            case EIdent(name):
                useIdent(name, e.pmin, e.pmax + 1, scope, ctx, false, true);
            case EVar(name, _, init):
                walk(init, scope, ctx);
                final nameStart = findWord(name, e.pmin + 3, e.pmax + 1);
                if (nameStart >= 0 || isGenerated(name)) {
                    final symbol = declare(scope, name, SymbolKind.Variable, nameStart >= 0 ? nameStart : e.pmin, ctx.container);
                    symbol.declStart = e.pmin;
                    symbol.declEnd = e.pmax + 1;
                    symbol.doc = docBefore(e.pmin);
                    if (init != null) {
                        symbol.type = inferType(init, scope);
                        switch init.e {
                            case EFunction(args, _, _, _):
                                symbol.params = [for (arg in args) {name: arg.name, optional: arg.opt == true || arg.value != null}];
                            case _:
                        }
                    }
                }
            case EParent(inner):
                walk(inner, scope, ctx);
            case EBlock(list):
                final block = new Scope(scope, e.pmin, e.pmax + 1, false);
                for (item in list) {
                    walk(item, block, ctx);
                }
            case EField(obj, field):
                walk(obj, scope, ctx);
                useField(obj, field, e, scope);
            case EBinop(op, left, right):
                if (op == '=' || (op.length > 1 && op.charAt(op.length - 1) == '=' && op != '==' && op != '!=' && op != '<=' && op != '>=')) {
                    walk(right, scope, ctx);
                    switch left != null ? left.e : null {
                        case EIdent(name):
                            // `x = v` writes, `x += v` reads and writes
                            useIdent(name, left.pmin, left.pmax + 1, scope, ctx, true, op != '=');
                        case _:
                            walk(left, scope, ctx);
                    }
                }
                else {
                    walk(left, scope, ctx);
                    walk(right, scope, ctx);
                }
            case EUnop(op, _, operand):
                switch operand != null ? operand.e : null {
                    case EIdent(name) if (op == '++' || op == '--'):
                        useIdent(name, operand.pmin, operand.pmax + 1, scope, ctx, true, true);
                    case _:
                        walk(operand, scope, ctx);
                }
            case ECall(callee, args):
                walk(callee, scope, ctx);
                for (arg in args) {
                    walk(arg, scope, ctx);
                }
                checkCall(e, callee, args, scope);
            case EIf(cond, then, otherwise):
                walk(cond, scope, ctx);
                walk(then, scope, ctx);
                walk(otherwise, scope, ctx);
            case ETernary(cond, then, otherwise):
                walk(cond, scope, ctx);
                walk(then, scope, ctx);
                walk(otherwise, scope, ctx);
            case EWhile(cond, body) | EDoWhile(cond, body):
                walk(cond, scope, ctx);
                ctx.loopDepth++;
                walk(body, scope, ctx);
                ctx.loopDepth--;
            case EFor(name, iterator, body):
                walk(iterator, scope, ctx);
                final loop = new Scope(scope, e.pmin, e.pmax + 1, false);
                final nameStart = findWord(name, e.pmin + 3, e.pmax + 1);
                if (nameStart >= 0) {
                    final symbol = declare(loop, name, SymbolKind.LoopVariable, nameStart, ctx.container);
                    symbol.declStart = e.pmin;
                    symbol.declEnd = e.pmax + 1;
                    symbol.type = switch iterator != null ? iterator.e : null {
                        case EBinop('...', _, _): TInt;
                        case _: TUnknown;
                    };
                }
                ctx.loopDepth++;
                walk(body, loop, ctx);
                ctx.loopDepth--;
            case EBreak | EContinue:
                if (ctx.loopDepth == 0) {
                    final keyword = e.e == EBreak ? 'break' : 'continue';
                    a.diagnostics.push({start: e.pmin, end: e.pmin + keyword.length, severity: 1, code: 'outside-loop',
                        message: '`$keyword` is only allowed inside a loop.'});
                }
            case EFunction(args, body, name, _):
                walkFunction(e, args, body, name, scope, ctx);
            case EReturn(value):
                walk(value, scope, ctx);
            case EArray(target, index):
                walk(target, scope, ctx);
                walk(index, scope, ctx);
            case EArrayDecl(list):
                for (item in list) {
                    walk(item, scope, ctx);
                }
            case ENew(cl, args):
                for (arg in args) {
                    walk(arg, scope, ctx);
                }
                final start = findWord(cl.split('.')[0], e.pmin + 3, e.pmax + 1);
                if (start >= 0) {
                    a.diagnostics.push({start: start, end: start + cl.length, severity: 2, code: 'unknown-class',
                        message: 'The runtime exposes no class `$cl`: `new` only finds the Haxe classes compiled into the app.'});
                }
            case EThrow(value):
                walk(value, scope, ctx);
            case ETry(body, name, _, handler):
                walk(body, scope, ctx);
                final clause = new Scope(scope, body != null ? body.pmax + 1 : e.pmin, e.pmax + 1, false);
                final keyword = findWord('catch', body != null ? body.pmax + 1 : e.pmin, e.pmax + 1);
                final nameStart = keyword >= 0 ? findWord(name, keyword + 5, e.pmax + 1) : -1;
                if (nameStart >= 0) {
                    final symbol = declare(clause, name, SymbolKind.CatchVariable, nameStart, ctx.container);
                    symbol.declStart = keyword;
                    symbol.declEnd = e.pmax + 1;
                }
                walk(handler, clause, ctx);
            case EObject(fields):
                for (field in fields) {
                    walk(field.e, scope, ctx);
                }
            case ESwitch(value, cases, def):
                walk(value, scope, ctx);
                for (c in cases) {
                    for (v in c.values) {
                        walk(v, scope, ctx);
                    }
                    walk(c.expr, scope, ctx);
                }
                walk(def, scope, ctx);
            case EMeta(_, _, inner):
                // the arguments of metadata are not evaluated by Interp
                walk(inner, scope, ctx);
            case ECheckType(inner, _):
                walk(inner, scope, ctx);
        }
    }

    function walkFunction(e:Expr, args:Array<Argument>, body:Null<Expr>, name:Null<String>, scope:Scope, ctx:WalkContext):Void {
        var symbol:Null<Symbol> = hoisted.get(e.pmin);
        if (symbol == null && name != null) {
            // a local function: visible after its declaration (and in itself)
            symbol = declareFunction(e, name, args, scope, ctx.container);
        }
        final fnScope = new Scope(scope, e.pmin, e.pmax + 1, true);
        // the parameters: after `(` for `function`, from the start for `x -> e`
        var searchFrom = e.pmin;
        final keyword = findWord('function', e.pmin, e.pmin + 9);
        if (keyword == e.pmin) {
            final paren = text.indexOf('(', e.pmin);
            searchFrom = paren >= 0 ? paren : e.pmin;
        }
        final inner:WalkContext = {functionDepth: ctx.functionDepth + 1, loopDepth: 0, container: symbol != null ? symbol : ctx.container};
        for (arg in args) {
            final start = findWord(arg.name, searchFrom, e.pmax + 1);
            if (start < 0) {
                continue;
            }
            searchFrom = start + arg.name.length;
            final param = declare(fnScope, arg.name, SymbolKind.Parameter, start, symbol);
            param.declStart = start;
            param.declEnd = start + arg.name.length;
            if (arg.value != null) {
                walk(arg.value, fnScope, inner);
                a.diagnostics.push({start: arg.value.pmin, end: arg.value.pmax + 1, severity: 2, code: 'ignored-default',
                    message: 'hscript ignores default values: `${arg.name}` is null when the argument is omitted.'});
            }
        }
        walk(body, fnScope, inner);
    }

    /**
     * A read (and/or write) of a name: a symbol in scope, a global of the
     * API, or an unknown name.
     */
    function useIdent(name:String, start:Int, end:Int, scope:Scope, ctx:WalkContext, write:Bool, read:Bool):Void {
        if (isGenerated(name)) {
            return;
        }
        switch name {
            case 'null' | 'true' | 'false':
                return;
            case _:
        }
        final symbol = scope.lookup(name);
        if (symbol != null) {
            final ref = new Reference(start, end, symbol, null, null, write, false);
            symbol.refs.push(ref);
            a.references.push(ref);
            if (read) {
                symbol.reads++;
            }
            if (write) {
                symbol.writes++;
            }
            if (symbol.hoisted && ctx.functionDepth == 0 && start < symbol.declStart) {
                final line = a.lineOf(symbol.nameStart) + 1;
                a.diagnostics.push({start: start, end: end, severity: 1, code: 'used-before-declaration',
                    message: '`$name` is used before its declaration (line $line): hscript defines a function when its declaration runs.',
                    related: [{start: symbol.nameStart, end: symbol.nameEnd, message: 'Declaration of `$name`'}]});
            }
            return;
        }
        final global = api.get(name);
        if (global != null) {
            a.references.push(new Reference(start, end, null, global, null, write, false));
            return;
        }
        // a top level variable declared after the function using it
        final later = topLevelVars.get(name);
        if (later != null && ctx.functionDepth > 0) {
            final line = a.lineOf(later) + 1;
            a.diagnostics.push({start: start, end: end, severity: 1, code: 'unknown-identifier', data: {name: name},
                message: '`$name` is declared after this function (line $line): hscript functions only see the variables declared before them.'});
            return;
        }
        a.diagnostics.push({start: start, end: end, severity: 1, code: 'unknown-identifier', data: {name: name},
            message: 'Unknown identifier `$name`.'});
    }

    /** A field read: checked on API objects, kept for hover on known values. */
    function useField(obj:Null<Expr>, field:Null<String>, e:Expr, scope:Scope):Void {
        if (obj == null || field == null) {
            return;
        }
        final end = e.pmax + 1;
        final start = end - field.length;
        if (start < 0 || text.substring(start, end) != field) {
            return;
        }
        final type = inferType(obj, scope);
        switch type {
            case TApi(entry) if (entry.kind == ApiKind.Object):
                final f = ScriptApi.field(entry, field);
                if (f != null) {
                    a.references.push(new Reference(start, end, null, f, entry.name, false, false));
                }
                else {
                    a.diagnostics.push({start: start, end: end, severity: 1, code: 'unknown-field', data: {name: field, owner: entry.name},
                        message: '`${entry.name}` has no field `$field`.'});
                }
            case _:
                final builtin = Analysis.builtinTypeName(type);
                if (builtin != null) {
                    for (f in ScriptApi.builtinFields(builtin)) {
                        if (f.name == field) {
                            a.references.push(new Reference(start, end, null, f, builtin, false, false));
                            break;
                        }
                    }
                }
        }
    }

    /** Records a call and checks its argument count when the callee is known. */
    function checkCall(e:Expr, callee:Null<Expr>, args:Array<Expr>, scope:Scope):Void {
        if (callee == null) {
            return;
        }
        final call:CallInfo = {start: callee.pmin, end: e.pmax + 1, args: args};
        var label:Null<String> = null;
        var min = 0;
        var max = 0;
        var scriptFunction = false;
        switch callee.e {
            case EIdent(name) if (!isGenerated(name)):
                final symbol = scope.lookup(name);
                if (symbol != null) {
                    if (symbol.params != null) {
                        call.symbol = symbol;
                        label = name;
                        max = symbol.params.length;
                        for (p in symbol.params) {
                            if (!p.optional) {
                                min++;
                            }
                        }
                        scriptFunction = true;
                    }
                }
                else {
                    final global = api.get(name);
                    if (global != null && global.kind == ApiKind.Function) {
                        call.api = global;
                        label = name;
                        final arity = ScriptApi.arity(global);
                        min = arity.min;
                        max = arity.max;
                    }
                }
            case EField(obj, field):
                switch inferType(obj, scope) {
                    case TApi(entry) if (entry.kind == ApiKind.Object):
                        final f = ScriptApi.field(entry, field);
                        if (f != null && f.kind == ApiKind.Function) {
                            call.api = f;
                            call.apiOwner = entry.name;
                            label = entry.name + '.' + field;
                            final arity = ScriptApi.arity(f);
                            min = arity.min;
                            max = arity.max;
                        }
                    case _:
                }
            case _:
        }
        a.calls.push(call);
        if (label == null) {
            return;
        }
        final count = args.length;
        if (count >= min && count <= max) {
            return;
        }
        final expected = min == max ? '$min argument' + (min == 1 ? '' : 's') : 'from $min to $max arguments';
        final start = count > max ? args[max].pmin : callee.pmin;
        final end = count > max ? args[count - 1].pmax + 1 : e.pmax + 1;
        if (scriptFunction && count > max) {
            // Interp drops the extra arguments of script functions
            a.diagnostics.push({start: start, end: end, severity: 2, code: 'argument-count',
                message: '`$label` takes $expected, got $count: the extra arguments are ignored.'});
        }
        else {
            a.diagnostics.push({start: start, end: end, severity: 1, code: 'argument-count',
                message: '`$label` expects $expected, got $count.'});
        }
    }

    function reportUnused():Void {
        for (symbol in a.symbols) {
            if (symbol.reads > 0 || StringTools.startsWith(symbol.name, '_')) {
                continue;
            }
            switch symbol.kind {
                case SymbolKind.Variable:
                    a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 4, code: 'unused-variable', tags: [1],
                        data: {name: symbol.name},
                        message: symbol.writes > 0 ? '`${symbol.name}` is assigned but its value is never read.' : '`${symbol.name}` is declared but never used.'});
                case SymbolKind.Parameter:
                    a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 4, code: 'unused-parameter', tags: [1],
                        message: 'Parameter `${symbol.name}` is never used.'});
                case SymbolKind.Function if (!symbol.isTopLevel()):
                    a.diagnostics.push({start: symbol.nameStart, end: symbol.nameEnd, severity: 4, code: 'unused-function', tags: [1],
                        message: 'Function `${symbol.name}` is never called.'});
                case _:
            }
        }
    }

    //#endregion

    //#region types

    function inferType(e:Null<Expr>, scope:Scope):ValueType {
        if (e == null) {
            return TUnknown;
        }
        return switch e.e {
            case EConst(CInt(_)): TInt;
            case EConst(CFloat(_)): TFloat;
            case EConst(CString(_)): TString;
            case EIdent('true') | EIdent('false'): TBool;
            case EIdent('null'): TNull;
            case EIdent(name):
                final symbol = scope.lookup(name);
                if (symbol != null) {
                    symbol.type;
                }
                else {
                    final global = api.get(name);
                    if (global == null) {
                        TUnknown;
                    }
                    else if (global.kind == ApiKind.Constant || global.kind == ApiKind.Property) {
                        Analysis.typeOfName(global.type);
                    }
                    else {
                        TApi(global);
                    }
                }
            case EParent(inner): inferType(inner, scope);
            case EArrayDecl(list):
                if (list.length > 0 && list[0] != null && list[0].e.match(EBinop('=>', _, _))) TMap else TArray;
            case EObject(fields): TObject([for (f in fields) f.name]);
            case EFunction(args, _, _, _): TFunction([for (arg in args) arg.name]);
            case ECall(callee, _):
                switch callee != null ? callee.e : null {
                    case EIdent(name) if (scope.lookup(name) == null && api.get(name) != null):
                        Analysis.typeOfName(api.get(name).type);
                    case EField(obj, field):
                        switch inferType(obj, scope) {
                            case TApi(entry):
                                final f = ScriptApi.field(entry, field);
                                f != null ? Analysis.typeOfName(f.type) : TUnknown;
                            case other:
                                final builtin = Analysis.builtinTypeName(other);
                                var result = TUnknown;
                                if (builtin != null) {
                                    for (f in ScriptApi.builtinFields(builtin)) {
                                        if (f.name == field) {
                                            result = Analysis.typeOfName(f.type);
                                        }
                                    }
                                }
                                result;
                        }
                    case _: TUnknown;
                }
            case EField(obj, field):
                switch inferType(obj, scope) {
                    case TApi(entry):
                        final f = ScriptApi.field(entry, field);
                        f == null ? TUnknown : (f.kind == ApiKind.Object ? TApi(f) : (f.kind == ApiKind.Function ? TApi(f) : Analysis.typeOfName(f.type)));
                    case TString | TArray if (field == 'length'): TInt;
                    case _: TUnknown;
                }
            case EBinop(op, left, right):
                switch op {
                    case '==' | '!=' | '<' | '>' | '<=' | '>=' | '&&' | '||' | 'is': TBool;
                    case '=': inferType(right, scope);
                    case '+' | '-' | '*' | '/' | '%':
                        final l = inferType(left, scope);
                        final r = inferType(right, scope);
                        if (op == '+' && (l == TString || r == TString)) TString
                        else if (op == '/' && isNumber(l) && isNumber(r)) TFloat
                        else if (l == TInt && r == TInt) TInt
                        else if (isNumber(l) && isNumber(r)) TFloat
                        else TUnknown;
                    case _: TUnknown;
                }
            case EUnop('!', _, _): TBool;
            case EUnop(_, _, operand): inferType(operand, scope);
            case ETernary(_, then, otherwise):
                final t = inferType(then, scope);
                Type.enumEq(t, inferType(otherwise, scope)) ? t : TUnknown;
            case _: TUnknown;
        }
    }

    static inline function isNumber(t:ValueType):Bool {
        return t == TInt || t == TFloat;
    }

    //#endregion

    //#region text

    static inline function isSpace(c:Int):Bool {
        return c == ' '.code || c == '\t'.code || c == '\n'.code || c == '\r'.code;
    }

    static inline function isIdentChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    /**
     * The offset of `word` as a whole word in `[from, to)`, outside of
     * comments and strings, or -1. The syntax tree has no position for the
     * names of declarations: they are found after the start of their node.
     */
    function findWord(word:String, from:Int, to:Int):Int {
        if (to > text.length) {
            to = text.length;
        }
        var i = from < 0 ? 0 : from;
        final first = StringTools.fastCodeAt(word, 0);
        while (i < to) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '/'.code && i + 1 < text.length) {
                final next = StringTools.fastCodeAt(text, i + 1);
                if (next == '/'.code) {
                    while (i < to && StringTools.fastCodeAt(text, i) != '\n'.code) {
                        i++;
                    }
                    continue;
                }
                if (next == '*'.code) {
                    final close = text.indexOf('*/', i + 2);
                    i = close < 0 ? to : close + 2;
                    continue;
                }
            }
            if (c == '"'.code || c == "'".code) {
                i++;
                while (i < to && StringTools.fastCodeAt(text, i) != c) {
                    if (StringTools.fastCodeAt(text, i) == '\\'.code) {
                        i++;
                    }
                    i++;
                }
                i++;
                continue;
            }
            if (c == first && (i == 0 || !isIdentChar(StringTools.fastCodeAt(text, i - 1)))
                && i + word.length <= text.length && text.substr(i, word.length) == word
                && (i + word.length >= text.length || !isIdentChar(StringTools.fastCodeAt(text, i + word.length)))) {
                return i;
            }
            i++;
        }
        return -1;
    }

    /**
     * The documentation comment right before a declaration: a `/** *\/`
     * or `/* *\/` block, or consecutive `//` lines, without their markers.
     */
    function docBefore(offset:Int):Null<String> {
        var i = offset - 1;
        while (i >= 0 && isSpace(StringTools.fastCodeAt(text, i))) {
            i--;
        }
        if (i >= 1 && StringTools.fastCodeAt(text, i) == '/'.code && StringTools.fastCodeAt(text, i - 1) == '*'.code) {
            final open = text.lastIndexOf('/*', i - 1);
            if (open < 0) {
                return null;
            }
            final lines = text.substring(open + 2, i - 1).split('\n');
            final cleaned = [for (line in lines) {
                var l = StringTools.trim(line);
                while (StringTools.startsWith(l, '*')) {
                    l = StringTools.trim(l.substr(1));
                }
                l;
            }];
            final doc = StringTools.trim(cleaned.join('\n'));
            return doc != '' ? doc : null;
        }
        // `//` lines, read upwards
        final lines:Array<String> = [];
        var line = a.lineOf(offset) - 1;
        while (line >= 0) {
            final content = StringTools.trim(text.substring(a.lineStart(line), a.lineEnd(line)));
            if (!StringTools.startsWith(content, '//')) {
                break;
            }
            lines.unshift(StringTools.trim(content.substr(2)));
            line--;
        }
        return lines.length > 0 ? lines.join('\n') : null;
    }

    //#endregion

}
