package;

import ceramic.Border;
import ceramic.Color;
import ceramic.Key;
import ceramic.KeyCode;
import ceramic.LdtkData;
import ceramic.LdtkRuleRunner;
import ceramic.Scene;
import ceramic.Tilemap;
import elements.Im;
import ldtk.rules.RuleGroupDef;

using ceramic.TilemapPlugin;

/**
 * An auto-layer recomputed at runtime and its panel state
 */
class LayerEntry {

    public var layer:LdtkLayerInstance;

    public var visible:Bool = true;

    /**
     * Tiles saved by the LDtk editor, to check parity with the runtime engine
     */
    public var bakedTiles:Array<Int>;

    public var originalSeed:Int;

    public function new(layer:LdtkLayerInstance) {
        this.layer = layer;
        this.bakedTiles = layer.autoLayerTiles != null ? layer.autoLayerTiles.copy() : [];
        this.originalSeed = layer.seed;
    }

}

/**
 * A rule group that can be toggled from the panel
 */
class GroupEntry {

    public var layer:LdtkLayerInstance;

    public var group:RuleGroupDef;

    public var active:Bool;

    public var originalActive:Bool;

    public function new(layer:LdtkLayerInstance, group:RuleGroupDef) {
        this.layer = layer;
        this.group = group;
        this.active = group.active;
        this.originalActive = group.active;
    }

}

class MainScene extends Scene {

    static inline var LEVEL_X = 8;

    static inline var LEVEL_Y = 8;

    static inline var PANEL_WIDTH = 330;

    static inline var STATS_WINDOW = 30;

    var ldtkName = Tilemaps.AUTO_LAYERS_5_ADVANCED;

    var level:LdtkLevel;

    var tilemap:Tilemap;

    var intGridLayer:LdtkLayerInstance;

    var painter:IntGridPainter;

    var overlay:IntGridOverlay;

    var hover:Border;

    var layerEntries:Array<LayerEntry> = [];

    var groupEntries:Array<GroupEntry> = [];

    var originalIntGrid:Array<Int>;

    var originalLevelSeed:Int;

    // Panel state

    var valueLabels:Array<String> = [];

    var valueByIndex:Array<Int> = [];

    var paintIndex:Int = 1;

    var brushSize:Int = 1;

    var toolIndex:Int = 0;

    var toolLabels:Array<String> = ['Brush', 'Fill'];

    var showOverlay:Bool = false;

    var partialRecompute:Bool = true;

    var parity:String = '';

    // Recompute stats

    var dirty:Bool = false;

    var lastComputeMs:Float = 0;

    var lastComputeMode:String = '';

    var lastComputeCells:Int = 0;

    var partialTimes:Array<Float> = [];

    var fullTimes:Array<Float> = [];

    var partialCount:Int = 0;

    var fullCount:Int = 0;

    override function preload() {

        assets.add(ldtkName);

    }

    override function create() {

        var ldtkData = assets.ldtk(ldtkName);
        level = ldtkData.worlds[0].levels[0];
        level.ensureLoaded(() -> {
            setupLevel();
        });

    }

    function setupLevel() {

        tilemap = new Tilemap();
        tilemap.depth = 1;
        tilemap.tilemapData = level.ceramicTilemap;
        tilemap.pos(LEVEL_X, LEVEL_Y);
        add(tilemap);

        intGridLayer = level.layerInstance('IntGrid_layer');
        originalIntGrid = intGridLayer.intGrid.copy();
        originalLevelSeed = level.seed;

        // Auto-layers reading our IntGrid, and their rule groups
        for (li in level.layerInstances) {
            var readsIntGrid = (li == intGridLayer) || (li.def.autoSourceLayerDefUid == intGridLayer.def.uid);
            if (readsIntGrid && LdtkRuleRunner.canRun(li)) {
                layerEntries.push(new LayerEntry(li));
                for (group in li.def.ruleLayerDef.groups)
                    groupEntries.push(new GroupEntry(li, group));
            }
        }

        // Palette
        valueLabels.push('Empty');
        valueByIndex.push(0);
        for (v in intGridLayer.def.intGridValues) {
            valueLabels.push(v.identifier != null ? v.identifier : Std.string(v.value));
            valueByIndex.push(v.value);
        }

        overlay = new IntGridOverlay(intGridLayer);
        overlay.depth = 2;
        overlay.pos(LEVEL_X, LEVEL_Y);
        overlay.visible = showOverlay;
        add(overlay);

        var gridSize = intGridLayer.def.gridSize;
        hover = new Border();
        hover.size(gridSize, gridSize);
        hover.borderSize = 1;
        hover.borderColor = Color.WHITE;
        hover.depth = 3;
        hover.visible = false;
        add(hover);

        painter = new IntGridPainter(intGridLayer, tilemap);
        painter.canPaintAt = (x, y) -> !Im.hits(x, y);
        painter.onChange(this, indices -> {
            overlay.updateCells(indices);
            dirty = true;
        });

        input.onKeyDown(this, handleKeyDown);


        applyPartialRecompute();
        checkParity();

    }

    override function update(delta:Float) {

        if (level == null || tilemap == null)
            return;

        painter.paintValue = valueByIndex[paintIndex];
        painter.brushSize = brushSize;
        painter.fillMode = (toolIndex == 1);

        updateHover();
        renderPanel();

        if (dirty)
            recompute();

    }

    function updateHover() {

        if (painter.hoverCx < 0) {
            hover.visible = false;
            return;
        }
        var gridSize = intGridLayer.def.gridSize;
        var size = toolIndex == 1 ? 1 : brushSize;
        var offset = (size - 1) >> 1;
        hover.visible = true;
        hover.size(gridSize * size, gridSize * size);
        hover.pos(LEVEL_X + (painter.hoverCx - offset) * gridSize, LEVEL_Y + (painter.hoverCy - offset) * gridSize);

    }

    /**
     * Recompute every auto-layer reading the IntGrid (once per frame at most)
     */
    function recompute() {

        dirty = false;
        var start = haxe.Timer.stamp();
        LdtkRuleRunner.refreshAutoLayersUsingSource(level, intGridLayer, tilemap);
        lastComputeMs = (haxe.Timer.stamp() - start) * 1000;

        // A single full recompute among the layers makes the whole pass a full one
        var anyFull = false;
        lastComputeCells = 0;
        for (entry in layerEntries) {
            var runner = LdtkRuleRunner.get(entry.layer);
            if (!runner.lastComputeWasPartial)
                anyFull = true;
            lastComputeCells += runner.lastComputeCells;
        }
        lastComputeMode = anyFull ? 'full' : 'partial';
        var times = anyFull ? fullTimes : partialTimes;
        times.push(lastComputeMs);
        if (times.length > STATS_WINDOW)
            times.shift();
        if (anyFull)
            fullCount++;
        else
            partialCount++;

    }

    /**
     * Recompute and compare with the tiles saved by the editor
     */
    function checkParity() {

        recompute();
        var identical = true;
        for (entry in layerEntries) {
            var tiles = entry.layer.autoLayerTiles;
            var baked = entry.bakedTiles;
            if (tiles.length != baked.length) {
                identical = false;
                break;
            }
            for (i in 0...tiles.length) {
                if (tiles[i] != baked[i]) {
                    identical = false;
                    break;
                }
            }
            if (!identical)
                break;
        }
        parity = identical ? 'identical' : 'DIFFERENT';
        log.info('Editor parity: ' + parity);

    }

    function regenerateSeed() {

        level.regenerateSeed();
        dirty = true;

    }

    function resetLevel() {

        for (i in 0...originalIntGrid.length)
            intGridLayer.intGrid[i] = originalIntGrid[i];
        intGridLayer.markIntGridChanged();

        level.seed = originalLevelSeed;
        for (entry in layerEntries)
            entry.layer.seed = entry.originalSeed;

        for (entry in groupEntries) {
            entry.active = entry.originalActive;
            entry.group.active = entry.originalActive;
            LdtkRuleRunner.get(entry.layer).invalidateRules();
        }

        painter.clearHistory();
        overlay.rebuild();
        checkParity();

    }

    function applyPartialRecompute() {

        for (entry in layerEntries)
            LdtkRuleRunner.get(entry.layer).incremental = partialRecompute;

    }

    function setGroupActive(entry:GroupEntry, active:Bool) {

        entry.active = active;
        entry.group.active = active;
        LdtkRuleRunner.get(entry.layer).invalidateRules();
        dirty = true;

    }

    function handleKeyDown(key:Key) {

        if (Im.usesKeyCode(key.keyCode))
            return;

        var modifier = input.keyPressed(KeyCode.LMETA) || input.keyPressed(KeyCode.RMETA) || input.keyPressed(KeyCode.LCTRL) || input.keyPressed(KeyCode.RCTRL);
        var shift = input.keyPressed(KeyCode.LSHIFT) || input.keyPressed(KeyCode.RSHIFT);

        switch key.keyCode {
            case KeyCode.KEY_Z if (modifier):
                if (shift)
                    painter.redo();
                else
                    painter.undo();
            case KeyCode.KEY_R:
                regenerateSeed();
            case KeyCode.KEY_B:
                toolIndex = 0;
            case KeyCode.KEY_F:
                toolIndex = 1;
            case KeyCode.KEY_G:
                showOverlay = !showOverlay;
            case KeyCode.KEY_P:
                partialRecompute = !partialRecompute;
                applyPartialRecompute();
            case _:
                var digit = key.keyCode - KeyCode.KEY_0;
                if (digit >= 0 && digit < valueLabels.length)
                    paintIndex = digit;
        }

    }

    function renderPanel() {

        Im.begin('Live rules', PANEL_WIDTH);
        // Im works in native screen coordinates, not in the scaled scene coordinates
        Im.position(screen.nativeWidth - 4, 4, 1, 0);

        Im.select('Paint', Im.int(paintIndex), valueLabels);
        Im.select('Tool', Im.int(toolIndex), toolLabels);
        Im.slideInt('Brush', Im.int(brushSize), 1, 4);
        if (Im.check('Show IntGrid', Im.bool(showOverlay)).changed || overlay.visible != showOverlay) {
            overlay.visible = showOverlay;
            if (showOverlay)
                overlay.rebuild();
        }
        if (Im.check('Partial recompute', Im.bool(partialRecompute)).changed)
            applyPartialRecompute();

        Im.separator();
        Im.beginRow();
        if (Im.button('New seed'))
            regenerateSeed();
        if (Im.button('Undo', painter.canUndo))
            painter.undo();
        if (Im.button('Redo', painter.canRedo))
            painter.redo();
        Im.endRow();
        if (Im.button('Reset level'))
            resetLevel();

        Im.separator();
        Im.text('Layers');
        Im.beginRow();
        for (entry in layerEntries) {
            if (Im.check(entry.layer.def.identifier, Im.bool(entry.visible)).changed) {
                var tilemapLayer = tilemap.layer(entry.layer.ceramicLayer.name);
                if (tilemapLayer != null)
                    tilemapLayer.visible = entry.visible;
            }
        }
        Im.endRow();

        Im.separator();
        Im.text('Rule groups');
        var i = 0;
        while (i < groupEntries.length) {
            Im.beginRow();
            for (j in i...Std.int(Math.min(i + 2, groupEntries.length))) {
                var entry = groupEntries[j];
                if (Im.check(entry.group.name, Im.bool(entry.active)).changed)
                    setGroupActive(entry, entry.active);
            }
            Im.endRow();
            i += 2;
        }

        Im.separator();
        Im.text('Last: ' + formatMs(lastComputeMs) + ' ms ' + lastComputeMode + ', ' + lastComputeCells + ' cells');
        Im.text('Partial avg ' + formatMs(average(partialTimes)) + ' ms (x' + partialCount + '), Full avg ' + formatMs(average(fullTimes)) + ' ms (x' + fullCount + ')');
        var tiles = '';
        for (entry in layerEntries) {
            if (tiles.length > 0)
                tiles += ', ';
            tiles += entry.layer.def.identifier + ': ' + Std.int(entry.layer.autoLayerTiles.length / 7);
        }
        Im.text('Tiles: ' + tiles);
        Im.text('Editor parity: ' + parity);
        if (painter.hoverCx >= 0) {
            var value = intGridLayer.intGrid[painter.hoverCx + painter.hoverCy * intGridLayer.cWid];
            Im.text('Cell: ' + painter.hoverCx + ', ' + painter.hoverCy + ' = ' + value);
        }
        else {
            Im.text('Cell: -');
        }
        Im.text('Keys: 0-4 value, B brush, F fill, G grid, P partial, R seed, Cmd+Z undo');

        Im.end();

    }

    static function average(values:Array<Float>):Float {

        if (values.length == 0)
            return 0;
        var sum = 0.0;
        for (v in values)
            sum += v;
        return sum / values.length;

    }

    static function formatMs(ms:Float):String {

        return Std.string(Math.round(ms * 100) / 100);

    }

}
