package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Visual;
import imgui.ImGui;

/**
 * Dear ImGui running on top of a ceramic scene.
 *
 * The famous ImGui demo window shown here is the HAXE PORT of
 * imgui_demo.cpp (imgui.demo.ImGuiDemo): the exact same code runs
 * natively (C++), on web (wasm) and on Unity (C#).
 *
 * Just enabling the `imgui` plugin gives a clean look out of the box:
 * the Roboto-Medium font (+ CJK fallback) and the DarkBlue theme are the
 * plugin defaults (no font file or theme call needed here).
 *
 * The "Ceramic visuals" window shows the other direction: ceramic visuals
 * rendered offscreen and displayed INSIDE the ImGui layout (still fully
 * animated and interactive) with `ceramic.ImGuiVisuals`.
 *
 * The app uses RESIZE scaling (see Project.hx), so the ImGui UI stays at
 * the screen's native scale while the game content below scales itself to
 * fit a fixed 1280x960 design space: the game and the UI each have their
 * own, independent scaling.
 */
class MainScene extends Scene {

    var quads:Array<Quad> = [];

    var elapsed:Float = 0;

    var demoWindowPlaced:Bool = false;

    // Visuals displayed inside the ImGui UI (owned by the UI, no parent needed)
    var spinningGroup:Visual = null;
    var spinningQuad:Quad = null;
    var quadGroup:Visual = null;
    var groupQuads:Array<Quad> = [];
    var interactiveGroup:Visual = null;
    var buttonQuad:Quad = null;
    var buttonClicks:Int = 0;

    override function create() {

        // Some animated ceramic content behind the UI
        for (i in 0...10) {
            var quad = new Quad();
            quad.size(48, 48);
            quad.anchor(0.5, 0.5);
            quad.color = Color.fromHSB(i * 36, 0.6, 0.9);
            add(quad);
            quads.push(quad);
        }

        createImGuiVisualsContent();

    }

    override function update(delta:Float) {

        elapsed += delta;

        // The game applies its own scaling: with RESIZE, the logical size is
        // the native screen size, so we fit our 1280x960 design space in it
        // manually (the UI, on its side, stays at native scale).
        var gameScale = Math.min(width / 1280, height / 960);

        // Animate the background quads
        for (i in 0...quads.length) {
            var quad = quads[i];
            var angle = elapsed * 0.5 + i * Math.PI * 2 / quads.length;
            quad.pos(
                width * 0.5 + Math.cos(angle) * 260 * gameScale,
                height * 0.5 + Math.sin(angle) * 200 * gameScale
            );
            quad.scale(gameScale);
            quad.rotation = elapsed * 40 + i * 36;
        }

        // Any ImGui call can be done in update().
        // Here, the whole Dear ImGui demo window, ported to Haxe.
        imgui.demo.ImGuiDemo.showDemoWindow();

        // The demo window places itself at (650, 20) with a 550x680 size,
        // which doesn't fit on small screens (like the embedded iframes of
        // ceramic's website). Once it exists, fit it into the screen, and
        // start it collapsed when it had to be shrunk.
        if (!demoWindowPlaced) {
            demoWindowPlaced = true;
            var w = Math.min(550, width - 32);
            var h = Math.min(680, height - 32);
            var x = Math.max(16, Math.min(650, width - w - 16));
            var y = Math.max(16, Math.min(20, height - h - 16));
            ImGui.setWindowPosStr('Dear ImGui Demo (Haxe)', ImVec2.make(x, y));
            ImGui.setWindowSizeStr('Dear ImGui Demo (Haxe)', ImVec2.make(w, h));
            if (w < 550 || h < 680) {
                ImGui.setWindowCollapsedStr('Dear ImGui Demo (Haxe)', true);
            }
        }

        // A second window displaying ceramic visuals INSIDE the ImGui layout
        ceramicVisualsWindow();

    }

    /** Create the visuals displayed inside the imgui UI. */
    function createImGuiVisualsContent():Void {

        // A single spinning quad, centered in a slightly larger container:
        // the displayed area matches the root visual's size, so the quad
        // needs some margin around it to not get cropped when rotated
        // (at 45 degrees, its diagonal is about 1.4x its width)
        spinningGroup = new Visual();
        spinningGroup.size(96, 96);
        spinningQuad = new Quad();
        spinningQuad.size(64, 64);
        spinningQuad.anchor(0.5, 0.5);
        spinningQuad.pos(48, 48);
        spinningQuad.color = Color.fromHSB(200, 0.7, 0.95);
        spinningGroup.add(spinningQuad);

        // A group of quads (composite visual)
        quadGroup = new Visual();
        quadGroup.size(200, 120);
        for (i in 0...4) {
            var q = new Quad();
            q.size(42, 42);
            q.anchor(0.5, 0.5);
            q.color = Color.fromHSB((i * 70) % 360, 0.7, 0.95);
            quadGroup.add(q);
            groupQuads.push(q);
        }

        // An interactive group: quads react to ceramic pointer events,
        // even when displayed inside an ImGui window
        interactiveGroup = new Visual();
        interactiveGroup.size(220, 80);
        for (i in 0...3) {
            var q = new Quad();
            q.size(60, 60);
            q.anchor(0.5, 0.5);
            q.pos(40 + i * 70, 40);
            q.color = Color.GRAY;
            q.onPointerOver(this, _ -> q.color = Color.YELLOW);
            q.onPointerOut(this, _ -> q.color = Color.GRAY);
            q.onPointerDown(this, _ -> q.color = Color.fromHSB(Math.random() * 360, 0.8, 0.95));
            interactiveGroup.add(q);
        }

        // A quad used as an image button
        buttonQuad = new Quad();
        buttonQuad.size(48, 48);
        buttonQuad.color = Color.ORANGE;

    }

    /** Ceramic visuals displayed inside imgui via ImGuiVisuals. */
    function ceramicVisualsWindow():Void {

        // Animate the content (it renders live in the imgui UI)
        spinningQuad.rotation = (elapsed * 90) % 360;
        for (i in 0...groupQuads.length) {
            var q = groupQuads[i];
            var a = elapsed * 1.5 + i * Math.PI * 0.5;
            q.pos(100 + Math.cos(a) * 60, 60 + Math.sin(a) * 30);
            q.rotation = (elapsed * 60 + i * 45) % 360;
        }

        ImGui.setNextWindowPos(ImVec2.make(16, 64), ImGuiCond.FirstUseEver);
        ImGui.setNextWindowSize(ImVec2.make(320, Math.min(430, height - 96)), ImGuiCond.FirstUseEver);
        if (!ImGui.begin('Ceramic visuals')) {
            ImGui.end();
            return;
        }

        ImGui.textWrapped('Ceramic visuals rendered offscreen and displayed inside the ImGui layout with ImGuiVisuals.visual().');
        ImGui.separator();

        ImGui.text('Spinning quad (auto size):');
        ceramic.ImGuiVisuals.visual(spinningGroup);

        ImGui.text('Composite group, scale-to-fit in 120x72:');
        ceramic.ImGuiVisuals.visual(quadGroup, 120, 72);

        ImGui.text('Interactive (hover/click the squares):');
        ceramic.ImGuiVisuals.visual(interactiveGroup);

        if (ceramic.ImGuiVisuals.visualButton('##visualbtn', buttonQuad)) {
            buttonClicks++;
            buttonQuad.color = Color.fromHSB(Math.random() * 360, 0.8, 0.95);
        }
        ImGui.sameLine();
        ImGui.text('visualButton, clicks: ' + buttonClicks);

        ImGui.end();

    }

}
