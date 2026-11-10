package hscriptls.server;

import hscriptls.ScriptApi;

/**
 * An open document: its text, and its analysis computed when a request or
 * the diagnostics need it.
 */
private class Document {

    public final uri:String;
    public var text:String;
    public var version:Int;
    var analysis:Null<Analysis> = null;
    final api:ScriptApi;

    public function new(uri:String, text:String, version:Int, api:ScriptApi) {
        this.uri = uri;
        this.text = text;
        this.version = version;
        this.api = api;
    }

    public function update(text:String, version:Int):Void {
        this.text = text;
        this.version = version;
        analysis = null;
    }

    public function analyze():Analysis {
        if (analysis == null) {
            analysis = Analyzer.analyze(text, api);
        }
        return analysis;
    }

}

/**
 * A language server for hscript, in pure Haxe, speaking the Language
 * Server Protocol as JSON-RPC messages passed as anonymous structures (no
 * serialization): give it to Cityscape's `LspClient` through an
 * `InProcessTransport`, or wrap it in a stdio loop to use it from another
 * editor.
 *
 * It has the shape of Cityscape's `LspInProcessServer` (`handleMessage`
 * answers requests through `onResponse`, `onNotification` sends the
 * diagnostics) and implements it when the `cityscape` plugin is there; the
 * class itself depends only on hscript, so the tests run it without an
 * editor.
 *
 * Every feature works on an `Analysis` of the document (`Analyzer`):
 * diagnostics, completion, hover, signature help, definition, references,
 * document highlights, rename, document symbols, folding ranges, inlay
 * hints, code lenses, semantic tokens and quick fixes.
 */
class HscriptServer #if plugin_cityscape implements cityscape.lsp.LspInProcessServer #end {

    public var onNotification:Null<(notification:Dynamic) -> Void> = null;

    /**
     * Runs a callback later (`delay` in seconds). The diagnostics of a
     * document are published `diagnosticsDelay` seconds after its last
     * change when it is set (a host gives its timer), at once otherwise.
     */
    public var schedule:Null<(delay:Float, callback:() -> Void) -> Void> = null;

    public var diagnosticsDelay:Float = 0.25;

    public final api:ScriptApi;

    final documents:Map<String, Document> = new Map();

    /** The diagnostics waiting for their delay, by uri. */
    final pendingDiagnostics:Map<String, Int> = new Map();

    var publishGeneration:Int = 0;

    public function new(?api:ScriptApi) {
        this.api = api != null ? api : ScriptApi.drawing();
    }

    public static function capabilities():Dynamic {
        return {
            textDocumentSync: {openClose: true, change: 1},
            completionProvider: {triggerCharacters: ['.'], resolveProvider: false},
            hoverProvider: true,
            signatureHelpProvider: {triggerCharacters: ['(', ','], retriggerCharacters: [',']},
            definitionProvider: true,
            referencesProvider: true,
            documentHighlightProvider: true,
            documentSymbolProvider: true,
            codeActionProvider: {codeActionKinds: ['quickfix']},
            renameProvider: {prepareProvider: true},
            foldingRangeProvider: true,
            inlayHintProvider: true,
            codeLensProvider: {resolveProvider: false},
            semanticTokensProvider: {
                legend: {tokenTypes: LanguageFeatures.TOKEN_TYPES, tokenModifiers: LanguageFeatures.TOKEN_MODIFIERS},
                full: true
            }
        };
    }

    /**
     * The analysis of an open document (null when it is not open).
     */
    public function analysisOf(uri:String):Null<Analysis> {
        final doc = documents.get(uri);
        return doc != null ? doc.analyze() : null;
    }

    public function handleMessage(message:Dynamic, onResponse:(response:Dynamic) -> Void):Void {
        if (message == null || message.method == null) {
            // a response of the client: this server sends no request
            return;
        }
        final method:String = message.method;
        final id:Dynamic = message.id;
        final params:Dynamic = message.params;
        final isRequest = id != null;
        var result:Dynamic = null;
        try {
            switch method {
                case 'initialize':
                    result = {capabilities: capabilities(), serverInfo: {name: 'hscript-ls', version: '1.0.0'}};
                case 'initialized' | "$/cancelRequest" | "$/setTrace" | 'workspace/didChangeConfiguration':
                case 'shutdown':
                    result = null;
                case 'exit':
                    documents.clear();
                case 'textDocument/didOpen':
                    final td:Dynamic = params.textDocument;
                    documents.set(td.uri, new Document(td.uri, td.text, td.version, api));
                    publishDiagnostics(td.uri, true);
                case 'textDocument/didChange':
                    final doc = documents.get(params.textDocument.uri);
                    if (doc != null) {
                        final changes:Array<Dynamic> = params.contentChanges;
                        // full synchronization: the last change holds the text
                        if (changes != null && changes.length > 0) {
                            doc.update(changes[changes.length - 1].text, params.textDocument.version);
                        }
                        publishDiagnostics(doc.uri, false);
                    }
                case 'textDocument/didClose':
                    final uri:String = params.textDocument.uri;
                    documents.remove(uri);
                    pendingDiagnostics.remove(uri);
                    send({jsonrpc: '2.0', method: 'textDocument/publishDiagnostics', params: {uri: uri, diagnostics: []}});
                case _:
                    if (!isRequest) {
                        return;
                    }
                    final uri:Null<String> = params != null && params.textDocument != null ? params.textDocument.uri : null;
                    final doc = uri != null ? documents.get(uri) : null;
                    if (doc == null) {
                        onResponse({jsonrpc: '2.0', id: id, error: {code: -32601, message: 'Unhandled method $method'}});
                        return;
                    }
                    final a = doc.analyze();
                    final offset = params.position != null ? a.offsetAt(params.position) : 0;
                    switch method {
                        case 'textDocument/completion':
                            result = LanguageFeatures.completion(a, offset);
                        case 'textDocument/hover':
                            result = LanguageFeatures.hover(a, offset);
                        case 'textDocument/signatureHelp':
                            result = LanguageFeatures.signatureHelp(a, offset);
                        case 'textDocument/definition':
                            result = LanguageFeatures.definition(a, uri, offset);
                        case 'textDocument/references':
                            final includeDeclaration = params.context == null || params.context.includeDeclaration == true;
                            result = LanguageFeatures.references(a, uri, offset, includeDeclaration);
                        case 'textDocument/documentHighlight':
                            result = LanguageFeatures.documentHighlights(a, offset);
                        case 'textDocument/prepareRename':
                            result = LanguageFeatures.prepareRename(a, offset);
                        case 'textDocument/rename':
                            final answer = LanguageFeatures.rename(a, uri, offset, params.newName);
                            if (answer.error != null) {
                                onResponse({jsonrpc: '2.0', id: id, error: {code: -32803, message: answer.error}});
                                return;
                            }
                            result = answer.edit;
                        case 'textDocument/documentSymbol':
                            result = LanguageFeatures.documentSymbols(a);
                        case 'textDocument/foldingRange':
                            result = LanguageFeatures.foldingRanges(a);
                        case 'textDocument/inlayHint':
                            result = LanguageFeatures.inlayHints(a, a.offsetAt(params.range.start), a.offsetAt(params.range.end));
                        case 'textDocument/codeLens':
                            result = LanguageFeatures.codeLenses(a, uri);
                        case 'textDocument/semanticTokens/full':
                            result = {data: LanguageFeatures.semanticTokens(a)};
                        case 'textDocument/codeAction':
                            final diagnostics:Array<Dynamic> = params.context != null && params.context.diagnostics != null ? params.context.diagnostics : [];
                            result = CodeActions.quickFixes(a, uri, diagnostics);
                        case _:
                            onResponse({jsonrpc: '2.0', id: id, error: {code: -32601, message: 'Unhandled method $method'}});
                            return;
                    }
            }
        }
        catch (e:Dynamic) {
            if (isRequest) {
                onResponse({jsonrpc: '2.0', id: id, error: {code: -32603, message: 'hscript-ls: ' + Std.string(e)}});
            }
            return;
        }
        if (isRequest) {
            onResponse({jsonrpc: '2.0', id: id, result: result});
        }
    }

    function send(notification:Dynamic):Void {
        final listener = onNotification;
        if (listener != null) {
            listener(notification);
        }
    }

    /**
     * Publishes the diagnostics of a document, after `diagnosticsDelay`
     * when a scheduler is set (only the last change of a burst of typing
     * is analyzed), unless `now`.
     */
    function publishDiagnostics(uri:String, now:Bool):Void {
        final run = () -> {
            pendingDiagnostics.remove(uri);
            final doc = documents.get(uri);
            if (doc == null) {
                return;
            }
            final a = doc.analyze();
            send({jsonrpc: '2.0', method: 'textDocument/publishDiagnostics', params: {
                uri: uri,
                version: doc.version,
                diagnostics: [for (d in a.diagnostics) toLspDiagnostic(a, uri, d)]
            }});
        };
        if (now || schedule == null) {
            run();
            return;
        }
        final generation = ++publishGeneration;
        pendingDiagnostics.set(uri, generation);
        schedule(diagnosticsDelay, () -> {
            if (pendingDiagnostics.get(uri) == generation) {
                run();
            }
        });
    }

    static function toLspDiagnostic(a:Analysis, uri:String, d:hscriptls.server.Analysis.Diagnostic):Dynamic {
        final result:Dynamic = {
            range: a.rangeOf(d.start, d.end),
            severity: d.severity,
            code: d.code,
            source: 'hscript',
            message: d.message
        };
        if (d.tags != null) {
            result.tags = d.tags;
        }
        if (d.data != null) {
            result.data = d.data;
        }
        if (d.related != null) {
            result.relatedInformation = [for (r in d.related) {location: {uri: uri, range: a.rangeOf(r.start, r.end)}, message: r.message}];
        }
        return result;
    }

}
