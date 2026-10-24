package;

import ceramic.Color;
import ceramic.LdtkData;
import ceramic.Quad;
import ceramic.Visual;

/**
 * Displays the values of an LDtk IntGrid layer as translucent colored cells,
 * using the colors defined in the LDtk project.
 */
class IntGridOverlay extends Visual {

    public var layer(default, null):LdtkLayerInstance;

    /**
     * Alpha of each colored cell
     */
    public var cellAlpha:Float = 0.4;

    var quads:Array<Quad> = [];

    var colors:Array<Int> = [];

    public function new(layer:LdtkLayerInstance) {

        super();

        this.layer = layer;

        var gridSize = layer.def.gridSize;
        size(layer.cWid * gridSize, layer.cHei * gridSize);

        var values = layer.def.intGridValues;
        if (values != null) {
            for (i in 0...values.length) {
                var v = values[i];
                while (colors.length <= v.value)
                    colors.push(-1);
                colors[v.value] = v.color;
            }
        }

        rebuild();

    }

    /**
     * Rebuild every cell from the current IntGrid
     */
    public function rebuild():Void {

        var n = layer.cWid * layer.cHei;
        for (i in 0...n)
            updateCell(i);

    }

    /**
     * Update the given cells (indices in the IntGrid array)
     */
    public function updateCells(indices:Array<Int>):Void {

        for (i in 0...indices.length)
            updateCell(indices[i]);

    }

    public function updateCell(index:Int):Void {

        var value = layer.intGrid[index];
        var quad = quads[index];

        if (value == 0) {
            if (quad != null)
                quad.visible = false;
            return;
        }

        if (quad == null) {
            var gridSize = layer.def.gridSize;
            quad = new Quad();
            quad.size(gridSize, gridSize);
            quad.pos((index % layer.cWid) * gridSize, Std.int(index / layer.cWid) * gridSize);
            quad.alpha = cellAlpha;
            add(quad);
            quads[index] = quad;
        }

        quad.visible = true;
        var color = value < colors.length ? colors[value] : -1;
        quad.color = color != -1 ? color : Color.WHITE;

    }

}
