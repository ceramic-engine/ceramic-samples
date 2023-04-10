package;

import ceramic.Color;
import ceramic.Filter;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Timer;
import ceramic.Utils;

class MainScene extends Scene {

    var quadOutsideFilter:Quad;

    var filter:Filter;

    var backgroundInFilter:Quad;

    var quadInFilter:Quad;

    override function create() {

        // Create a quad outside filter
        quadOutsideFilter = new Quad();
        quadOutsideFilter.color = Color.INDIGO;
        quadOutsideFilter.anchor(0.5, 0.5);
        quadOutsideFilter.pos(width * 0.5, height * 0.5);
        quadOutsideFilter.size(350, 350);
        add(quadOutsideFilter);

        // Plug events
        var quadOutsideFilterOver = false;
        quadOutsideFilter.onPointerOver(this, info -> {
            quadOutsideFilterOver = true;
            quadOutsideFilter.color = Color.interpolate(Color.INDIGO, Color.WHITE, 0.5);
        });
        quadOutsideFilter.onPointerOut(this, info -> {
            quadOutsideFilterOver = false;
            quadOutsideFilter.color = Color.INDIGO;
        });
        quadOutsideFilter.onPointerDown(this, info -> {
            quadOutsideFilter.color = Color.RED;
        });
        quadOutsideFilter.onPointerUp(this, info -> {
            quadOutsideFilter.color = quadOutsideFilterOver ? Color.interpolate(Color.INDIGO, Color.WHITE, 0.5) : Color.INDIGO;
        });

        // Create a filter
        filter = new Filter();
        filter.anchor(0.5, 0.5);
        filter.size(150, 150);
        filter.pos(
            quadOutsideFilter.width * 0.5,
            quadOutsideFilter.height * 0.5
        );
        quadOutsideFilter.add(filter);

        // Put a background inside
        backgroundInFilter = new Quad();
        backgroundInFilter.depth = 1;
        backgroundInFilter.color = Color.BLUE;
        backgroundInFilter.size(filter.width, filter.height);
        filter.content.add(backgroundInFilter);

        // Plug background events
        var backgroundInFilterOver = false;
        backgroundInFilter.onPointerOver(this, info -> {
            backgroundInFilterOver = true;
            backgroundInFilter.color = Color.interpolate(Color.BLUE, Color.WHITE, 0.5);
        });
        backgroundInFilter.onPointerOut(this, info -> {
            backgroundInFilterOver = false;
            backgroundInFilter.color = Color.BLUE;
        });
        backgroundInFilter.onPointerDown(this, info -> {
            backgroundInFilter.color = Color.RED;
        });
        backgroundInFilter.onPointerUp(this, info -> {
            backgroundInFilter.color = backgroundInFilterOver ? Color.interpolate(Color.BLUE, Color.WHITE, 0.5) : Color.BLUE;
        });

        // Put a quad inside
        quadInFilter = new Quad();
        quadInFilter.depth = 2;
        quadInFilter.color = Color.CYAN;
        quadInFilter.anchor(0.5, 0.5);
        quadInFilter.pos(
            filter.width * 0.5,
            filter.height * 0.5
        );
        quadInFilter.size(100, 40);
        filter.content.add(quadInFilter);

        // Plug quad events
        var quadInFilterOver = false;
        quadInFilter.onPointerOver(this, info -> {
            quadInFilterOver = true;
            quadInFilter.color = Color.WHITE;
        });
        quadInFilter.onPointerOut(this, info -> {
            quadInFilterOver = false;
            quadInFilter.color = Color.CYAN;
        });
        quadInFilter.onPointerDown(this, info -> {
            quadInFilter.color = Color.RED;
        });
        quadInFilter.onPointerUp(this, info -> {
            quadInFilter.color = quadInFilterOver ? Color.WHITE : Color.CYAN;
        });

    }

    override function update(delta:Float) {

        var ratio1 = Utils.sinRatio((Timer.now * 0.2) % 1.0);
        var ratio2 = Utils.sinRatio((Timer.now * 0.1 + 0.5) % 1.0);
        var ratio3 = Utils.sinRatio((Timer.now * 0.025 + 0.25) % 1.0);

        quadOutsideFilter.skew(ratio1 * -20, -20 + ratio3 * 40);

        filter.skew(ratio1 * 30, -ratio2 * 30);
        filter.rotation = -ratio3 * 360;

        quadInFilter.rotation = ratio3 * 360;

    }

}
