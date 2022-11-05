package;

import ceramic.Scene;
import ceramic.Text;
import ceramic.TextAlign;
import elements.Im;

class MainScene extends Scene {

    var text:Text;

    override function preload() {

        // Add any asset you want to load here
        assets.add(Fonts.PIXELLARI);

    }

    override function create() {

        // Force "nearest neighbor" rendering on the pixellari font,
        // because that's a "pixel" font
        for (page in assets.font(Fonts.PIXELLARI).pages) {
            page.filter = NEAREST;
        }

        // Called when scene has finished preloading
        text = new Text();
        text.content = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
        text.pointSize = 16;
        text.pos(20, 20);
        text.fitWidth = 400;
        add(text);

    }

    override function update(delta:Float) {

        Im.begin('Options', 300);

        Im.slideFloat('Fit width', Im.float(text.fitWidth), 50, 600, 1);

        Im.slideFloat('Point size', Im.float(text.pointSize), 8, 160, 1);

        Im.select('Align', Im.enumValue(text.align), TextAlign);

        var fonts = ['Roboto', 'Pixellari'];
        var fontName = fonts[0];
        if (text.font == assets.font(Fonts.PIXELLARI)) fontName = 'Pixellari';
        Im.select('Font', Im.string(fontName), fonts);
        text.font = switch fontName {
            default: null;
            case 'Pixellari': assets.font(Fonts.PIXELLARI);
        };

        Im.editColor('Color', Im.color(text.color));

        Im.end();

        // Update text anchor from align
        switch text.align {
            case LEFT:
                text.x = 20;
                text.anchorX = 0;
            case RIGHT:
                text.x = width - 20;
                text.anchorX = 1;
            case CENTER:
                text.x = width * 0.5;
                text.anchorX = 0.5;
        }

    }

    override function resize(width:Float, height:Float) {

        // Called everytime the scene size has changed

    }

    override function destroy() {

        // Perform any cleanup before final destroy

        super.destroy();

    }

}
