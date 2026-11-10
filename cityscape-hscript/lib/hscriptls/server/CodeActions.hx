package hscriptls.server;

import hscriptls.server.Analysis;

/**
 * The quick fixes of the diagnostics of the analyzer, as LSP `CodeAction`s
 * with a `WorkspaceEdit`:
 *
 * - unknown identifier: declare it (`var` before an assignment, or a
 *   `var name = null;` line before the statement), or change it to a
 *   similar name in scope or of the API;
 * - unknown field of an API object: change it to a similar field;
 * - unused variable: remove its declaration.
 */
class CodeActions {

    public static function quickFixes(a:Analysis, uri:String, diagnostics:Array<Dynamic>):Array<Dynamic> {
        final actions:Array<Dynamic> = [];
        for (d in diagnostics) {
            final code:Null<String> = d.code;
            final start = a.offsetAt(d.range.start);
            final end = a.offsetAt(d.range.end);
            final data:Dynamic = d.data;
            switch code {
                case 'unknown-identifier' if (data != null):
                    final name:String = data.name;
                    declareFixes(a, uri, d, name, start, actions);
                    final names = [for (s in a.visibleSymbols(start)) s.name];
                    for (g in a.api.globals) {
                        names.push(g.name);
                    }
                    similarFixes(a, uri, d, name, start, end, names, actions);
                case 'unknown-field' if (data != null):
                    final owner = a.api.get(data.owner);
                    if (owner != null && owner.fields != null) {
                        similarFixes(a, uri, d, data.name, start, end, [for (f in owner.fields) f.name], actions);
                    }
                case 'unused-variable' if (data != null):
                    removeFix(a, uri, d, data.name, start, actions);
                case _:
            }
        }
        return actions;
    }

    static function action(title:String, uri:String, diagnostic:Dynamic, edits:Array<Dynamic>, preferred:Bool):Dynamic {
        final changes:Dynamic = {};
        Reflect.setField(changes, uri, edits);
        return {title: title, kind: 'quickfix', diagnostics: [diagnostic], isPreferred: preferred, edit: {changes: changes}};
    }

    static function declareFixes(a:Analysis, uri:String, diagnostic:Dynamic, name:String, start:Int, actions:Array<Dynamic>):Void {
        final line = a.lineOf(start);
        final lineStart = a.lineStart(line);
        var indentEnd = lineStart;
        while (indentEnd < a.text.length && (StringTools.fastCodeAt(a.text, indentEnd) == ' '.code || StringTools.fastCodeAt(a.text, indentEnd) == '\t'.code)) {
            indentEnd++;
        }
        final indent = a.text.substring(lineStart, indentEnd);
        // `name = value` at the start of a statement: make it the declaration
        final rest = a.text.substring(start + name.length, a.lineEnd(line));
        if (start == indentEnd && ~/^\s*=[^=]/.match(rest)) {
            actions.push(action('Declare `$name` here (`var $name = ...`)', uri, diagnostic, [
                {range: a.rangeOf(start, start), newText: 'var '}
            ], true));
            return;
        }
        actions.push(action('Declare variable `$name`', uri, diagnostic, [
            {range: a.rangeOf(lineStart, lineStart), newText: indent + 'var $name = null;\n'}
        ], false));
    }

    static function similarFixes(a:Analysis, uri:String, diagnostic:Dynamic, name:String, start:Int, end:Int, candidates:Array<String>, actions:Array<Dynamic>):Void {
        final scored:Array<{name:String, distance:Int}> = [];
        final seen = new Map<String, Bool>();
        final limit = name.length <= 3 ? 1 : 2;
        for (candidate in candidates) {
            if (candidate == name || seen.exists(candidate)) {
                continue;
            }
            seen.set(candidate, true);
            final distance = levenshtein(name.toLowerCase(), candidate.toLowerCase());
            if (distance <= limit) {
                scored.push({name: candidate, distance: distance});
            }
        }
        scored.sort((x, y) -> x.distance != y.distance ? x.distance - y.distance : (x.name < y.name ? -1 : 1));
        var first = true;
        for (i in 0...(scored.length < 3 ? scored.length : 3)) {
            final candidate = scored[i].name;
            actions.push(action('Change to `$candidate`', uri, diagnostic, [
                {range: a.rangeOf(start, end), newText: candidate}
            ], first && !hasPreferred(actions)));
            first = false;
        }
    }

    static function hasPreferred(actions:Array<Dynamic>):Bool {
        for (action in actions) {
            if (action.isPreferred == true) {
                return true;
            }
        }
        return false;
    }

    static function removeFix(a:Analysis, uri:String, diagnostic:Dynamic, name:String, start:Int, actions:Array<Dynamic>):Void {
        var symbol:Null<Symbol> = null;
        for (s in a.symbols) {
            if (s.nameStart == start && s.name == name) {
                symbol = s;
                break;
            }
        }
        if (symbol == null || symbol.kind != SymbolKind.Variable) {
            return;
        }
        final text = a.text;
        var removeStart = symbol.declStart;
        var removeEnd = symbol.declEnd;
        // the `;` after the declaration
        var i = removeEnd;
        while (i < text.length && (StringTools.fastCodeAt(text, i) == ' '.code || StringTools.fastCodeAt(text, i) == '\t'.code)) {
            i++;
        }
        if (i < text.length && StringTools.fastCodeAt(text, i) == ';'.code) {
            removeEnd = i + 1;
        }
        // the whole lines when the declaration is alone on them
        final firstLine = a.lineOf(removeStart);
        final lastLine = a.lineOf(removeEnd);
        final before = text.substring(a.lineStart(firstLine), removeStart);
        final after = text.substring(removeEnd, a.lineEnd(lastLine));
        if (StringTools.trim(before) == '' && StringTools.trim(after) == '') {
            removeStart = a.lineStart(firstLine);
            removeEnd = lastLine + 1 < a.lineCount() ? a.lineStart(lastLine + 1) : a.lineEnd(lastLine);
        }
        actions.push(action('Remove unused variable `$name`', uri, diagnostic, [
            {range: a.rangeOf(removeStart, removeEnd), newText: ''}
        ], true));
    }

    public static function levenshtein(s:String, t:String):Int {
        final m = s.length;
        final n = t.length;
        var previous = [for (j in 0...n + 1) j];
        for (i in 1...m + 1) {
            final current = [i];
            for (j in 1...n + 1) {
                final cost = s.charCodeAt(i - 1) == t.charCodeAt(j - 1) ? 0 : 1;
                final a = previous[j] + 1;
                final b = current[j - 1] + 1;
                final c = previous[j - 1] + cost;
                current.push(a < b ? (a < c ? a : c) : (b < c ? b : c));
            }
            previous = current;
        }
        return previous[n];
    }

}
