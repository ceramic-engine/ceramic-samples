package hscriptls;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.lsp.LspClient;
import cityscape.lsp.LspConversions;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;

/**
 * The providers of the LSP features that Cityscape's `LspClient` does not
 * register by itself (it registers completion, hover, definition, document
 * symbols, code actions, signature help and formatting): references,
 * document highlights, rename, folding ranges, inlay hints, code lenses and
 * semantic tokens. Each one sends the LSP request with
 * `client.sendCancellableRequest` and converts the answer to Monaco's
 * types, like the client's own providers.
 */
class HscriptProviders {

    /**
     * Registers the providers for the client's languages; the returned
     * disposable unregisters them.
     */
    public static function register(client:LspClient):IDisposable {
        final context = client.context;
        final selector = client.languageSelector();
        final store = new DisposableStore();
        final caps:Dynamic = client.serverCapabilities;
        if (caps.referencesProvider != null) {
            store.add(context.registerReferenceProvider(selector, new References(client)));
        }
        if (caps.documentHighlightProvider != null) {
            store.add(context.registerDocumentHighlightProvider(selector, new Highlights(client)));
        }
        if (caps.renameProvider != null) {
            store.add(context.registerRenameProvider(selector, new Rename(client)));
        }
        if (caps.foldingRangeProvider != null) {
            store.add(context.registerFoldingRangeProvider(selector, new Folding(client)));
        }
        if (caps.inlayHintProvider != null) {
            store.add(context.registerInlayHintsProvider(selector, new InlayHints(client)));
        }
        if (caps.codeLensProvider != null) {
            store.add(context.registerCodeLensProvider(selector, new CodeLenses(client)));
        }
        if (caps.semanticTokensProvider != null) {
            final legend:Dynamic = caps.semanticTokensProvider.legend;
            store.add(context.registerDocumentSemanticTokensProvider(selector, new Semantic(client, {tokenTypes: legend.tokenTypes, tokenModifiers: legend.tokenModifiers})));
        }
        return store;
    }

    public static function textDocumentPosition(client:LspClient, model:ITextModel, position:Position):Dynamic {
        client.syncModel(model);
        return {textDocument: client.textDocumentIdentifier(model), position: LspConversions.toLspPosition(position)};
    }

    public static function toLocation(location:Dynamic):Location {
        return {uri: Uri.parse(location.uri), range: LspConversions.fromLspRange(location.range)};
    }

}

private class References implements ReferenceProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void {
        final params:Dynamic = HscriptProviders.textDocumentPosition(client, model, position);
        params.context = {includeDeclaration: context.includeDeclaration};
        client.sendCancellableRequest('textDocument/references', params, token, (result, error) -> {
            final list = LspConversions.asArray(result);
            resolve(error != null || list == null ? null : [for (l in list) HscriptProviders.toLocation(l)]);
        });
    }

}

private class Highlights implements DocumentHighlightProvider {

    final client:LspClient;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideDocumentHighlights(model:ITextModel, position:Position, token:CancellationToken, resolve:(highlights:Null<Array<DocumentHighlight>>) -> Void):Void {
        client.sendCancellableRequest('textDocument/documentHighlight', HscriptProviders.textDocumentPosition(client, model, position), token, (result, error) -> {
            final list = LspConversions.asArray(result);
            if (error != null || list == null) {
                resolve(null);
                return;
            }
            // LSP kinds start at 1 (Text), Monaco's at 0
            resolve([for (h in list) {range: LspConversions.fromLspRange(h.range), kind: (LspConversions.asInt(h.kind, 1) - 1 : DocumentHighlightKind)}]);
        });
    }

}

private class Rename implements RenameProvider {

    final client:LspClient;

    public var resolveRenameLocation(default, null):Null<(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void>;

    public function new(client:LspClient) {
        this.client = client;
        resolveRenameLocation = prepare;
    }

    function prepare(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void):Void {
        client.sendCancellableRequest('textDocument/prepareRename', HscriptProviders.textDocumentPosition(client, model, position), token, (result, error) -> {
            if (error != null || result == null) {
                resolve({range: Range.fromPositions(position), text: '', rejectReason: 'Only the names declared in the script can be renamed.'});
                return;
            }
            resolve({range: LspConversions.fromLspRange(result.range), text: result.placeholder});
        });
    }

    public function provideRenameEdits(model:ITextModel, position:Position, newName:String, token:CancellationToken, resolve:(edit:Null<WorkspaceEditAndRejection>) -> Void):Void {
        final params:Dynamic = HscriptProviders.textDocumentPosition(client, model, position);
        params.newName = newName;
        client.sendCancellableRequest('textDocument/rename', params, token, (result, error) -> {
            if (error != null) {
                resolve({edits: [], rejectReason: error.message});
                return;
            }
            final edit:WorkspaceEditAndRejection = cast LspConversions.toWorkspaceEdit(result);
            resolve(edit);
        });
    }

}

private class Folding implements FoldingRangeProvider {

    final client:LspClient;

    public var id(default, null):Null<String> = 'hscript-ls';
    public var onDidChange(default, null):Null<Event<FoldingRangeProvider>> = null;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideFoldingRanges(model:ITextModel, context:FoldingContext, token:CancellationToken, resolve:(ranges:Null<Array<FoldingRange>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/foldingRange', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            final list = LspConversions.asArray(result);
            if (error != null || list == null) {
                // the indentation ranges are used
                resolve(null);
                return;
            }
            resolve([for (r in list) {
                final range:FoldingRange = {start: LspConversions.asInt(r.startLine) + 1, end: LspConversions.asInt(r.endLine) + 1};
                final kind = LspConversions.asString(r.kind);
                if (kind != null) {
                    range.kind = FoldingRangeKind.fromValue(kind);
                }
                range;
            }]);
        });
    }

}

private class InlayHints implements InlayHintsProvider {

    final client:LspClient;

    public var displayName(default, null):Null<String> = 'hscript-ls';
    public var onDidChangeInlayHints(default, null):Null<VoidEvent> = null;
    public var resolveInlayHint(default, null):Null<(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void) -> Void> = null;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideInlayHints(model:ITextModel, range:Range, token:CancellationToken, resolve:(hints:Null<InlayHintList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/inlayHint', {textDocument: client.textDocumentIdentifier(model), range: LspConversions.toLspRange(range)}, token, (result, error) -> {
            final list = LspConversions.asArray(result);
            if (error != null || list == null) {
                resolve(null);
                return;
            }
            resolve({hints: [for (h in list) {
                final hint:InlayHint = {
                    label: (LspConversions.asString(h.label) : EitherType<String, Array<InlayHintLabelPart>>),
                    position: LspConversions.fromLspPosition(h.position),
                    kind: LspConversions.asInt(h.kind, 2) == 1 ? InlayHintKind.Type : InlayHintKind.Parameter,
                    paddingLeft: LspConversions.asBool(h.paddingLeft),
                    paddingRight: LspConversions.asBool(h.paddingRight)
                };
                hint;
            }]});
        });
    }

}

private class CodeLenses implements CodeLensProvider {

    final client:LspClient;

    public var onDidChange(default, null):Null<Event<CodeLensProvider>> = null;
    public var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void> = null;

    public function new(client:LspClient) {
        this.client = client;
    }

    public function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/codeLens', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            final list = LspConversions.asArray(result);
            if (error != null || list == null) {
                resolve(null);
                return;
            }
            final lenses:Array<CodeLens> = [];
            for (l in list) {
                final lens:CodeLens = {range: LspConversions.fromLspRange(l.range)};
                final command = LspConversions.toCommand(l.command);
                if (command != null && command.id == 'editor.action.findReferences' && command.arguments != null && command.arguments.length == 2) {
                    // VS Code's command takes a Uri and a Monaco position
                    final at:Dynamic = command.arguments[1];
                    command.arguments = [Uri.parse(command.arguments[0]), new Position(LspConversions.asInt(at.line) + 1, LspConversions.asInt(at.character) + 1)];
                }
                lens.command = command;
                lenses.push(lens);
            }
            resolve({lenses: lenses});
        });
    }

}

private class Semantic implements DocumentSemanticTokensProvider {

    final client:LspClient;
    final legend:SemanticTokensLegend;

    public var onDidChange(default, null):Null<VoidEvent> = null;

    public function new(client:LspClient, legend:SemanticTokensLegend) {
        this.client = client;
        this.legend = legend;
    }

    public function getLegend():SemanticTokensLegend {
        return legend;
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<cityscape.common.Languages.SemanticTokens, SemanticTokensEdits>>) -> Void):Void {
        client.syncModel(model);
        client.sendCancellableRequest('textDocument/semanticTokens/full', {textDocument: client.textDocumentIdentifier(model)}, token, (result, error) -> {
            final data = result != null ? LspConversions.asArray(result.data) : null;
            if (error != null || data == null) {
                resolve(null);
                return;
            }
            final tokens:cityscape.common.Languages.SemanticTokens = {data: UInt32Array.fromArray([for (v in data) LspConversions.asInt(v)])};
            resolve(tokens);
        });
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}

}
