package;

import ceramic.Arc;
import ceramic.Border;
import ceramic.Color;
import ceramic.Filter;
import ceramic.Line;
import ceramic.Mesh;
import ceramic.Quad;
import ceramic.RenderTexture;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Timer;
import ceramic.Transform;
import ceramic.Tween;
import ceramic.Utils;
import ceramic.Visual;

using ceramic.MeshExtensions;

class Demo extends Scene {

    override function preload() {

        assets.add(Images.CERAMIC);

        assets.add(shaders.Glow);
        assets.add(shaders.Blur);
        assets.add(shaders.TintBlack);

    }

    override function create() {

        var cols = 2;
        var rows = 2;
        var w = width / cols;
        var h = height / rows;

        demoShapes(
            0, 0,
            w, h,
            1
        );

        demoTint(
            w, 0,
            w, h,
            2
        );

        demoTextures(
            0, h,
            w, h,
            3
        );

        demoClip(
            w, h,
            w, h,
            4
        );

    }

    function demoShapes(x:Float, y:Float, w:Float, h:Float, d:Float) {

        var container = new Quad();
        container.pos(0, 0);
        container.size(w, h);
        container.depth = d;
        container.color = 0x5EBB59;
        add(container);

        var text = new Text();
        text.content = 'SHAPES';
        text.align = CENTER;
        text.color = Color.WHITE;
        text.anchor(0.5, 0.5);
        text.pos(w * 0.5, h * 0.06);
        text.depth = 100;
        text.pointSize = 16;
        container.add(text);

        var quad = new Quad();
        quad.anchor(0.5, 0.5);
        quad.color = Color.WHITE;
        quad.rotation = -33;
        quad.size(w * 0.2, h * 0.2);
        quad.pos(w * 0.25, h * 0.3);
        quad.depth = 2;
        container.add(quad);

        var line = new Line();
        line.color = Color.WHITE;
        line.thickness = 2;
        line.depth = 3;
        line.pos(w * 0.1, h * 0.5);
        line.points = [];
        container.add(line);

        var pie = new Arc();
        pie.radius = 0;
        pie.borderPosition = OUTSIDE;
        pie.thickness = w * 0.12;
        pie.pos(w * 0.75, h * 0.75);
        pie.depth = 4;
        pie.color = Color.WHITE;
        container.add(pie);

        var rectangle = new Border();
        rectangle.borderColor = Color.WHITE;
        rectangle.borderPosition = OUTSIDE;
        rectangle.borderSize = 2;
        rectangle.anchor(0.5, 0.5);
        rectangle.size(0, 0);
        rectangle.pos(w * 0.6, h * 0.3);
        rectangle.depth = 5;
        rectangle.transform = new Transform();
        container.add(rectangle);

        var circle = new Arc();
        circle.borderPosition = OUTSIDE;
        circle.thickness = 2;
        circle.angle = 360;
        circle.pos(w * 0.8, h * 0.4);
        circle.depth = 6;
        circle.color = Color.WHITE;
        circle.transform = rectangle.transform;
        container.add(circle);

        var time = 0.0;
        var duration = 5.0;
        var halfTime = 0.0;
        var halfDuration = duration * 0.5;

        function update(delta:Float) {

            time = (time + delta) % duration;
            var ratio = time / duration;
            var sinRatio = (Math.sin(ratio * Math.PI * 2) + 1.0) * 0.5;
            var easeRatio = Tween.ease(QUART_EASE_IN_OUT, sinRatio);
            halfTime = (halfTime + delta) % halfDuration;
            var fastRatio = halfTime / halfDuration;
            var fastSinRatio = (Math.sin(fastRatio * Math.PI * 2) + 1.0) * 0.5;
            var fastEaseRatio = Tween.ease(QUART_EASE_IN_OUT, fastSinRatio);

            // Rotating a quad
            quad.rotation = 360 * ratio;

            // Changing line points at each frame
            line.points[0] = 0 + w * 0.1 * easeRatio;
            line.points[1] = 0 + h * 0.2 * easeRatio;
            line.points[2] = w * 0.1 + w * 0.1 * easeRatio;
            line.points[3] = h * 0.4;
            line.points[4] = w * 0.25 - w * 0.1 * easeRatio;
            line.points[5] = h * 0.1;
            line.points[6] = w * 0.4 - w * 0.16 * easeRatio;
            line.points[7] = h * 0.3 - h * 0.01 * easeRatio;
            line.contentDirty = true;

            // Changing the filling angle of the pie
            pie.angle = fastEaseRatio * 360;
            pie.skewX = 15 + 10 * sinRatio;

            // Rotating and changing rectangle size
            rectangle.rotation = -20 + 90 * easeRatio;
            rectangle.size(
                w * 0.22 * (0.5 + easeRatio * 0.5),
                h * 0.12 * (0.5 + easeRatio * 0.5)
            );

            // Changing circle radius
            circle.radius = w * (0.1 - 0.05 * easeRatio);

            // Changing transform translation to translate
            // both ring & border with the same value
            // (cicle.transform is also assigned to rectangle.transform)
            circle.transform.tx = w * (0.04 * easeRatio);
            circle.transform.changedDirty = true;

        }
        app.onUpdate(this, update);
        update(0);

    }

    function demoTint(x:Float, y:Float, w:Float, h:Float, d:Float) {

        var container = new Quad();
        container.pos(x, y);
        container.size(w, h);
        container.depth = d;
        container.color = 0x5B6E83;
        add(container);

        var text = new Text();
        text.content = 'TINT COLORS';
        text.align = CENTER;
        text.color = Color.WHITE;
        text.anchor(0.5, 0.5);
        text.pos(w * 0.5, h * 0.06);
        text.depth = 100;
        text.pointSize = 16;
        container.add(text);

        var s = w * 0.25;

        var image0 = new Quad();
        image0.texture = assets.texture(Images.CERAMIC);
        image0.size(s, s);
        image0.anchor(0.5, 0.5);
        image0.pos(w * 0.25, h * 0.39);
        image0.depth = 1;
        container.add(image0);
        var text0 = new Text();
        text0.content = 'tint (standard)';
        text0.align = CENTER;
        text0.color = Color.WHITE;
        text0.anchor(0.5, 0.5);
        text0.pos(image0.x, image0.y - h * 0.22);
        text0.depth = 99;
        text0.pointSize = 14;
        container.add(text0);

        var image1 = new Mesh();
        image1.texture = assets.texture(Images.CERAMIC);
        image1.color = Color.WHITE;
        image1.shader = assets.shader(shaders.TintBlack);
        image1.createQuad(s, s);
        image1.anchor(0.5, 0.5);
        image1.pos(w * 0.75, h * 0.39);
        image1.depth = 1;
        container.add(image1);
        var text1 = new Text();
        text1.content = 'tint black';
        text1.align = CENTER;
        text1.color = Color.WHITE;
        text1.anchor(0.5, 0.5);
        text1.pos(image1.x, image1.y - h * 0.22);
        text1.depth = 99;
        text1.pointSize = 14;
        container.add(text1);

        var image2 = new Mesh();
        image2.texture = assets.texture(Images.CERAMIC);
        image2.color = Color.WHITE;
        image2.shader = assets.shader(shaders.TintBlack);
        image2.createQuad(s, s);
        image2.anchor(0.5, 0.5);
        image2.pos(w * 0.5, h * 0.75);
        image2.depth = 1;
        container.add(image2);
        var text3 = new Text();
        text3.content = 'dual tint';
        text3.align = CENTER;
        text3.color = Color.WHITE;
        text3.anchor(0.5, 0.5);
        text3.pos(image2.x, image2.y - h * 0.22);
        text3.depth = 99;
        text3.pointSize = 14;
        container.add(text3);

        var time = 0.0;
        var duration = 5.0;

        function update(delta:Float) {

            time = (time + delta) % duration;
            var ratio = time / duration;
            var ratio2 = ((ratio + 0.5) * 2) % 1.0;

            image0.color = Color.fromHSB(360 * ratio, 1, 1);

            var darkColor:Color = Color.fromHSB(360 * ratio, 1, 1);
            image1.setDarkColor(darkColor);

            var color2:Color = Color.fromHSB(360 * (1 - ratio2), 1, 1);
            var darkColor2:Color = Color.fromHSB(360 * ratio2, 1, 1);
            image2.color = color2;
            image2.setDarkColor(darkColor2);

        }
        app.onUpdate(this, update);
        update(0);

    }

    function demoTextures(x:Float, y:Float, w:Float, h:Float, d:Float) {

        var container = new Quad();
        container.pos(x, y);
        container.size(w, h);
        container.depth = d;
        container.color = 0xBA58BE;
        add(container);

        var text = new Text();
        text.content = 'TEXTURES & FILTERS';
        text.align = CENTER;
        text.color = Color.WHITE;
        text.anchor(0.5, 0.5);
        text.pos(w * 0.5, h * 0.06);
        text.depth = 100;
        text.pointSize = 16;
        container.add(text);

        var source = new Quad();
        source.texture = assets.texture(Images.CERAMIC);
        source.size(w * 0.2, w * 0.2);
        source.anchor(0.5, 0.5);
        source.renderTarget = new RenderTexture(Std.int(w * 0.2), Std.int(w * 0.2));
        source.pos(source.renderTarget.width * 0.5, source.renderTarget.height * 0.5);
        app.onUpdate(source, function(delta) {
            source.rotation = (Utils.sinRatio(Timer.now) - 0.5) * 33;
            source.scaleX = 0.4 + Tween.ease(QUAD_EASE_IN_OUT, Utils.sinRatio(Timer.now * 0.25)) * 0.6;
        });

        // Display original
        var quad1 = new Quad();
        quad1.texture = source.renderTarget;
        quad1.size(w * 0.2, w * 0.2);
        quad1.anchor(0.5, 0.5);
        quad1.pos(w * 0.28, h * 0.35);
        container.add(quad1);
        var text1 = new Text();
        text1.content = 'original';
        text1.align = CENTER;
        text1.color = Color.WHITE;
        text1.anchor(0.5, 0.5);
        text1.pos(quad1.x, quad1.y - h * 0.18);
        text1.depth = 99;
        text1.pointSize = 14;
        container.add(text1);

        // Render to texture with some transformation
        var quad2A = new Quad();
        quad2A.anchor(0.5, 0.5);
        quad2A.depth = 1;
        quad2A.color = Color.interpolate(0xAE5FB9, Color.WHITE, 0.5);
        container.add(quad2A);
        var quad2B = new Quad();
        quad2B.texture = source.renderTarget;
        quad2B.anchor(0.5, 0.5);
        quad2B.pos(w * 0.72, h * 0.35);
        quad2B.depth = 2;
        container.add(quad2B);
        quad2A.pos(quad2B.x, quad2B.y);
        quad2A.size(quad2B.width, quad2B.height);
        app.onUpdate(quad2A, function(delta) {
            var skew = 35 + 25 * Utils.cosRatio(Timer.now * 0.25);
            quad2A.skewX = skew;
            quad2B.skewX = skew;
        });
        var text2 = new Text();
        text2.content = 'render to texture';
        text2.align = CENTER;
        text2.color = Color.WHITE;
        text2.anchor(0.5, 0.5);
        text2.pos(quad2B.x, quad2B.y - h * 0.18);
        text2.depth = 99;
        text2.pointSize = 14;
        container.add(text2);

        // Blur filter
        var quad3 = new Quad();
        quad3.texture = assets.texture(Images.CERAMIC);
        quad3.size(w * 0.2, w * 0.2);
        quad3.anchor(0.5, 0.5);

        var filter1 = new Filter();
        filter1.size(quad3.width * 1.25, quad3.height * 1.25);
        filter1.pos(w * 0.28, h * 0.75);
        filter1.anchor(0.5, 0.5);
        container.add(filter1);

        quad3.pos(filter1.width * 0.5, filter1.height * 0.5);
        filter1.content.add(quad3);

        var shader1 = assets.shader(shaders.Blur);
        shader1.resolution(
            source.renderTarget.width * source.renderTarget.density,
            source.renderTarget.height * source.renderTarget.density
        );
        filter1.shader = shader1;

        app.onUpdate(shader1, function(delta) {
            var blurSize = (Math.sin((Timer.now % 1.0) * Math.PI * 2) + 1.0);
            shader1.setVec2('blurSize', blurSize, blurSize);
        });

        var text3 = new Text();
        text3.content = 'blur filter';
        text3.align = CENTER;
        text3.color = Color.WHITE;
        text3.anchor(0.5, 0.5);
        text3.pos(filter1.x, filter1.y - h * 0.18);
        text3.depth = 99;
        text3.pointSize = 14;
        container.add(text3);

        // Glow filter
        var quad4 = new Quad();
        quad4.texture = assets.texture(Images.CERAMIC);
        quad4.size(w * 0.2, w * 0.2);
        quad4.anchor(0.5, 0.5);

        var filter2 = new Filter();
        filter2.size(quad4.width * 1.5, quad4.height * 1.5);
        filter2.pos(w * 0.72, h * 0.75);
        filter2.anchor(0.5, 0.5);
        container.add(filter2);

        quad4.pos(filter2.width * 0.5, filter2.height * 0.5);
        filter2.content.add(quad4);

        var shader2 = assets.shader(shaders.Glow).clone();
        shader2.setVec2('resolution',
            source.renderTarget.width * source.renderTarget.density,
            source.renderTarget.height * source.renderTarget.density
        );
        filter2.shader = shader2;

        var glowColor = Color.YELLOW;
        shader2.setVec3('glowColor', glowColor.redFloat, glowColor.greenFloat, glowColor.blueFloat);
        shader2.setFloat('glowIntensity', 1);
        shader2.setFloat('glowThreshold', 0.5);

        app.onUpdate(shader2, function(delta) {
            var glowSize = 2.0 + Tween.ease(QUAD_EASE_IN_OUT, Utils.sinRatio(Timer.now)) * 3;
            var glowIntensity = 1.0 + Tween.ease(QUAD_EASE_IN_OUT, Utils.cosRatio(Timer.now));
            var scale = 0.75 + Utils.cosRatio(Timer.now) * 0.25;
            shader2.setFloat('glowSize', glowSize);
            shader2.setFloat('glowIntensity', glowIntensity);
            quad4.scale(scale);
        });

        var text4 = new Text();
        text4.content = 'glow & scale';
        text4.align = CENTER;
        text4.color = Color.WHITE;
        text4.anchor(0.5, 0.5);
        text4.pos(filter2.x, filter2.y - h * 0.18);
        text4.depth = 99;
        text4.pointSize = 14;
        container.add(text4);

    }

    function demoClip(x:Float, y:Float, w:Float, h:Float, d:Float) {

        var container = new Quad();
        container.pos(x, y);
        container.size(w, h);
        container.depth = d;
        container.color = 0x505FC0;
        add(container);

        var text = new Text();
        text.content = 'POLYGON CLIPPING';
        text.align = CENTER;
        text.color = Color.WHITE;
        text.anchor(0.5, 0.5);
        text.pos(w * 0.5, h * 0.06);
        text.depth = 100;
        text.pointSize = 16;
        container.add(text);

        var clipper1 = new Quad();
        clipper1.size(w * 0.4, w * 0.1);
        clipper1.pos(w * 0.5, h * 0.5);
        clipper1.rotation = 33;
        clipper1.visible = false;
        container.add(clipper1);

        var clipper2 = new Quad();
        clipper2.size(w * 0.4, w * 0.1);
        clipper2.pos(w * 0.5, h * 0.5);
        clipper2.rotation = 33;
        clipper2.visible = false;
        container.add(clipper2);

        var image1 = new Quad();
        image1.texture = assets.texture(Images.CERAMIC);
        image1.size(w * 0.5, w * 0.5);
        image1.anchor(0.5, 0.5);
        image1.pos(w * 0.5, h * 0.5);
        image1.depth = 20;
        container.add(image1);

        var image2 = new Quad();
        image2.texture = assets.texture(Images.CERAMIC);
        image2.size(w * 0.5, w * 0.5);
        image2.anchor(0.5, 0.5);
        image2.pos(w * 0.5, h * 0.5);
        image2.depth = 21;
        container.add(image2);

        image1.clip = clipper1;
        image2.clip = clipper2;

        app.onUpdate(this, function(delta) {

            clipper1.rotation = (clipper1.rotation + delta * 100) % 360;
            clipper2.rotation = (clipper2.rotation + delta * 200) % 360;

        });

    }

}
