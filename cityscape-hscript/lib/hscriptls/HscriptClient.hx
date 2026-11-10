package hscriptls;

import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.lsp.InProcessTransport;
import cityscape.lsp.LspClient;
import hscriptls.server.HscriptServer;

/**
 * Plugs the hscript language into a Cityscape context:
 *
 * 1. `HscriptLanguage.register`: the language, its TextMate grammar and its
 *    language configuration;
 * 2. an `HscriptServer` (the language server, pure Haxe) in this process,
 *    behind Cityscape's `LspClient` through an `InProcessTransport`: the
 *    client opens the `hscript` models of the context on the server, sends
 *    their changes, turns the published diagnostics into markers, and
 *    registers the providers of completion, hover, signature help,
 *    definition, document symbols and code actions;
 * 3. `HscriptProviders`: the providers of the other features the server
 *    declares (references, highlights, rename, folding, inlay hints, code
 *    lenses, semantic tokens), sent through the same client.
 */
class HscriptClient {

    public final context:Cityscape;
    public final server:HscriptServer;
    public final client:LspClient;

    final providers:DisposableStore = new DisposableStore();

    public function new(context:Cityscape, ?server:HscriptServer) {
        this.context = context;
        HscriptLanguage.register(context);
        this.server = server != null ? server : new HscriptServer();
        // the diagnostics wait for a pause in the typing (Ceramic's clock)
        this.server.schedule = (delay, callback) -> ceramic.Timer.delay(null, delay, callback);
        client = new LspClient(context, new InProcessTransport(this.server), {
            languageIds: [HscriptLanguage.LANGUAGE_ID],
            markerOwner: 'hscript',
            clientName: 'cityscape-hscript'
        });
        client.onError = (message, error) -> ceramic.Shortcuts.log.warning('hscript-ls: $message ' + Std.string(error));
        client.start(() -> providers.add(HscriptProviders.register(client)));
    }

    public function dispose():Void {
        providers.dispose();
        client.dispose();
    }

}
