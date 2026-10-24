package;

import ceramic.Color;
import ceramic.ColumnLayout;
import ceramic.RowLayout;
import ceramic.Scene;
import ceramic.TextView;
import ceramic.View;
import ceramic.ViewSize;

class MainScene extends Scene {

    var mainLayout:ColumnLayout;

    override function create() {

        // A column layout that fills the whole scene:
        // header on top, then a row of panels, then a footer.
        // Resize the window to see everything reflow.
        mainLayout = new ColumnLayout();
        mainLayout.size(width, height);
        mainLayout.padding(12);
        mainLayout.itemSpacing = 12;
        add(mainLayout);

        // Header: full width, fixed height
        var header = panel('header', 0x3185FC);
        header.viewSize(ViewSize.fill(), 60);
        mainLayout.add(header);

        // Middle row: fills the remaining vertical space
        var row = new RowLayout();
        row.viewSize(ViewSize.fill(), ViewSize.fill());
        row.itemSpacing = 12;
        mainLayout.add(row);

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
        mainLayout.add(footer);

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

        // The layout system recomputes everything when the main layout size changes
        if (mainLayout != null) mainLayout.size(width, height);

    }

}
