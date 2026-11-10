package hscriptls;

import cityscape.Cityscape;
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
 *    registers a provider for each feature the server declares
 *    (completion, hover, signature help, definition, references,
 *    highlights, document symbols, code actions, rename, folding, inlay
 *    hints, code lenses, semantic tokens).
 */
class HscriptClient {

    public final context:Cityscape;
    public final server:HscriptServer;
    public final client:LspClient;

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
        client.start();
    }

    public function dispose():Void {
        client.dispose();
    }

}
