package;

import ceramic.Color;
import ceramic.PremultiplyAlpha;
import ceramic.Quad;
import ceramic.RenderTexture;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Texture;
import ceramic.UInt8Array;
import ceramic.Visual;

class MainScene extends Scene {

    var renderTexture:RenderTexture;

    var canvas:Quad;

    var brush:Visual;

    var brushTexture:Texture;

    var brushDots:Array<Quad> = [];

    var pendingPoints:Array<{x:Float, y:Float}> = [];

    var stamping:Bool = false;

    var clearRequested:Bool = false;

    var painting:Bool = false;

    var lastX:Float = -1;

    var lastY:Float = -1;

    var hue:Float = 200;

    override function create() {

        // The render texture we paint into. autoRender is disabled:
        // its content is only updated when we explicitly stamp() into it,
        // and it accumulates everything stamped so far.
        renderTexture = new RenderTexture(width, height);
        renderTexture.autoRender = false;
        renderTexture.clearOnRender = false;

        // A quad displaying the render texture
        canvas = new Quad();
        canvas.texture = renderTexture;
        add(canvas);

        // A soft round brush texture, generated once at runtime
        brushTexture = createBrushTexture();

        // The brush: a small group of round quads, stamped into
        // the render texture at every stroke point. It is not added
        // to the scene and stays invisible: stamp() makes it visible
        // just long enough to render into the texture. Without this,
        // a parentless visual is still drawn on screen, so the last
        // stamped dots would linger over the canvas.
        brush = new Visual();
        brush.visible = false;
        for (i in 0...16) {
            var dot = new Quad();
            dot.texture = brushTexture;
            dot.anchor(0.5, 0.5);
            dot.size(16, 16);
            dot.active = false;
            brush.add(dot);
            brushDots.push(dot);
        }

        var hint = new Text();
        hint.content = 'Drag to paint. Press C or click [ clear ] to erase.';
        hint.pointSize = 14;
        hint.color = Color.WHITE;
        hint.pos(16, 12);
        hint.depth = 10;
        add(hint);

        var clear = new Text();
        clear.content = '[ clear ]';
        clear.pointSize = 14;
        clear.color = Color.GRAY;
        clear.anchor(1, 0);
        clear.pos(width - 16, 12);
        clear.depth = 10;
        add(clear);
        clear.onPointerDown(this, _ -> clearCanvas());

        input.onKeyDown(this, key -> {
            if (key.scanCode == KEY_C) clearCanvas();
        });

        screen.onPointerDown(this, info -> {
            // Don't start a stroke when the press lands on the clear
            // button, otherwise we would stamp a stray dot right where
            // we clicked to erase
            if (clear.hits(info.x, info.y)) return;
            painting = true;
            lastX = info.x;
            lastY = info.y;
            queuePoint(info.x, info.y);
        });

        screen.onPointerUp(this, info -> {
            painting = false;
        });

        // Paint a welcome spiral so the canvas isn't empty at launch.
        // We go through strokeTo() so it is drawn as one continuous
        // line, exactly like a stroke painted by hand.
        var cx = width * 0.5;
        var cy = height * 0.5;
        lastX = cx + 10;
        lastY = cy;
        queuePoint(lastX, lastY);
        for (i in 1...220) {
            var angle = i * 0.12;
            var radius = 10 + i * 0.6;
            strokeTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius * 0.7);
        }

        screen.onPointerMove(this, info -> {
            if (!painting) return;
            strokeTo(info.x, info.y);
        });

    }

    function strokeTo(x:Float, y:Float) {

        // Interpolate from the last painted point so the stroke stays
        // continuous even when successive points are far apart
        var dx = x - lastX;
        var dy = y - lastY;
        var dist = Math.sqrt(dx * dx + dy * dy);
        var steps = Std.int(Math.max(1, Math.ceil(dist / 6)));
        for (i in 1...steps + 1) {
            queuePoint(lastX + dx * i / steps, lastY + dy * i / steps);
        }
        lastX = x;
        lastY = y;

    }

    function queuePoint(x:Float, y:Float) {

        pendingPoints.push({ x: x, y: y });

        // Slowly cycle the brush color
        hue = (hue + 0.5) % 360;

    }

    override function update(delta:Float) {

        // A clear waits until any in-flight stamp has completed, so it
        // always wipes everything (a stamp still being rendered would
        // otherwise draw its dots on top of a freshly cleared texture)
        if (clearRequested) {
            if (stamping) return;
            clearRequested = false;
            stamping = true;
            renderTexture.clear(Color.WHITE, 0, () -> {
                stamping = false;
            });
            return;
        }

        // Stamp at most once per frame, with all the points
        // collected since the previous stamp
        if (stamping || pendingPoints.length == 0) return;

        var count = Std.int(Math.min(pendingPoints.length, brushDots.length));
        for (i in 0...brushDots.length) {
            var dot = brushDots[i];
            if (i < count) {
                var point = pendingPoints[i];
                dot.active = true;
                dot.pos(point.x, point.y);
                dot.color = Color.fromHSB(hue, 0.6, 1);
            }
            else {
                dot.active = false;
            }
        }
        pendingPoints.splice(0, count);

        stamping = true;
        renderTexture.stamp(brush, () -> {
            stamping = false;
        });

    }

    /**
     * Build a soft, round white brush texture in memory: a filled
     * disc with a feathered edge. The dots tint it with their color,
     * so a single white texture is enough for any brush color.
     */
    function createBrushTexture():Texture {

        var size = 64;
        var pixels = new UInt8Array(size * size * 4);
        var center = (size - 1) / 2.0;
        var radius = size / 2.0;

        for (y in 0...size) {
            for (x in 0...size) {
                var dx = x - center;
                var dy = y - center;
                var dist = Math.sqrt(dx * dx + dy * dy) / radius;

                // Solid core, then a soft edge over the outer 20%
                var alpha = (1.0 - dist) / 0.2;
                if (alpha > 1) alpha = 1;
                if (alpha < 0) alpha = 0;

                var i = (y * size + x) * 4;
                pixels[i + 0] = 255;
                pixels[i + 1] = 255;
                pixels[i + 2] = 255;
                pixels[i + 3] = Std.int(alpha * 255);
            }
        }

        // Textures are rendered with premultiplied alpha
        PremultiplyAlpha.premultiplyAlpha(pixels);

        return Texture.fromPixels(size, size, pixels);

    }

    function clearCanvas() {

        // Drop everything still queued and ask update() to wipe the
        // texture as soon as it is safe to do so
        pendingPoints = [];
        clearRequested = true;

    }

}
