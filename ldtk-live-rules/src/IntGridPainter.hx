package;

import ceramic.Entity;
import ceramic.LdtkData;
import ceramic.Point;
import ceramic.Tilemap;
import ceramic.TouchInfo;

/**
 * One undoable edit: the cells changed by a stroke or a fill
 */
class IntGridEdit {

    public var indices:Array<Int> = [];

    public var oldValues:Array<Int> = [];

    public var newValues:Array<Int> = [];

    public function new() {}

}

/**
 * Paints IntGrid values of an LDtk layer instance with the pointer, with undo and redo.
 * Left button paints `paintValue`, right button paints 0 (empty).
 * Pointer positions are converted to cells through the `Tilemap` visual displaying the level.
 */
class IntGridPainter extends Entity {

    /**
     * Fired after cells have been modified (the array is reused, copy it if you need to keep it)
     */
    @event function change(indices:Array<Int>);

    public var layer(default, null):LdtkLayerInstance;

    public var tilemap(default, null):Tilemap;

    /**
     * Value painted with the left button
     */
    public var paintValue:Int = 1;

    /**
     * Brush size in cells (square brush)
     */
    public var brushSize:Int = 1;

    /**
     * When `true`, a click fills the connected area instead of painting a stroke
     */
    public var fillMode:Bool = false;

    /**
     * Optional filter: return `false` to ignore a pointer down at this screen position
     */
    public var canPaintAt:(x:Float, y:Float)->Bool = null;

    /**
     * Cell under the pointer (-1 when outside the layer)
     */
    public var hoverCx(default, null):Int = -1;

    public var hoverCy(default, null):Int = -1;

    public var canUndo(get, never):Bool;
    inline function get_canUndo():Bool return undoStack.length > 0;

    public var canRedo(get, never):Bool;
    inline function get_canRedo():Bool return redoStack.length > 0;

    var point:Point = new Point();

    var buttonId:Int = -1;

    var strokeValue:Int = 0;

    var lastX:Float = 0;

    var lastY:Float = 0;

    var edit:IntGridEdit = null;

    var touched:Array<Bool> = [];

    var changed:Array<Int> = [];

    var undoStack:Array<IntGridEdit> = [];

    var redoStack:Array<IntGridEdit> = [];

    var fillStack:Array<Int> = [];

    public function new(layer:LdtkLayerInstance, tilemap:Tilemap) {

        super();

        this.layer = layer;
        this.tilemap = tilemap;

        for (i in 0...layer.cWid * layer.cHei)
            touched.push(false);

        screen.onPointerDown(this, handlePointerDown);
        screen.onPointerMove(this, handlePointerMove);
        screen.onPointerUp(this, handlePointerUp);

    }

    public function undo():Void {

        var edit = undoStack.pop();
        if (edit == null)
            return;
        for (i in 0...edit.indices.length)
            applyValue(edit.indices[i], edit.oldValues[i]);
        redoStack.push(edit);
        flushChanges();

    }

    public function redo():Void {

        var edit = redoStack.pop();
        if (edit == null)
            return;
        for (i in 0...edit.indices.length)
            applyValue(edit.indices[i], edit.newValues[i]);
        undoStack.push(edit);
        flushChanges();

    }

    public function clearHistory():Void {

        undoStack = [];
        redoStack = [];

    }

    function handlePointerDown(info:TouchInfo):Void {

        if (buttonId != -1)
            return;
        if (info.buttonId != 0 && info.buttonId != 2)
            return;
        if (canPaintAt != null && !canPaintAt(info.x, info.y))
            return;

        tilemap.screenToVisual(info.x, info.y, point);
        var gridSize = layer.def.gridSize;
        var cx = Math.floor(point.x / gridSize);
        var cy = Math.floor(point.y / gridSize);
        if (!isInside(cx, cy))
            return;

        var value = info.buttonId == 0 ? paintValue : 0;

        if (fillMode) {
            beginEdit();
            fill(cx, cy, value);
            endEdit();
            return;
        }

        buttonId = info.buttonId;
        strokeValue = value;
        lastX = point.x;
        lastY = point.y;

        beginEdit();
        paintBrush(cx, cy);
        flushChanges();

    }

    function handlePointerMove(info:TouchInfo):Void {

        tilemap.screenToVisual(info.x, info.y, point);
        var gridSize = layer.def.gridSize;
        var cx = Math.floor(point.x / gridSize);
        var cy = Math.floor(point.y / gridSize);
        if (isInside(cx, cy)) {
            hoverCx = cx;
            hoverCy = cy;
        }
        else {
            hoverCx = -1;
            hoverCy = -1;
        }

        if (buttonId == -1)
            return;

        // Interpolate between the previous and the current position so that fast strokes leave no hole
        var x = point.x;
        var y = point.y;
        var numSteps = Std.int(Math.max(1, Math.max(Math.abs(x - lastX), Math.abs(y - lastY))));
        for (i in 0...numSteps + 1) {
            var stepX = lastX + (x - lastX) * i / numSteps;
            var stepY = lastY + (y - lastY) * i / numSteps;
            paintBrush(Math.floor(stepX / gridSize), Math.floor(stepY / gridSize));
        }
        lastX = x;
        lastY = y;

        flushChanges();

    }

    function handlePointerUp(info:TouchInfo):Void {

        if (buttonId != -1 && info.buttonId == buttonId) {
            buttonId = -1;
            endEdit();
        }

    }

    inline function isInside(cx:Int, cy:Int):Bool {

        return cx >= 0 && cy >= 0 && cx < layer.cWid && cy < layer.cHei;

    }

    function paintBrush(cx:Int, cy:Int):Void {

        var offset = (brushSize - 1) >> 1;
        var x0 = cx - offset;
        var y0 = cy - offset;
        for (y in y0...y0 + brushSize) {
            for (x in x0...x0 + brushSize) {
                if (isInside(x, y))
                    setCell(x + y * layer.cWid, strokeValue);
            }
        }

    }

    function fill(cx:Int, cy:Int, value:Int):Void {

        var w = layer.cWid;
        var h = layer.cHei;
        var grid = layer.intGrid;
        var target = grid[cx + cy * w];
        if (target == value)
            return;

        fillStack.push(cx + cy * w);
        while (fillStack.length > 0) {
            var index = fillStack.pop();
            if (grid[index] != target)
                continue;
            setCell(index, value);
            var x = index % w;
            var y = Std.int(index / w);
            if (x > 0)
                fillStack.push(index - 1);
            if (x < w - 1)
                fillStack.push(index + 1);
            if (y > 0)
                fillStack.push(index - w);
            if (y < h - 1)
                fillStack.push(index + w);
        }

    }

    /**
     * Change a cell as part of the current edit
     */
    function setCell(index:Int, value:Int):Void {

        var old = layer.intGrid[index];
        if (old == value)
            return;

        if (!touched[index]) {
            touched[index] = true;
            edit.indices.push(index);
            edit.oldValues.push(old);
            edit.newValues.push(value);
        }

        applyValue(index, value);

    }

    function applyValue(index:Int, value:Int):Void {

        layer.setIntGrid(index % layer.cWid, Std.int(index / layer.cWid), value);
        changed.push(index);

    }

    function beginEdit():Void {

        edit = new IntGridEdit();

    }

    function endEdit():Void {

        if (edit != null) {
            for (i in 0...edit.indices.length)
                touched[edit.indices[i]] = false;
            if (edit.indices.length > 0) {
                undoStack.push(edit);
                redoStack = [];
            }
            edit = null;
        }
        flushChanges();

    }

    function flushChanges():Void {

        if (changed.length > 0) {
            emitChange(changed);
            changed.resize(0);
        }

    }

}
