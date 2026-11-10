package;

import hscriptls.ScriptApi;
import hscriptls.server.Analysis;
import hscriptls.server.Analyzer;
import hscriptls.server.HscriptServer;

/**
 * Tests of the analyzer and of the server's answers. Positions are found
 * with markers in the texts (`at(text, 'turtle.fly', 7)`: the offset 7
 * characters after the start of `turtle.fly`), never hard-coded.
 */
class AnalyzerTests {

    static var failures = 0;
    static var passed = 0;
    static var current = '';

    public static function run():Int {
        final tests:Array<{name:String, run:() -> Void}> = [
            {name: 'parse error range', run: testParseError},
            {name: 'clean script', run: testCleanScript},
            {name: 'unknown identifiers', run: testUnknownIdentifiers},
            {name: 'unused variables', run: testUnused},
            {name: 'duplicate declarations', run: testDuplicates},
            {name: 'argument counts', run: testArgumentCounts},
            {name: 'hscript scoping rules', run: testScopingRules},
            {name: 'completion', run: testCompletion},
            {name: 'completion after a dot', run: testMemberCompletion},
            {name: 'hover', run: testHover},
            {name: 'signature help', run: testSignatureHelp},
            {name: 'definition and references', run: testReferences},
            {name: 'rename', run: testRename},
            {name: 'document symbols', run: testDocumentSymbols},
            {name: 'inlay hints and code lenses', run: testInlayHintsAndLenses},
            {name: 'semantic tokens', run: testSemanticTokens},
            {name: 'folding ranges', run: testFolding},
            {name: 'quick fixes', run: testQuickFixes},
            {name: 'server protocol', run: testServer},
            {name: 'example scripts', run: testExamples}
        ];
        for (test in tests) {
            current = test.name;
            try {
                test.run();
            }
            catch (e:Dynamic) {
                fail('threw ' + Std.string(e) + '\n' + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            }
        }
        println('hscript-ls tests: $passed passed, $failures failed');
        return failures;
    }

    //#region helpers

    static function println(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

    static function fail(message:String, ?pos:haxe.PosInfos):Void {
        failures++;
        println('FAIL [$current] line ${pos.lineNumber}: $message');
    }

    static function check(condition:Bool, message:String, ?pos:haxe.PosInfos):Void {
        if (condition) {
            passed++;
        }
        else {
            fail(message, pos);
        }
    }

    static function equals<T>(expected:T, actual:T, message:String, ?pos:haxe.PosInfos):Void {
        check(expected == actual, '$message: expected $expected, got $actual', pos);
    }

    static function at(text:String, marker:String, delta:Int = 0):Int {
        final index = text.indexOf(marker);
        if (index < 0) {
            throw 'marker not found: $marker';
        }
        return index + delta;
    }

    static final api = ScriptApi.drawing();

    static function analyze(lines:Array<String>):Analysis {
        return Analyzer.analyze(lines.join('\n'), api);
    }

    static function codes(a:Analysis):Array<String> {
        return [for (d in a.diagnostics) d.code];
    }

    static function diagnostic(a:Analysis, code:String, ?from:Int = 0):Null<Diagnostic> {
        for (d in a.diagnostics) {
            if (d.code == code && d.start >= from) {
                return d;
            }
        }
        return null;
    }

    static function labels(items:Array<Dynamic>):Array<String> {
        return [for (item in items) item.label];
    }

    //#endregion

    static function testParseError():Void {
        final a = analyze(['var x = 1;', 'var y = (x + ;', 'print(y);']);
        final d = diagnostic(a, 'parse-error');
        check(d != null, 'a parse error is reported');
        check(!a.parsed, 'the script is marked as not parsed');
        equals(at(a.text, '+ ;', 2), d.start, 'the error starts at the unexpected token');
        equals(at(a.text, '+ ;', 3), d.end, 'the error ends after it');
        equals('Unexpected `;`', d.message, 'message');
        equals(1, a.diagnostics.length, 'only the parse error while the script does not parse');

        final b = analyze(['var s = "abc', 'print(s);']);
        final u = diagnostic(b, 'parse-error');
        check(u != null && u.message == 'Unterminated string', 'unterminated string');

        final c = analyze(['function f() {', '  print(1);']);
        final eof = diagnostic(c, 'parse-error');
        check(eof != null && eof.message == 'Unexpected end of script', 'unexpected end: ' + (eof != null ? eof.message : 'none'));
        check(eof != null && eof.end <= c.text.length && eof.end > eof.start, 'the end of script error is a non empty range inside the text');
    }

    static function testCleanScript():Void {
        final a = analyze([
            'var count = 5;',
            'function star(size, color) {',
            '  turtle.penColor(color);',
            '  for (i in 0...5) {',
            '    turtle.forward(size);',
            '    turtle.turn(144);',
            '  }',
            '}',
            'for (k in 0...count) star(random(20, 60), hsl(k * 30, 0.8, 0.6));',
            'var m = ["a" => 1];',
            'var o = {x: 1, y: 2};',
            'print(m.get("a") + o.x + Math.PI + WIDTH);',
            'trace("done");'
        ]);
        equals(0, a.diagnostics.length, 'no diagnostic: ' + [for (d in a.diagnostics) d.message].join(' | '));
        check(a.parsed, 'parsed');
    }

    static function testUnknownIdentifiers():Void {
        final a = analyze(['var size = 3;', 'pirnt(sise);', 'turtle.fly(2);']);
        final d1 = diagnostic(a, 'unknown-identifier');
        check(d1 != null && d1.message == 'Unknown identifier `pirnt`.', 'pirnt is unknown');
        equals(at(a.text, 'pirnt'), d1.start, 'range start of pirnt');
        equals(at(a.text, 'pirnt', 5), d1.end, 'range end of pirnt');
        final d2 = diagnostic(a, 'unknown-identifier', d1.end);
        check(d2 != null && d2.data.name == 'sise', 'sise is unknown');
        final field = diagnostic(a, 'unknown-field');
        check(field != null && field.message == '`turtle` has no field `fly`.', 'fly is not a field of turtle');
        equals(at(a.text, 'fly'), field.start, 'range start of the field');
        equals(at(a.text, 'fly', 3), field.end, 'range end of the field');
        equals(1, a.diagnostics.filter(d -> d.severity == 1 && d.code == 'unknown-field').length, 'one unknown field');
    }

    static function testUnused():Void {
        final a = analyze([
            'var used = 1;',
            'var unused = 2;',
            'var written = 0;',
            'written = 4;',
            'function f(a, _b, c) {',
            '  function helper() {}',
            '  return a + used;',
            '}',
            'f(1, 2, 3);'
        ]);
        final unused = a.diagnostics.filter(d -> d.code == 'unused-variable');
        equals(2, unused.length, 'two unused variables');
        equals('`unused` is declared but never used.', unused[0].message, 'unused message');
        equals('`written` is assigned but its value is never read.', unused[1].message, 'written message');
        check(unused[0].tags != null && unused[0].tags[0] == 1, 'tagged unnecessary');
        equals(4, unused[0].severity, 'hint severity');
        final params = a.diagnostics.filter(d -> d.code == 'unused-parameter');
        equals(1, params.length, 'one unused parameter (c; _b is ignored)');
        equals(at(a.text, 'c)'), params[0].start, 'c is the unused parameter');
        check(diagnostic(a, 'unused-function') != null, 'the local function is never called');
    }

    static function testDuplicates():Void {
        final a = analyze(['var x = 1;', 'var x = 2;', 'function g(p, p) { print(p); }', 'g(1, 2);', 'print(x);', 'var print = 3;']);
        final dup = a.diagnostics.filter(d -> d.code == 'duplicate-declaration');
        equals(2, dup.length, 'a duplicate variable and a duplicate parameter');
        equals(2, dup[0].severity, 'duplicate variable is a warning');
        check(dup[0].related != null && dup[0].related[0].start == at(a.text, 'x = 1'), 'related information points at the first declaration');
        equals(1, dup[1].severity, 'duplicate parameter is an error');
        check(diagnostic(a, 'shadowed-global') != null, 'var print hides the API function');
    }

    static function testArgumentCounts():Void {
        final a = analyze([
            'circle(10, 20, 5);',
            'line(0, 0, 10, 10, 0xffffff);',
            'line(0, 0, 10, 10, 0xffffff, 3, 4);',
            'turtle.forward();',
            'function two(a, b) { return a + b; }',
            'two(1);',
            'two(1, 2, 3);',
            'var add = (x, y) -> x + y;',
            'add(1);'
        ]);
        final counts = a.diagnostics.filter(d -> d.code == 'argument-count');
        equals(6, counts.length, 'argument count problems: ' + [for (d in counts) d.message].join(' | '));
        equals('`circle` expects 4 arguments, got 3.', counts[0].message, 'circle');
        equals('`line` expects from 5 to 6 arguments, got 7.', counts[1].message, 'line, too many');
        equals(at(a.text, '4);'), counts[1].start, 'the extra argument is underlined');
        equals('`turtle.forward` expects 1 argument, got 0.', counts[2].message, 'turtle.forward');
        equals('`two` expects 2 arguments, got 1.', counts[3].message, 'two, missing');
        equals(1, counts[3].severity, 'missing arguments of script functions fail at runtime');
        equals(2, counts[4].severity, 'extra arguments of script functions are ignored: a warning');
        equals('`add` expects 2 arguments, got 1.', counts[5].message, 'a variable holding a function');
    }

    static function testScopingRules():Void {
        final a = analyze([
            'early();',
            'function early() { return later; }',
            'var later = 1;',
            'function ok() { return early(); }',
            'ok();',
            'function opt(a, size = 2) { return a + size; }',
            'opt(1);',
            'break;',
            'for (i in 0...3) { if (i > 1) break; }',
            'print(i);'
        ]);
        final before = diagnostic(a, 'used-before-declaration');
        check(before != null && before.start == 0, 'calling a top level function before its declaration');
        final later = diagnostic(a, 'unknown-identifier');
        check(later != null && later.message.indexOf('declared after this function') >= 0, 'a function does not see the variables declared after it');
        check(diagnostic(a, 'ignored-default') != null, 'default values are ignored by hscript');
        final outside = a.diagnostics.filter(d -> d.code == 'outside-loop');
        equals(1, outside.length, 'one break outside a loop');
        final unknownI = a.diagnostics.filter(d -> d.code == 'unknown-identifier' && d.data.name == 'i');
        equals(1, unknownI.length, 'the loop variable is not visible after the loop');
    }

    static function testCompletion():Void {
        final text = ['var speed = 3;', 'function walk(steps) {', '  var local = 1;', '  ', '}', 'var after = 2;'].join('\n');
        final a = Analyzer.analyze(text, api);
        final inside = at(text, '  \n}', 2);
        final items:Array<Dynamic> = hscriptls.server.LanguageFeatures.completion(a, inside).items;
        final names = labels(items);
        check(names.indexOf('speed') >= 0, 'top level variable declared before');
        check(names.indexOf('steps') >= 0, 'parameter');
        check(names.indexOf('local') >= 0, 'local variable');
        check(names.indexOf('walk') >= 0, 'the function itself');
        check(names.indexOf('after') < 0, 'not a variable declared after the function');
        check(names.indexOf('circle') >= 0, 'API function');
        check(names.indexOf('turtle') >= 0, 'API object');
        check(names.indexOf('while') >= 0, 'keyword');
        var snippet:Dynamic = null;
        for (item in items) {
            if (item.label == 'for' && item.kind == 15) {
                snippet = item;
            }
        }
        check(snippet != null && snippet.insertTextFormat == 2 && snippet.insertText.indexOf("${1:i}") >= 0, 'for snippet');
        var circle:Dynamic = null;
        for (item in items) {
            if (item.label == 'circle') {
                circle = item;
            }
        }
        equals('circle(x:Float, y:Float, radius:Float, color:Color):Void', circle.detail, 'API signature as detail');
        check(circle.documentation.value.indexOf('Draws a filled circle.') == 0, 'API documentation');
        // nothing in comments and strings
        final b = Analyzer.analyze('// pri\nprint("ci");', api);
        equals(0, hscriptls.server.LanguageFeatures.completion(b, 6).items.length, 'no completion in a comment');
        equals(0, hscriptls.server.LanguageFeatures.completion(b, at(b.text, 'ci"', 2)).items.length, 'no completion in a string');
    }

    static function testMemberCompletion():Void {
        final text = 'var name = "x";\nvar list = [1, 2];\nvar point = {x: 1, y: 2};\nturtle.\nname.\nlist.\npoint.\nMath.';
        final a = Analyzer.analyze(text, api);
        check(!a.parsed, 'the text does not parse');
        function members(marker:String):Array<String> {
            return labels(hscriptls.server.LanguageFeatures.completion(a, at(text, marker, marker.length)).items);
        }
        final t = members('turtle.');
        check(t.indexOf('forward') >= 0 && t.indexOf('penColor') >= 0 && t.indexOf('x') >= 0, 'turtle fields: ' + t.join(','));
        check(t.indexOf('circle') < 0, 'only the fields after a dot');
        check(members('name.').indexOf('toUpperCase') >= 0, 'string methods');
        check(members('list.').indexOf('push') >= 0, 'array methods');
        final p = members('point.');
        check(p.length == 2 && p.indexOf('y') >= 0, 'object literal fields');
        check(members('Math.').indexOf('sqrt') >= 0, 'Math');
        equals(0, hscriptls.server.LanguageFeatures.completion(Analyzer.analyze('for (i in 0...', api), 14).items.length, 'no member completion after a range');
    }

    static function testHover():Void {
        final text = ['/** How many sides. */', 'var sides = 6;', 'function poly(n) { return n * sides; }', 'circle(1, 2, 3, poly(2));', 'turtle.forward(1);'].join('\n');
        final a = Analyzer.analyze(text, api);
        final h1:Dynamic = hscriptls.server.LanguageFeatures.hover(a, at(text, 'sides;', 1));
        check(h1 != null && h1.contents.value.indexOf('var sides:Int') >= 0, 'variable with its inferred type');
        check(h1.contents.value.indexOf('How many sides.') >= 0, 'doc comment');
        final h2:Dynamic = hscriptls.server.LanguageFeatures.hover(a, at(text, 'circle'));
        check(h2 != null && h2.contents.value.indexOf('circle(x:Float') >= 0 && h2.contents.value.indexOf('Runtime API') >= 0, 'API function');
        final h3:Dynamic = hscriptls.server.LanguageFeatures.hover(a, at(text, 'n *'));
        check(h3 != null && h3.contents.value.indexOf('(parameter) n') >= 0 && h3.contents.value.indexOf('poly') >= 0, 'parameter of poly');
        final h4:Dynamic = hscriptls.server.LanguageFeatures.hover(a, at(text, 'forward', 2));
        check(h4 != null && h4.contents.value.indexOf('turtle.forward(distance:Float)') >= 0, 'API object method');
        equals(at(text, 'forward'), a.offsetAt(h4.range.start), 'hover range of the field');
    }

    static function testSignatureHelp():Void {
        final text = 'function tri(a, b, c) {}\nline(1, 2, ';
        final a = Analyzer.analyze(text, api);
        final help:Dynamic = hscriptls.server.LanguageFeatures.signatureHelp(a, text.length);
        check(help != null, 'signature help in an unfinished call');
        equals(2, help.activeParameter, 'third parameter');
        final signature:Dynamic = help.signatures[0];
        equals('line(x1:Float, y1:Float, x2:Float, y2:Float, color:Color, ?thickness:Float):Void', signature.label, 'label');
        final range:Array<Int> = signature.parameters[2].label;
        equals('x2:Float', signature.label.substring(range[0], range[1]), 'parameter label offsets');
        final text2 = 'function tri(a, b, c) {}\ntri(1, [2, 3], ';
        final help2:Dynamic = hscriptls.server.LanguageFeatures.signatureHelp(Analyzer.analyze(text2, api), text2.length);
        equals('tri(a, b, c)', help2.signatures[0].label, 'script function');
        equals(2, help2.activeParameter, 'commas inside brackets are skipped');
        final text3 = 'turtle.goTo(';
        final help3:Dynamic = hscriptls.server.LanguageFeatures.signatureHelp(Analyzer.analyze(text3, api), text3.length);
        check(help3 != null && help3.signatures[0].label.indexOf('turtle.goTo(x:Float, y:Float)') == 0, 'method of an API object');
    }

    static function testReferences():Void {
        final text = 'var total = 0;\nfor (i in 0...3) total += i;\nprint(total);';
        final a = Analyzer.analyze(text, api);
        final def:Dynamic = hscriptls.server.LanguageFeatures.definition(a, 'file:///t', at(text, 'total)', 2));
        equals(at(text, 'total'), a.offsetAt(def.range.start), 'definition of total');
        final refs = hscriptls.server.LanguageFeatures.references(a, 'file:///t', at(text, 'total +='), true);
        equals(3, refs.length, 'three references with the declaration');
        equals(2, hscriptls.server.LanguageFeatures.references(a, 'file:///t', 4, false).length, 'two without');
        final highlights = hscriptls.server.LanguageFeatures.documentHighlights(a, 4);
        equals(3, highlights.length, 'highlights');
        equals(3, highlights[1].kind, '+= writes');
        equals(2, highlights[2].kind, 'print reads');
        check(hscriptls.server.LanguageFeatures.definition(a, 'file:///t', at(text, 'print')) == null, 'no definition for the API');
    }

    static function testRename():Void {
        final text = 'var size = 1;\nfunction grow(size) { return size * 2; }\nprint(grow(size));';
        final a = Analyzer.analyze(text, api);
        final prepare:Dynamic = hscriptls.server.LanguageFeatures.prepareRename(a, at(text, 'size * 2'));
        check(prepare != null && prepare.placeholder == 'size', 'prepare rename of a parameter');
        check(hscriptls.server.LanguageFeatures.prepareRename(a, at(text, 'print')) == null, 'the API cannot be renamed');
        final answer = hscriptls.server.LanguageFeatures.rename(a, 'file:///t', at(text, 'size * 2'), 'amount');
        final edits:Array<Dynamic> = Reflect.field(answer.edit.changes, 'file:///t');
        equals(2, edits.length, 'the parameter and its use, not the top level variable');
        equals(at(text, 'size)'), a.offsetAt(edits[0].range.start), 'first edit on the parameter');
        final top = hscriptls.server.LanguageFeatures.rename(a, 'file:///t', 5, 'scale');
        equals(2, (Reflect.field(top.edit.changes, 'file:///t') : Array<Dynamic>).length, 'top level variable: declaration and the last line');
        check(hscriptls.server.LanguageFeatures.rename(a, 'file:///t', 5, 'for').error != null, 'a keyword is refused');
        check(hscriptls.server.LanguageFeatures.rename(a, 'file:///t', 5, '2x').error != null, 'an invalid name is refused');
    }

    static function testDocumentSymbols():Void {
        final text = 'var a = 1;\nfunction outer(p) {\n  var inner = p;\n  function nested() { return inner; }\n  return nested();\n}\nouter(a);';
        final a = Analyzer.analyze(text, api);
        final symbols = hscriptls.server.LanguageFeatures.documentSymbols(a);
        equals(2, symbols.length, 'two top level symbols');
        equals('outer', symbols[1].name, 'the function');
        equals(12, symbols[1].kind, 'Function kind');
        final children:Array<Dynamic> = symbols[1].children;
        equals(2, children.length, 'inner and nested');
        equals(5, symbols[1].range.end.line, 'the range covers the body, up to its closing brace');
    }

    static function testInlayHintsAndLenses():Void {
        final text = 'var x = 3;\nfunction main() {\n  circle(x, 20, 5, 0xff0000);\n}\nfunction size(n) { return n; }\nmain();\nprint(size(1));';
        final a = Analyzer.analyze(text, api);
        final hints = hscriptls.server.LanguageFeatures.inlayHints(a, 0, text.length);
        final hintLabels:Array<String> = [for (h in hints) h.label];
        equals('y:,radius:,color:,n:', hintLabels.join(','), 'parameter hints (x is named like its parameter, print says enough)');
        final unary = Analyzer.analyze('turtle.turn(-spread);\nvar spread = 1;', api);
        final unaryHints = hscriptls.server.LanguageFeatures.inlayHints(unary, 0, unary.text.length);
        equals(12, unaryHints[0].position.character, 'the hint goes before the minus sign of a prefix operation');
        final lenses = hscriptls.server.LanguageFeatures.codeLenses(a, 'file:///t');
        final titles:Array<String> = [for (l in lenses) l.command.title];
        equals("$(play) Run main(),1 reference,1 reference", titles.join(','), 'lenses');
        equals('hscript.runFunction', lenses[0].command.command, 'run command');
    }

    static function testSemanticTokens():Void {
        final text = 'var r = 2;\ncircle(r, r, r, 0);\nturtle.forward(WIDTH);';
        final a = Analyzer.analyze(text, api);
        final data = hscriptls.server.LanguageFeatures.semanticTokens(a);
        equals(0, data.length % 5, 'groups of five');
        // r (declaration), circle, r, r, r, turtle, forward, WIDTH
        equals(8 * 5, data.length, 'eight tokens');
        equals(0, data[3], 'r is a variable');
        equals(1, data[4], 'declaration modifier');
        equals(2, data[5 + 3], 'circle is a function');
        equals(4, data[5 + 4], 'defaultLibrary');
        equals(4, data[25 + 3], 'turtle is a class');
        equals(3, data[30 + 3], 'forward is a method');
        equals(0, data[35 + 3], 'WIDTH is a variable');
        equals(6, data[35 + 4], 'readonly and defaultLibrary');
    }

    static function testFolding():Void {
        final text = '/*\n doc\n*/\nfunction f() {\n  var o = {\n    a: 1\n  };\n}\n// #region things\nprint(1);\n// #endregion';
        final ranges = hscriptls.server.LanguageFeatures.foldingRanges(Analyzer.analyze(text, api));
        final found = [for (r in ranges) r.startLine + '-' + r.endLine + (r.kind != null ? ':' + r.kind : '')];
        check(found.indexOf('3-6') >= 0, 'function body: ' + found.join(' '));
        check(found.indexOf('4-5') >= 0, 'object literal');
        check(found.indexOf('0-2:comment') >= 0, 'block comment');
        check(found.indexOf('8-10:region') >= 0, 'region');
        check(hscriptls.server.LanguageFeatures.foldingRanges(Analyzer.analyze('function f() {', api)) == null, 'none when the script does not parse');
    }

    static function testQuickFixes():Void {
        final text = 'var radius = 3;\nprint(radus + radius);\ncount = 2;\nvar unused = 1;\nturtle.forwad(1);';
        final server = new HscriptServer(api);
        final uri = 'file:///fix.hscript';
        var published:Array<Dynamic> = null;
        server.onNotification = n -> published = n.params.diagnostics;
        server.handleMessage({jsonrpc: '2.0', method: 'textDocument/didOpen', params: {textDocument: {uri: uri, languageId: 'hscript', version: 1, text: text}}}, _ -> {});
        check(published != null, 'diagnostics published on open');
        function fixes(code:String):Array<Dynamic> {
            var result:Array<Dynamic> = null;
            for (d in published) {
                if (d.code == code && result == null) {
                    server.handleMessage({jsonrpc: '2.0', id: 1, method: 'textDocument/codeAction', params: {
                        textDocument: {uri: uri}, range: d.range, context: {diagnostics: [d]}
                    }}, r -> result = r.result);
                }
            }
            return result;
        }
        final unknown = fixes('unknown-identifier');
        final titles = [for (f in unknown) (f.title : String)];
        check(titles.indexOf('Declare variable `radus`') >= 0, 'declare: ' + titles.join(' | '));
        check(titles.indexOf('Change to `radius`') >= 0, 'did you mean');
        var change:Dynamic = null;
        for (f in unknown) {
            if (f.title == 'Change to `radius`') {
                change = f;
            }
        }
        check(change.isPreferred == true, 'the similar name is preferred');
        final edit:Dynamic = (Reflect.field(change.edit.changes, uri) : Array<Dynamic>)[0];
        equals('radius', edit.newText, 'replacement');
        // `count = 2` becomes the declaration
        var assignFix:Dynamic = null;
        for (d in published) {
            if (d.code == 'unknown-identifier' && d.data.name == 'count') {
                server.handleMessage({jsonrpc: '2.0', id: 2, method: 'textDocument/codeAction', params: {textDocument: {uri: uri}, range: d.range, context: {diagnostics: [d]}}}, r -> assignFix = r.result[0]);
            }
        }
        check(assignFix != null && (Reflect.field(assignFix.edit.changes, uri) : Array<Dynamic>)[0].newText == 'var ', 'var before an assignment');
        final remove = fixes('unused-variable');
        equals(1, remove.length, 'remove unused');
        final removeEdit:Dynamic = (Reflect.field(remove[0].edit.changes, uri) : Array<Dynamic>)[0];
        equals(3, removeEdit.range.start.line, 'the whole line');
        equals(0, removeEdit.range.start.character, 'from its start');
        equals(4, removeEdit.range.end.line, 'to the next line');
        final field = fixes('unknown-field');
        check(field.length == 1 && field[0].title == 'Change to `forward`', 'field fix');
    }

    static function testServer():Void {
        final server = new HscriptServer(api);
        var initialize:Dynamic = null;
        server.handleMessage({jsonrpc: '2.0', id: 1, method: 'initialize', params: {capabilities: {}}}, r -> initialize = r);
        check(initialize != null && initialize.id == 1 && initialize.result.capabilities.hoverProvider == true, 'initialize');
        check(initialize.result.capabilities.semanticTokensProvider.legend.tokenTypes.length == 6, 'semantic legend');
        // delayed diagnostics: only the last change of a burst
        final queue:Array<() -> Void> = [];
        server.schedule = (_, callback) -> queue.push(callback);
        final notifications:Array<Dynamic> = [];
        server.onNotification = n -> notifications.push(n);
        final uri = 'file:///s.hscript';
        server.handleMessage({jsonrpc: '2.0', method: 'textDocument/didOpen', params: {textDocument: {uri: uri, languageId: 'hscript', version: 1, text: 'print(1);'}}}, _ -> {});
        equals(1, notifications.length, 'diagnostics at once on open');
        server.handleMessage({jsonrpc: '2.0', method: 'textDocument/didChange', params: {textDocument: {uri: uri, version: 2}, contentChanges: [{text: 'print(x'}]}}, _ -> {});
        server.handleMessage({jsonrpc: '2.0', method: 'textDocument/didChange', params: {textDocument: {uri: uri, version: 3}, contentChanges: [{text: 'print(x);'}]}}, _ -> {});
        equals(1, notifications.length, 'nothing before the delay');
        for (callback in queue) {
            callback();
        }
        equals(2, notifications.length, 'one publication for the burst');
        final last:Dynamic = notifications[1].params;
        equals(3, last.version, 'of the last version');
        equals('unknown-identifier', last.diagnostics[0].code, 'x is unknown');
        var hover:Dynamic = null;
        server.handleMessage({jsonrpc: '2.0', id: 7, method: 'textDocument/hover', params: {textDocument: {uri: uri}, position: {line: 0, character: 2}}}, r -> hover = r);
        check(hover.id == 7 && hover.result.contents.value.indexOf('print(value:Dynamic)') >= 0, 'hover answer');
        var error:Dynamic = null;
        server.handleMessage({jsonrpc: '2.0', id: 8, method: 'textDocument/rename', params: {textDocument: {uri: uri}, position: {line: 0, character: 2}, newName: 'y'}}, r -> error = r);
        check(error.error != null && error.error.code == -32803, 'rename of the API is refused with an error');
        var prepare:Dynamic = null;
        server.handleMessage({jsonrpc: '2.0', id: 10, method: 'textDocument/prepareRename', params: {textDocument: {uri: uri}, position: {line: 0, character: 2}}}, r -> prepare = r);
        check(prepare.error != null && prepare.error.message == 'Only the names declared in the script can be renamed.', 'prepareRename of the API is refused with a message');
        var unknown:Dynamic = null;
        server.handleMessage({jsonrpc: '2.0', id: 9, method: 'workspace/symbol', params: {query: ''}}, r -> unknown = r);
        check(unknown.error != null && unknown.error.code == -32601, 'unknown methods get MethodNotFound');
        server.handleMessage({jsonrpc: '2.0', method: 'textDocument/didClose', params: {textDocument: {uri: uri}}}, _ -> {});
        equals(0, (notifications[notifications.length - 1].params.diagnostics : Array<Dynamic>).length, 'diagnostics cleared on close');
    }

    static function testExamples():Void {
        for (example in Examples.all()) {
            final a = Analyzer.analyze(example.code, api);
            final problems = [for (d in a.diagnostics) if (d.severity <= 2 && example.name != 'Mistakes') d.message];
            check(problems.length == 0, example.name + ' has no error or warning: ' + problems.join(' | '));
            check(a.parsed, example.name + ' parses');
            if (example.name == 'Mistakes') {
                final found = [for (d in a.diagnostics) d.code + ':' + a.text.substring(d.start, d.end)];
                for (expected in ['unused-variable:forgotten', 'argument-count:circle(200 + Math.cos(angle) * size, 200 + Math.sin(angle) * size, radius / 2)',
                    'unknown-identifier:raduis', 'unknown-field:forwad', 'unknown-identifier:count']) {
                    check(found.indexOf(expected) >= 0, 'Mistakes reports ' + expected + ' in ' + found.join(', '));
                }
            }
        }
    }

}
