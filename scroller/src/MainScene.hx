package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Scroller;
import ceramic.Text;
import ceramic.Visual;

class MainScene extends Scene {

    static final ITEM_COUNT:Int = 42;

    static final ITEM_HEIGHT:Float = 56;

    static final ITEM_GAP:Float = 6;

    override function create() {

        var title = new Text();
        title.content = 'Drag or use the mouse wheel to scroll (momentum & bounce included)';
        title.pointSize = 13;
        title.color = Color.WHITE;
        title.anchor(0.5, 0.5);
        title.pos(width * 0.5, 20);
        add(title);

        // The content visual holds everything that will be scrolled
        var content = new Visual();
        var contentWidth = width - 80;
        content.size(contentWidth, ITEM_COUNT * (ITEM_HEIGHT + ITEM_GAP) + ITEM_GAP);

        for (i in 0...ITEM_COUNT) {

            var item = new Quad();
            item.size(contentWidth, ITEM_HEIGHT);
            item.color = Color.fromHSB((i * 24) % 360, 0.45, 0.9);
            item.pos(0, ITEM_GAP + i * (ITEM_HEIGHT + ITEM_GAP));
            content.add(item);

            var label = new Text();
            label.content = 'Item ' + (i + 1);
            label.pointSize = 18;
            label.color = Color.WHITE;
            label.anchor(0, 0.5);
            label.pos(16, ITEM_HEIGHT * 0.5);
            item.add(label);

            // Items stay interactive inside the scroller: a click that
            // didn't turn into a drag is still delivered to the item
            var index = i;
            item.onPointerDown(this, _ -> {
                log.info('Clicked item ' + (index + 1));
                item.color = Color.WHITE;
                item.tween(QUAD_EASE_OUT, 0.4, 0, 1, (v, t) -> {
                    item.color = Color.interpolate(Color.WHITE, Color.fromHSB((index * 24) % 360, 0.45, 0.9), v);
                });
            });

        }

        // The scroller displays a viewport over its content,
        // handling drag, momentum, bounce and mouse wheel for us
        var scroller = new Scroller(content);
        scroller.pos(40, 40);
        scroller.size(contentWidth, height - 80);
        add(scroller);

        // Clip the scrolled content to the scroller area, so that items
        // don't leak over what's around it (like the title above)
        var clipQuad = new Quad();
        clipQuad.visible = false;
        clipQuad.pos(scroller.x, scroller.y);
        clipQuad.size(scroller.width, scroller.height);
        add(clipQuad);
        scroller.clip = clipQuad;

    }

}
