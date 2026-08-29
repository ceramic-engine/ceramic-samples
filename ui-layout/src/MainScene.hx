package;

import ceramic.Color;
import ceramic.ColumnLayout;
import ceramic.RowLayout;
import ceramic.Scene;
import ceramic.TextView;
import ceramic.View;
import ceramic.ViewSize;

class MainScene extends Scene {

    var root:ColumnLayout;

    override function create() {

        // A column layout that fills the whole scene:
        // header on top, then a row of panels, then a footer.
        // Resize the window to see everything reflow.
        root = new ColumnLayout();
        root.size(width, height);
        root.padding(12);
        root.itemSpacing = 12;
        add(root);

        // Header: full width, fixed height
        var header = panel('header', 0x3185FC);
        header.viewSize(ViewSize.fill(), 60);
        root.add(header);

        // Middle row: fills the remaining vertical space
        var row = new RowLayout();
        row.viewSize(ViewSize.fill(), ViewSize.fill());
        row.itemSpacing = 12;
        root.add(row);

        // Sidebar: 25% of the row's width
        var sidebar = panel('sidebar\n25%', 0x9B5DE5);
        sidebar.viewSize(ViewSize.percent(25), ViewSize.fill());
        row.add(sidebar);

        // Main content: takes what's left (flex)
        var main = panel('content\n(fill)', 0x5FAD56);
        main.viewSize(ViewSize.fill(), ViewSize.fill());
        row.add(main);

        // Second column, fixed width
        var extra = panel('160px', 0xF2652F);
        extra.viewSize(160, ViewSize.fill());
        row.add(extra);

        // Footer: full width, fixed height
        var footer = panel('footer', 0xE84855);
        footer.viewSize(ViewSize.fill(), 40);
        root.add(footer);

    }

    /**
     * A colored panel with a centered label
     */
    function panel(text:String, color:Color):View {

        var view = new TextView();
        view.content = text;
        view.pointSize = 16;
        view.textColor = Color.WHITE;
        view.align = CENTER;
        view.verticalAlign = CENTER;
        view.transparent = false;
        view.color = color;
        view.alpha = 0.85;
        return view;

    }

    override function resize(width:Float, height:Float) {

        // The layout system recomputes everything when the root size changes
        if (root != null) root.size(width, height);

    }

}
