package hscriptls.server;

import hscript.Expr;
import hscriptls.ScriptApi;
import hscriptls.server.Analysis;

/**
 * The language features of the server, computed from an `Analysis` and
 * returned as LSP values (anonymous structures, ready for JSON-RPC).
 * Positions are LSP's: 0 based lines and UTF-16 characters.
 */
class LanguageFeatures {

    /** LSP `CompletionItemKind` values. */
    static inline final KIND_METHOD = 2;
    static inline final KIND_FUNCTION = 3;
    static inline final KIND_FIELD = 5;
    static inline final KIND_VARIABLE = 6;
    static inline final KIND_CLASS = 7;
    static inline final KIND_MODULE = 9;
    static inline final KIND_PROPERTY = 10;
    static inline final KIND_KEYWORD = 14;
    static inline final KIND_SNIPPET = 15;
    static inline final KIND_CONSTANT = 21;

    /** LSP `SymbolKind` values. */
    static inline final SYMBOL_FUNCTION = 12;
    static inline final SYMBOL_VARIABLE = 13;

    /** The semantic token types and modifiers of the server. */
    public static final TOKEN_TYPES = ['variable', 'parameter', 'function', 'method', 'class', 'property'];
    public static final TOKEN_MODIFIERS = ['declaration', 'readonly', 'defaultLibrary'];

    static final SNIPPETS:Array<{label:String, detail:String, body:String}> = [
        {label: 'for', detail: 'for loop over a range', body: "for (${1:i} in ${2:0}...${3:10}) {\n\t$0\n}"},
        {label: 'forin', detail: 'for loop over an array', body: "for (${1:item} in ${2:items}) {\n\t$0\n}"},
        {label: 'if', detail: 'if statement', body: "if (${1:condition}) {\n\t$0\n}"},
        {label: 'ifelse', detail: 'if / else statement', body: "if (${1:condition}) {\n\t$2\n} else {\n\t$0\n}"},
        {label: 'while', detail: 'while loop', body: "while (${1:condition}) {\n\t$0\n}"},
        {label: 'function', detail: 'function declaration', body: "function ${1:name}(${2}) {\n\t$0\n}"},
        {label: 'switch', detail: 'switch statement', body: "switch (${1:value}) {\n\tcase ${2:0}:\n\t\t$0\n\tdefault:\n}"},
        {label: 'try', detail: 'try / catch', body: "try {\n\t$1\n} catch (${2:e}:Dynamic) {\n\t$0\n}"},
        {label: 'repeat', detail: 'repeat n times with the turtle', body: "for (${1:i} in 0...${2:4}) {\n\tturtle.forward(${3:100});\n\tturtle.turn(${4:90});\n}"}
    ];

    //#region completion

    public static function completion(a:Analysis, offset:Int):Dynamic {
        final text = a.text;
        if (insideCommentOrString(text, offset)) {
            return {isIncomplete: false, items: []};
        }
        var wordStart = offset;
        while (wordStart > 0 && isIdentChar(StringTools.fastCodeAt(text, wordStart - 1))) {
            wordStart--;
        }
        // after `.`: the fields of the value before it
        var dot = wordStart - 1;
        while (dot >= 0 && isBlank(StringTools.fastCodeAt(text, dot))) {
            dot--;
        }
        if (dot >= 0 && StringTools.fastCodeAt(text, dot) == '.'.code) {
            if (dot > 0 && StringTools.fastCodeAt(text, dot - 1) == '.'.code) {
                // `0...` is a range, not a field access
                return {isIncomplete: false, items: []};
            }
            return {isIncomplete: false, items: memberItems(a, receiverBefore(text, dot), offset)};
        }
        if (wordStart > 0 && isNumberStart(text, wordStart)) {
            return {isIncomplete: false, items: []};
        }
        final items:Array<Dynamic> = [];
        final seen = new Map<String, Bool>();
        for (symbol in a.visibleSymbols(offset)) {
            if (symbol.nameStart <= offset && offset <= symbol.nameEnd) {
                // the name being declared
                continue;
            }
            seen.set(symbol.name, true);
            items.push({
                label: symbol.name,
                kind: symbol.kind == SymbolKind.Function ? KIND_FUNCTION : KIND_VARIABLE,
                detail: symbolDetail(a, symbol),
                documentation: symbol.doc != null ? {kind: 'markdown', value: symbol.doc} : null,
                sortText: '0' + symbol.name
            });
        }
        for (entry in a.api.globals) {
            if (seen.exists(entry.name)) {
                continue;
            }
            items.push(apiItem(entry, null, '1'));
        }
        for (keyword in Analyzer.KEYWORDS) {
            items.push({label: keyword, kind: KIND_KEYWORD, sortText: '2' + keyword});
        }
        for (snippet in SNIPPETS) {
            items.push({
                label: snippet.label,
                kind: KIND_SNIPPET,
                detail: snippet.detail,
                insertText: snippet.body,
                insertTextFormat: 2,
                documentation: {kind: 'markdown', value: '```hscript\n' + StringTools.replace(snippet.body, '\t', '    ') + '\n```'},
                sortText: '3' + snippet.label
            });
        }
        return {isIncomplete: false, items: items};
    }

    static function apiItem(entry:ApiEntry, owner:Null<String>, sort:String):Dynamic {
        final isFunction = entry.kind == ApiKind.Function;
        final item:Dynamic = {
            label: entry.name,
            kind: switch entry.kind {
                case ApiKind.Function: owner != null ? KIND_METHOD : KIND_FUNCTION;
                case ApiKind.Object: KIND_CLASS;
                case ApiKind.Constant: KIND_CONSTANT;
                case ApiKind.Property: owner != null ? KIND_PROPERTY : KIND_VARIABLE;
            },
            detail: isFunction ? ScriptApi.signature(entry, owner != null ? owner + '.' : null) : (entry.kind == ApiKind.Object ? 'object ' + entry.name : entry.name + ':' + entry.type),
            documentation: {kind: 'markdown', value: ScriptApi.documentation(entry)},
            sortText: sort + entry.name
        };
        if (isFunction) {
            // `circle($1)`: the parameter hints open on the parentheses
            final params = entry.params != null ? entry.params : [];
            item.insertText = params.length == 0 ? entry.name + "()" : entry.name + "($0)";
            item.insertTextFormat = 2;
            if (params.length > 0) {
                item.command = {title: 'Trigger parameter hints', command: 'editor.action.triggerParameterHints'};
            }
        }
        return item;
    }

    static function memberItems(a:Analysis, receiver:Null<String>, offset:Int):Array<Dynamic> {
        if (receiver == null) {
            return [];
        }
        final type = typeOfName(a, receiver, offset);
        switch type {
            case TApi(entry) if (entry.fields != null):
                return [for (f in entry.fields) apiItem(f, entry.name, '0')];
            case TObject(fields):
                return [for (f in fields) {label: f, kind: KIND_FIELD, sortText: '0' + f}];
            case _:
                final builtin = Analysis.builtinTypeName(type);
                if (builtin != null) {
                    return [for (f in ScriptApi.builtinFields(builtin)) apiItem(f, builtin, '0')];
                }
                return [];
        }
    }

    /** The value type of a name at an offset: a visible symbol or a global. */
    static function typeOfName(a:Analysis, name:String, offset:Int):ValueType {
        for (symbol in a.visibleSymbols(offset)) {
            if (symbol.name == name) {
                return symbol.type;
            }
        }
        final global = a.api.get(name);
        if (global != null) {
            return global.kind == ApiKind.Object || global.kind == ApiKind.Function ? TApi(global) : Analysis.typeOfName(global.type);
        }
        return TUnknown;
    }

    /** The identifier right before a `.` (null when it is something else). */
    static function receiverBefore(text:String, dot:Int):Null<String> {
        var end = dot;
        while (end > 0 && isBlank(StringTools.fastCodeAt(text, end - 1))) {
            end--;
        }
        var start = end;
        while (start > 0 && isIdentChar(StringTools.fastCodeAt(text, start - 1))) {
            start--;
        }
        if (start == end || isDigit(StringTools.fastCodeAt(text, start))) {
            return null;
        }
        return text.substring(start, end);
    }

    //#endregion

    //#region hover

    public static function hover(a:Analysis, offset:Int):Dynamic {
        final ref = a.referenceAt(offset);
        if (ref == null) {
            return null;
        }
        final value = if (ref.symbol != null) {
            symbolMarkdown(a, ref.symbol);
        }
        else if (ref.api != null) {
            apiMarkdown(ref.api, ref.owner);
        }
        else {
            null;
        }
        if (value == null) {
            return null;
        }
        return {contents: {kind: 'markdown', value: value}, range: a.rangeOf(ref.start, ref.end)};
    }

    static function codeBlock(code:String):String {
        return '```hscript\n' + code + '\n```';
    }

    static function symbolDetail(a:Analysis, symbol:Symbol):String {
        return switch symbol.kind {
            case SymbolKind.Function: 'function ' + symbol.name + '(' + paramList(symbol) + ')';
            case SymbolKind.Parameter: '(parameter) ' + symbol.name + typeSuffix(symbol.type);
            case SymbolKind.LoopVariable: '(loop variable) ' + symbol.name + typeSuffix(symbol.type);
            case SymbolKind.CatchVariable: '(exception) ' + symbol.name;
            case SymbolKind.Variable:
                symbol.params != null ? 'var ' + symbol.name + ' = function(' + paramList(symbol) + ')' : 'var ' + symbol.name + typeSuffix(symbol.type);
        }
    }

    static function typeSuffix(type:ValueType):String {
        return type == TUnknown ? '' : ':' + Analysis.typeLabel(type);
    }

    static function paramList(symbol:Symbol):String {
        return symbol.params == null ? '' : [for (p in symbol.params) (p.optional ? '?' : '') + p.name].join(', ');
    }

    static function symbolMarkdown(a:Analysis, symbol:Symbol):String {
        final buf = new StringBuf();
        buf.add(codeBlock(symbolDetail(a, symbol)));
        final line = a.lineOf(symbol.nameStart) + 1;
        final where = switch symbol.kind {
            case SymbolKind.Function: symbol.isTopLevel() ? 'Function of the script' : 'Local function';
            case SymbolKind.Parameter: 'SymbolKind.Parameter of `' + containerName(symbol) + '`';
            case SymbolKind.LoopVariable: 'Loop variable';
            case SymbolKind.CatchVariable: 'The value thrown, in this catch clause';
            case SymbolKind.Variable: symbol.isTopLevel() ? 'Top level variable' : 'Local variable of `' + containerName(symbol) + '`';
        }
        buf.add('\n\n' + where + ', declared on line ' + line + '.');
        if (symbol.doc != null) {
            buf.add('\n\n---\n\n' + symbol.doc);
        }
        return buf.toString();
    }

    static function containerName(symbol:Symbol):String {
        if (symbol.container != null) {
            return symbol.container.name;
        }
        return symbol.kind == SymbolKind.Parameter ? 'anonymous function' : 'script';
    }

    static function apiMarkdown(entry:ApiEntry, owner:Null<String>):String {
        final prefix = owner != null ? owner + '.' : null;
        final code = switch entry.kind {
            case ApiKind.Function: ScriptApi.signature(entry, prefix);
            case ApiKind.Object: 'object ' + entry.name;
            case _: (prefix != null ? prefix : '') + entry.name + ':' + entry.type;
        }
        final origin = owner == null ? 'Runtime API' : (owner == 'String' || owner == 'Array' || owner == 'Map' ? owner + ' method' : 'Runtime API, `' + owner + '`');
        var doc = ScriptApi.documentation(entry);
        if (entry.kind == ApiKind.Object && entry.fields != null) {
            doc += '\n\nFields: ' + [for (f in entry.fields) '`' + f.name + '`'].join(', ');
        }
        return codeBlock(code) + '\n\n*' + origin + '*\n\n' + doc;
    }

    //#endregion

    //#region signature help

    /**
     * The signature of the call around an offset: found in the text (the
     * script may not parse while a call is typed), then resolved like the
     * analyzer resolves callees.
     */
    public static function signatureHelp(a:Analysis, offset:Int):Dynamic {
        final text = a.text;
        var depth = 0;
        var commas = 0;
        var i = offset - 1;
        var open = -1;
        while (i >= 0) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == ')'.code || c == ']'.code || c == '}'.code) {
                depth++;
            }
            else if (c == '('.code || c == '['.code || c == '{'.code) {
                if (depth == 0) {
                    if (c == '('.code) {
                        open = i;
                    }
                    break;
                }
                depth--;
            }
            else if (c == ','.code && depth == 0) {
                commas++;
            }
            else if (c == ';'.code && depth == 0) {
                break;
            }
            i--;
        }
        if (open < 0 || insideCommentOrString(text, offset)) {
            return null;
        }
        // the callee: `name` or `owner.name` before the parenthesis
        var end = open;
        while (end > 0 && isBlank(StringTools.fastCodeAt(text, end - 1))) {
            end--;
        }
        var start = end;
        while (start > 0 && isIdentChar(StringTools.fastCodeAt(text, start - 1))) {
            start--;
        }
        if (start == end) {
            return null;
        }
        final name = text.substring(start, end);
        var owner:Null<String> = null;
        if (start > 0 && StringTools.fastCodeAt(text, start - 1) == '.'.code) {
            owner = receiverBefore(text, start - 1);
            if (owner == null) {
                return null;
            }
        }
        var label:Null<String> = null;
        var doc:Null<String> = null;
        final offsets:Array<Array<Int>> = [];
        final paramDocs:Array<Null<String>> = [];
        if (owner == null) {
            var symbol:Null<Symbol> = null;
            for (s in a.visibleSymbols(offset)) {
                if (s.name == name) {
                    symbol = s;
                    break;
                }
            }
            if (symbol != null) {
                if (symbol.params == null) {
                    return null;
                }
                final buf = new StringBuf();
                buf.add(name + '(');
                var length = name.length + 1;
                for (j in 0...symbol.params.length) {
                    if (j > 0) {
                        buf.add(', ');
                        length += 2;
                    }
                    final p = (symbol.params[j].optional ? '?' : '') + symbol.params[j].name;
                    offsets.push([length, length + p.length]);
                    paramDocs.push(null);
                    buf.add(p);
                    length += p.length;
                }
                buf.add(')');
                label = buf.toString();
                doc = symbol.doc;
            }
            else {
                final global = a.api.get(name);
                if (global == null || global.kind != ApiKind.Function) {
                    return null;
                }
                label = ScriptApi.signature(global, null, offsets);
                doc = global.doc;
                for (p in global.params) {
                    paramDocs.push(p.doc);
                }
            }
        }
        else {
            var entry:Null<ApiEntry> = null;
            switch typeOfName(a, owner, offset) {
                case TApi(o):
                    entry = ScriptApi.field(o, name);
                case other:
                    final builtin = Analysis.builtinTypeName(other);
                    if (builtin != null) {
                        for (f in ScriptApi.builtinFields(builtin)) {
                            if (f.name == name) {
                                entry = f;
                            }
                        }
                    }
            }
            if (entry == null || entry.kind != ApiKind.Function) {
                return null;
            }
            label = ScriptApi.signature(entry, owner + '.', offsets);
            doc = entry.doc;
            for (p in entry.params) {
                paramDocs.push(p.doc);
            }
        }
        final parameters:Array<Dynamic> = [];
        for (j in 0...offsets.length) {
            final p:Dynamic = {label: offsets[j]};
            if (paramDocs[j] != null) {
                p.documentation = {kind: 'markdown', value: paramDocs[j]};
            }
            parameters.push(p);
        }
        final signature:Dynamic = {label: label, parameters: parameters};
        if (doc != null) {
            signature.documentation = {kind: 'markdown', value: doc};
        }
        return {signatures: [signature], activeSignature: 0, activeParameter: commas};
    }

    //#endregion

    //#region symbols, references, rename

    public static function definition(a:Analysis, uri:String, offset:Int):Dynamic {
        final symbol = a.symbolAt(offset);
        if (symbol == null) {
            return null;
        }
        return {uri: uri, range: a.rangeOf(symbol.nameStart, symbol.nameEnd)};
    }

    public static function references(a:Analysis, uri:String, offset:Int, includeDeclaration:Bool):Array<Dynamic> {
        final symbol = a.symbolAt(offset);
        if (symbol == null) {
            return [];
        }
        return [for (ref in symbol.refs) if (includeDeclaration || !ref.declaration) {uri: uri, range: a.rangeOf(ref.start, ref.end)}];
    }

    /** LSP `DocumentHighlight`s: 2 read, 3 write (a declaration writes). */
    public static function documentHighlights(a:Analysis, offset:Int):Array<Dynamic> {
        final symbol = a.symbolAt(offset);
        if (symbol == null) {
            return [];
        }
        return [for (ref in symbol.refs) {range: a.rangeOf(ref.start, ref.end), kind: ref.write || ref.declaration ? 3 : 2}];
    }

    public static function prepareRename(a:Analysis, offset:Int):Dynamic {
        final ref = a.referenceAt(offset);
        if (ref == null || ref.symbol == null) {
            return null;
        }
        return {range: a.rangeOf(ref.start, ref.end), placeholder: ref.symbol.name};
    }

    /**
     * The edits of a rename (an LSP `WorkspaceEdit`), or a message saying
     * why the name cannot be used.
     */
    public static function rename(a:Analysis, uri:String, offset:Int, newName:String):{?edit:Dynamic, ?error:String} {
        final symbol = a.symbolAt(offset);
        if (symbol == null) {
            return {error: 'Only the names declared in the script can be renamed.'};
        }
        if (!~/^[A-Za-z_][A-Za-z0-9_]*$/.match(newName)) {
            return {error: '`$newName` is not a valid identifier.'};
        }
        if (Analyzer.KEYWORDS.indexOf(newName) >= 0) {
            return {error: '`$newName` is a keyword.'};
        }
        if (newName != symbol.name && symbol.scope.symbols.exists(newName)) {
            return {error: '`$newName` is already declared in the same scope.'};
        }
        final edits:Array<Dynamic> = [for (ref in symbol.refs) {range: a.rangeOf(ref.start, ref.end), newText: newName}];
        final changes:Dynamic = {};
        Reflect.setField(changes, uri, edits);
        return {edit: {changes: changes}};
    }

    /**
     * The outline: top level functions and variables, with the functions
     * and variables declared inside the functions as children (they feed
     * the outline and the sticky scroll of the editor).
     */
    public static function documentSymbols(a:Analysis):Array<Dynamic> {
        final top = [for (symbol in a.symbols) if (symbol.isTopLevel() && (symbol.kind == SymbolKind.Function || symbol.kind == SymbolKind.Variable)) symbol];
        // in the order of the text (the top level functions are declared first)
        top.sort((x, y) -> x.nameStart - y.nameStart);
        return [for (symbol in top) documentSymbol(a, symbol)];
    }

    static function documentSymbol(a:Analysis, symbol:Symbol):Dynamic {
        final result:Dynamic = {
            name: symbol.name,
            detail: symbol.kind == SymbolKind.Function ? '(' + paramList(symbol) + ')' : typeSuffix(symbol.type),
            kind: symbol.kind == SymbolKind.Function ? SYMBOL_FUNCTION : SYMBOL_VARIABLE,
            range: a.rangeOf(symbol.declStart, symbol.declEnd),
            selectionRange: a.rangeOf(symbol.nameStart, symbol.nameEnd)
        };
        if (symbol.kind == SymbolKind.Function) {
            result.children = [for (child in symbol.children) if (child.kind == SymbolKind.Function || child.kind == SymbolKind.Variable) documentSymbol(a, child)];
        }
        return result;
    }

    //#endregion

    //#region folding, inlay hints, code lens, semantic tokens

    /**
     * Folding ranges: multi-line blocks, objects, arrays and switches (up to
     * the line before their closing bracket), block comments, and
     * `// #region` / `// #endregion` pairs. Null when the script does not
     * parse: the editor then folds by indentation.
     */
    public static function foldingRanges(a:Analysis):Null<Array<Dynamic>> {
        if (!a.parsed) {
            return null;
        }
        final ranges:Array<Dynamic> = [];
        function visit(e:Null<Expr>):Void {
            if (e == null) {
                return;
            }
            switch e.e {
                case EBlock(_) | EObject(_) | EArrayDecl(_) | ESwitch(_, _, _):
                    final startLine = a.lineOf(e.pmin);
                    var endLine = a.lineOf(e.pmax);
                    final close = e.pmax < a.text.length ? StringTools.fastCodeAt(a.text, e.pmax) : 0;
                    if (close == '}'.code || close == ']'.code) {
                        endLine--;
                    }
                    if (endLine > startLine) {
                        ranges.push({startLine: startLine, endLine: endLine});
                    }
                case _:
            }
            hscript.Tools.iter(e, visit);
        }
        for (statement in a.statements) {
            visit(statement);
        }
        // comments and regions
        final text = a.text;
        final regions:Array<Int> = [];
        var i = 0;
        while (i < text.length) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '"'.code || c == "'".code) {
                i++;
                while (i < text.length && StringTools.fastCodeAt(text, i) != c) {
                    if (StringTools.fastCodeAt(text, i) == '\\'.code) {
                        i++;
                    }
                    i++;
                }
            }
            else if (c == '/'.code && i + 1 < text.length && StringTools.fastCodeAt(text, i + 1) == '*'.code) {
                final close = text.indexOf('*/', i + 2);
                final end = close < 0 ? text.length : close + 2;
                final startLine = a.lineOf(i);
                final endLine = a.lineOf(end);
                if (endLine > startLine) {
                    ranges.push({startLine: startLine, endLine: endLine, kind: 'comment'});
                }
                i = end;
                continue;
            }
            else if (c == '/'.code && i + 1 < text.length && StringTools.fastCodeAt(text, i + 1) == '/'.code) {
                final line = a.lineOf(i);
                final content = StringTools.trim(text.substring(i + 2, a.lineEnd(line)));
                if (StringTools.startsWith(content, '#region')) {
                    regions.push(line);
                }
                else if (StringTools.startsWith(content, '#endregion') && regions.length > 0) {
                    ranges.push({startLine: regions.pop(), endLine: line, kind: 'region'});
                }
                i = a.lineEnd(line);
                continue;
            }
            i++;
        }
        return ranges;
    }

    /**
     * Parameter name hints before the arguments of the calls of API
     * functions and script functions (not when the argument already says
     * it: a variable of the same name, or a function).
     */
    public static function inlayHints(a:Analysis, start:Int, end:Int):Array<Dynamic> {
        final hints:Array<Dynamic> = [];
        for (call in a.calls) {
            if (call.end < start || call.start > end) {
                continue;
            }
            final names:Array<String> = if (call.api != null && call.api.params != null) {
                [for (p in call.api.params) p.name];
            }
            else if (call.symbol != null && call.symbol.params != null) {
                [for (p in call.symbol.params) p.name];
            }
            else {
                continue;
            }
            if (names.length == 0 || (names.length == 1 && names[0] == 'value')) {
                // `print(x)` says enough
                continue;
            }
            for (i in 0...call.args.length) {
                final arg = call.args[i];
                if (i >= names.length || arg == null || arg.pmin < start || arg.pmin > end) {
                    continue;
                }
                switch arg.e {
                    case EIdent(name) if (name == names[i]):
                        continue;
                    case EFunction(_, _, _, _):
                        continue;
                    case _:
                }
                hints.push({position: a.positionAt(argumentStart(a, arg)), label: names[i] + ':', kind: 2, paddingRight: true});
            }
        }
        return hints;
    }

    /**
     * Where an argument starts in the text: hscript gives a prefix unary
     * operation (`-x`, `!done`) the range of its operand.
     */
    static function argumentStart(a:Analysis, arg:Expr):Int {
        var start = arg.pmin;
        switch arg.e {
            case EUnop(op, true, _):
                var i = start - 1;
                while (i >= 0 && isBlank(StringTools.fastCodeAt(a.text, i))) {
                    i--;
                }
                if (i - op.length + 1 >= 0 && a.text.substr(i - op.length + 1, op.length) == op) {
                    start = i - op.length + 1;
                }
            case _:
        }
        return start;
    }

    /**
     * Above each top level function: its references (they open the
     * references peek), and `Run` for the functions that take no argument
     * (the host's `hscript.runFunction` command runs the script, then calls
     * the function).
     */
    public static function codeLenses(a:Analysis, uri:String):Array<Dynamic> {
        final lenses:Array<Dynamic> = [];
        for (symbol in a.symbols) {
            if (symbol.kind != SymbolKind.Function || !symbol.isTopLevel()) {
                continue;
            }
            final range = a.rangeOf(symbol.nameStart, symbol.nameEnd);
            var required = 0;
            for (p in symbol.params) {
                if (!p.optional) {
                    required++;
                }
            }
            if (required == 0) {
                lenses.push({range: range, command: {title: "$(play) Run " + symbol.name + '()', command: 'hscript.runFunction', arguments: [symbol.name]}});
            }
            final count = symbol.refs.length - 1;
            lenses.push({range: range, command: {
                title: count == 1 ? '1 reference' : count + ' references',
                command: 'editor.action.findReferences',
                arguments: [uri, a.positionAt(symbol.nameStart)]
            }});
        }
        return lenses;
    }

    /**
     * Semantic tokens (LSP's relative encoding): parameters, variables
     * (read-only for the API constants), script functions, API functions,
     * objects and fields (`defaultLibrary`).
     */
    public static function semanticTokens(a:Analysis):Array<Int> {
        final data:Array<Int> = [];
        var lastLine = 0;
        var lastChar = 0;
        for (ref in a.references) {
            var type = -1;
            var modifiers = 0;
            if (ref.symbol != null) {
                type = switch ref.symbol.kind {
                    case SymbolKind.Parameter: 1;
                    case SymbolKind.Function: 2;
                    case _: ref.symbol.params != null ? 2 : 0;
                };
                if (ref.declaration) {
                    modifiers |= 1;
                }
            }
            else if (ref.api != null) {
                modifiers |= 4;
                final member = ref.owner != null;
                type = switch ref.api.kind {
                    case ApiKind.Function: member ? 3 : 2;
                    case ApiKind.Object: 4;
                    case ApiKind.Constant:
                        modifiers |= 2;
                        member ? 5 : 0;
                    case ApiKind.Property: member ? 5 : 0;
                };
            }
            if (type < 0) {
                continue;
            }
            final position = a.positionAt(ref.start);
            final line:Int = position.line;
            final character:Int = position.character;
            final deltaLine = line - lastLine;
            data.push(deltaLine);
            data.push(deltaLine == 0 ? character - lastChar : character);
            data.push(ref.end - ref.start);
            data.push(type);
            data.push(modifiers);
            lastLine = line;
            lastChar = character;
        }
        return data;
    }

    //#endregion

    //#region text helpers

    static inline function isIdentChar(c:Int):Bool {
        return (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code;
    }

    static inline function isDigit(c:Int):Bool {
        return c >= '0'.code && c <= '9'.code;
    }

    static inline function isBlank(c:Int):Bool {
        return c == ' '.code || c == '\t'.code;
    }

    static function isNumberStart(text:String, start:Int):Bool {
        return start < text.length && isDigit(StringTools.fastCodeAt(text, start));
    }

    /** Whether an offset is inside a comment or a string (a scan from the start). */
    public static function insideCommentOrString(text:String, offset:Int):Bool {
        var i = 0;
        while (i < offset) {
            final c = StringTools.fastCodeAt(text, i);
            if (c == '/'.code && i + 1 < text.length) {
                final next = StringTools.fastCodeAt(text, i + 1);
                if (next == '/'.code) {
                    final newline = text.indexOf('\n', i);
                    if (newline < 0 || newline >= offset) {
                        return true;
                    }
                    i = newline + 1;
                    continue;
                }
                if (next == '*'.code) {
                    final close = text.indexOf('*/', i + 2);
                    if (close < 0 || close + 2 > offset) {
                        return true;
                    }
                    i = close + 2;
                    continue;
                }
            }
            if (c == '"'.code || c == "'".code) {
                var j = i + 1;
                while (j < text.length && StringTools.fastCodeAt(text, j) != c) {
                    if (StringTools.fastCodeAt(text, j) == '\\'.code) {
                        j++;
                    }
                    j++;
                }
                if (j >= offset) {
                    return true;
                }
                i = j + 1;
                continue;
            }
            i++;
        }
        return false;
    }

    //#endregion

}
