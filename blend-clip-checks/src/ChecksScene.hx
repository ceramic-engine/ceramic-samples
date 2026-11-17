package;

import ceramic.Blending;
import ceramic.Color;
import ceramic.Mesh;
import ceramic.Quad;
import ceramic.RenderTexture;
import ceramic.Scene;
import ceramic.UInt8Array;
import ceramic.Visual;

/**
 * Pixel checks of Blending.MULTIPLY, Blending.SCREEN and Visual.clipInverted.
 *
 * Every case is drawn into its own render texture, then pixels are read back and
 * compared with values computed by hand. Prints one CHECK line per case, then
 * CHECKS PASSED or CHECKS FAILED, and exits with status 0 or 1.
 */
class ChecksScene extends Scene {

    static inline final W:Int = 64;

    static inline final H:Int = 16;

    /** Color tolerance (in 0..255) */
    static inline final TOL:Int = 2;

    var cases:Array<Case> = [];

    var frames:Int = 0;

    override function create() {

        // Opaque background: (0.8, 0.6, 0.4)
        var bg = Color.fromRGBFloat(0.8, 0.6, 0.4);
        // Source: (0.5, 0.5, 1.0)
        var src = Color.fromRGBFloat(0.5, 0.5, 1.0);

        // Multiply, opaque source: dest * src
        addCase('multiply opaque', bg, 1, src, 1, MULTIPLY, [0.4, 0.3, 0.4, 1]);
        // Multiply, source alpha 0.5: dest * (src * a + 1 - a)
        addCase('multiply alpha 0.5', bg, 1, src, 0.5, MULTIPLY, [0.8 * 0.75, 0.6 * 0.75, 0.4 * 1.0, 1]);
        // Screen, opaque source: 1 - (1 - dest) * (1 - src)
        addCase('screen opaque', bg, 1, src, 1, SCREEN, [0.9, 0.8, 1.0, 1]);
        // Screen, source alpha 0.5 (premultiplied source s' = src * a): s' + dest * (1 - s')
        addCase('screen alpha 0.5', bg, 1, src, 0.5, SCREEN, [0.25 + 0.8 * 0.75, 0.25 + 0.6 * 0.75, 0.5 + 0.4 * 0.5, 1]);
        // Transparent destination: multiply draws nothing, alpha stays 0
        addCase('multiply on transparent', Color.BLACK, 0, src, 1, MULTIPLY, [0, 0, 0, 0]);
        // Transparent destination: screen draws the source, with its alpha
        addCase('screen on transparent', Color.BLACK, 0, src, 0.5, SCREEN, [0.25, 0.25, 0.5, 0.5]);

        // Clips: green content over the full width, mask over the left half
        addClipCase('clip rect', false, false);
        addClipCase('clip rect inverted', false, true);
        addClipCase('clip triangle', true, false);
        addClipCase('clip triangle inverted', true, true);

    }

    function addCase(name:String, bgColor:Color, bgAlpha:Float, srcColor:Color, srcAlpha:Float, blending:Blending, expected:Array<Float>) {

        // Render textures are cleared to transparent black before each render
        var rt = new RenderTexture(W, H, 1);

        if (bgAlpha > 0) {
            var background = new Quad();
            background.size(W, H);
            background.color = bgColor;
            background.alpha = bgAlpha;
            rt.add(background);
        }

        var source = new Quad();
        source.size(W, H);
        source.color = srcColor;
        source.alpha = srcAlpha;
        source.blending = blending;
        source.depth = 1;
        rt.add(source);

        cases.push(new Case(name, rt, [{ x: W >> 1, expected: expected }]));

    }

    function addClipCase(name:String, triangle:Bool, inverted:Bool) {

        var rt = new RenderTexture(W, H, 1);

        var background = new Quad();
        background.size(W, H);
        background.color = Color.BLACK;
        background.depth = -1;
        rt.add(background);

        var mask:Visual;
        if (triangle) {
            // Triangle covering the left part of the texture (x < 32 at mid height)
            var mesh = new Mesh();
            mesh.vertices = [0, -H, 32, H * 0.5, 0, H * 2];
            mesh.indices = [0, 1, 2];
            mesh.color = Color.WHITE;
            mask = mesh;
        }
        else {
            var quad = new Quad();
            quad.size(W >> 1, H);
            mask = quad;
        }
        mask.visible = false;
        mask.clipInverted = inverted;
        rt.add(mask);

        var content = new Quad();
        content.size(W, H);
        content.color = Color.fromRGBFloat(0, 1, 0);
        content.clip = mask;
        content.depth = 1;
        rt.add(content);

        var green = [0.0, 1.0, 0.0, 1.0];
        var black = [0.0, 0.0, 0.0, 1.0];
        cases.push(new Case(name, rt, [
            { x: 8, expected: inverted ? black : green },
            { x: W - 8, expected: inverted ? green : black }
        ]));

    }

    override function update(delta:Float) {

        // Let render textures render, then read them back
        frames++;
        if (frames < 4) return;

        var failed = 0;
        for (c in cases) {
            var pixels = c.rt.fetchPixels();
            var y = H >> 1;
            var ok = true;
            var details = [];
            for (probe in c.probes) {
                var i = (y * W + probe.x) * 4;
                var got = [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]];
                var want = [for (v in probe.expected) Math.round(v * 255)];
                var match = true;
                for (k in 0...4) {
                    if (Math.abs(got[k] - want[k]) > TOL) match = false;
                }
                if (!match) ok = false;
                details.push('x=${probe.x} got=$got want=$want');
            }
            if (!ok) failed++;
            trace('CHECK ' + (ok ? 'OK  ' : 'FAIL') + ' ' + c.name + ' | ' + details.join(' | '));
        }

        trace(failed == 0 ? 'CHECKS PASSED' : 'CHECKS FAILED ($failed)');
        Sys.exit(failed == 0 ? 0 : 1);

    }

}

typedef Probe = {
    x:Int,
    expected:Array<Float>
}

class Case {

    public var name:String;

    public var rt:RenderTexture;

    public var probes:Array<Probe>;

    public function new(name:String, rt:RenderTexture, probes:Array<Probe>) {
        this.name = name;
        this.rt = rt;
        this.probes = probes;
    }

}
