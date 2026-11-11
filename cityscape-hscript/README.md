# Cityscape hscript

A code editor for [hscript](https://github.com/HaxeFoundation/hscript), the scripting subset of Haxe, made with **Cityscape** (the Haxe port of Monaco, the editor of VS Code) in a **Glaze** interface. The language support is a language server written in pure Haxe on top of hscript's own parser, plugged into the editor through Cityscape's LSP client, in the same process. The scripts draw on a canvas: press Run and watch the turtle.

It runs on the web and natively (macOS here), like the rest of Glaze.

## What it shows

- **Colors**: a TextMate grammar written for hscript (`lib/hscriptls/res/hscript.tmLanguage.json`, derived from the Haxe grammar bundled with Glaze), with VS Code's Dark+ and Light+ themes (the sun / moon button), and semantic tokens from the server (the API's objects, functions and constants, parameters, script functions).
- **Diagnostics**, as you type: parse errors at their exact range, unknown identifiers and fields, unused variables and parameters (faded), duplicate declarations, wrong argument counts, `break` outside a loop, default values hscript ignores, names hiding a global, and the scoping rules of hscript's `Interp` (a top level function called before its declaration, a function using a variable declared after it). Hover a squiggle or press F8.
- **Quick fixes** (Cmd+. or the light bulb): declare an unknown variable, change it to a similar name, remove an unused one.
- **Completion**: keywords, the names in scope, the runtime API with signatures and documentation, the fields after `.` (`turtle.`, `Math.`, strings, arrays, maps, object literals), snippets (`for`, `forin`, `if`, `function`, `switch`, `try`, `repeat`).
- **Hover**, **signature help** (type `circle(`), **inlay hints** with the parameter names of the calls, **go to definition** (F12, Cmd+click), **references** (Shift+F12), **highlights** of the symbol under the cursor, **rename** (F2), the **outline** feeding the **sticky scroll**, **folding** (blocks, comments, `// #region`), and **code lenses** above the functions: their references, and `Run` for the ones without parameters.
- The editor itself: find and replace (Cmd+F, Cmd+Alt+F), multiple cursors (Alt+click, Cmd+D, Cmd+Alt+Up/Down), comment toggling (Cmd+/), indentation and auto closing pairs from the language configuration.
- **Running**: Run (or Cmd+Enter) runs the script with hscript's `Interp`. What it draws and prints is played back over a second or two, the editor highlighting the line of each step; the console lists the printed lines (click one to go to its line). A runtime error becomes a marker and an inline highlight at its range.

The examples: **Spiral** (functions, loops, colors), **Tree** (a recursive function), **Starfield** (arrays, objects, maps) and **Mistakes** (a script full of diagnostics to fix).

## Running

The project uses the Ceramic install on the `PATH`; `glaze` and `cityscape` are built-in plugins of Ceramic, `hscript` a library bundled with it.

```sh
# web: build, then open project/web in a browser, or run it with Electron
ceramic clay build web --setup --assets
ceramic web project --run

# macOS
ceramic clay build mac --setup --assets
open project/mac/cityscape-hscript.app
```

### Captures

`--variant capture` builds a version that plays a scene, writes a PNG and quits (a hidden window natively; Electron takes the screenshot on the web). `CS_HSCRIPT_SCENE` is one of `run`, `light`, `completion`, `suggest`, `suggest-editor`, `codelens`, `signature`, `hover`, `quickfix`, `quickfix-menu`, `error` (see `src/MainScene.hx`), `CS_HSCRIPT_OUT` the PNG path.

```sh
ceramic clay build mac --setup --assets --variant capture
CS_HSCRIPT_SCENE=completion CS_HSCRIPT_OUT=/tmp/completion.png ./project/mac/cityscape-hscript.app/Contents/MacOS/cityscape-hscript

ceramic clay build web --setup --assets --variant capture
CS_HSCRIPT_SCENE=hover CS_HSCRIPT_OUT=/tmp/hover-canvas.png ceramic web project --run --hidden \
    --screenshot /tmp/hover.png --screenshot-on-signal --screenshot-then-quit
```

## How the language is plugged

Everything is in `lib/hscriptls`. Reading order:

1. **`HscriptLanguage`** registers the language on a `Cityscape` context: its id and extensions, the TextMate grammar (embedded at compile time by `Embed`) and the language configuration (comments, brackets, auto closing and surrounding pairs, indentation rules, on enter rules for `/** */` comments, folding markers). This alone gives colors, brackets, comment toggling and indentation.

2. **`server/HscriptServer`** is the language server. It speaks the Language Server Protocol: `handleMessage(message, onResponse)` takes JSON-RPC messages as anonymous structures (no serialization in process) and answers requests through `onResponse`; `onNotification` sends `textDocument/publishDiagnostics`. That is the shape of Cityscape's `LspInProcessServer` interface, which it implements when the `cityscape` plugin is there. It depends on nothing but hscript, so it could also run behind a stdio loop for another editor, and the tests run it without an editor.

   Each request works on an **`Analysis`** of the document, made by **`server/Analyzer`**: hscript's `Parser` (with `hscriptPos`, types, JSON objects and metadata allowed, like the runtime), then a walk of the syntax tree that builds scopes, symbols and references with the scoping rules of hscript's `Interp`, and the diagnostics. **`server/LanguageFeatures`** turns an analysis into the answers (completion, hover, signature help, references, rename, symbols, folding, inlay hints, code lenses, semantic tokens) and **`server/CodeActions`** into quick fixes. **`ScriptApi`** describes the runtime API (names, parameters, types, documentation): the server uses it for completion, hover, signature help, inlay hints and argument checks, and the runtime binds an implementation to each function by name.

3. **`HscriptClient`** connects them:

   ```haxe
   final server = new HscriptServer();
   final client = new LspClient(context, new InProcessTransport(server), {languageIds: ['hscript'], markerOwner: 'hscript'});
   client.start();
   ```

   The client opens the `hscript` models of the context on the server and sends their changes, turns the diagnostics into markers, and registers a provider for each feature the server declares (completion, hover, signature help, definition, references, document highlights, document symbols, code actions, rename, folding ranges, inlay hints, code lenses, semantic tokens), converting the LSP answers to Monaco's types. Nothing is registered by hand: the code lens `N references` uses VS Code's `editor.action.findReferences` command with LSP arguments (a uri and a position), which the client converts for the editor, and the `$(play)` of the `Run` lens is drawn as Monaco's codicon. The suggestions show the codicon of each completion kind in its color.

The app (`src/Playground.hx`) only creates models of language `hscript` in the context and shows them in a `CityscapeEditor`.

## Layout

- `lib/hscriptls`: the language (see above).
- `lib/runtime/ScriptRuntime.hx`: runs a script with hscript's `Interp` and the API of `ScriptApi.drawing()`, recording the drawing commands and printed lines with their script line; it stops endless loops and turns errors into ranges.
- `src/Playground.hx`: the Glaze interface (toolbar, editor, canvas, console, status bar), the playback, the execution highlight and the runtime error markers.
- `src/MainScene.hx`, `src/Project.hx`: the Ceramic scene and project, and the capture scenes.
- `scripts/`: the example scripts, embedded at compile time (`lib/Examples.hx`).
- `tests/`: unit tests of the analyzer, the server and the runtime, without an editor.

## Tests

```sh
cd tests
ceramic headless run node --setup --assets
ceramic clay build mac --setup --assets
./project/mac/tests.app/Contents/MacOS/tests
```

The native test build uses a hidden window.
