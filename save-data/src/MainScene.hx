package;

import ceramic.Color;
import ceramic.PersistentData;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Text;
import ceramic.TouchInfo;

class MainScene extends Scene {

    /**
     * The colors the player can paint with
     */
    static final COLORS:Array<Color> = [
        0xE84855, 0xF9DC5C, 0x3185FC, 0x5FAD56, 0xF2652F, 0x9B5DE5, 0xFFFFFF
    ];

    /**
     * Our save file. On desktop it is stored on disk,
     * on web it uses the browser's local storage.
     */
    var saveData:PersistentData;

    var launches:Int;

    var cells:Array<Quad> = [];

    var gridSize:Int = 8;

    var selectedColor:Int = 0;

    var swatches:Array<Quad> = [];

    override function create() {

        // Load (or create) the persistent data identified by 'save-data-sample'
        saveData = new PersistentData('save-data-sample');

        // Count how many times the app was launched
        launches = saveData.exists('launches') ? saveData.get('launches') : 0;
        launches++;
        saveData.set('launches', launches);
        saveData.save();

        var info = new Text();
        info.content = 'This app was launched ' + launches + ' time' + (launches > 1 ? 's' : '') + ' on this device.';
        info.pointSize = 16;
        info.color = Color.WHITE;
        info.anchor(0.5, 0);
        info.pos(width * 0.5, 24);
        add(info);

        var hint = new Text();
        hint.content = 'Paint some pixels, then reload the page: the drawing is saved.';
        hint.pointSize = 12;
        hint.color = Color.GRAY;
        hint.anchor(0.5, 0);
        hint.pos(width * 0.5, 52);
        add(hint);

        createGrid();
        createSwatches();

        // Reset button
        var reset = new Text();
        reset.content = '[ reset drawing ]';
        reset.pointSize = 14;
        reset.color = Color.GRAY;
        reset.anchor(0.5, 1);
        reset.pos(width * 0.5, height - 20);
        add(reset);
        reset.onPointerDown(this, _ -> {
            saveData.remove('pixels');
            saveData.save();
            var pixels = emptyPixels();
            for (i in 0...cells.length) {
                applyPixel(cells[i], pixels[i]);
            }
        });

    }

    function emptyPixels():Array<Int> {

        return [for (_ in 0...gridSize * gridSize) -1];

    }

    function createGrid() {

        // Restore the saved drawing if any
        var pixels:Array<Int> = saveData.exists('pixels') ? saveData.get('pixels') : emptyPixels();

        var cellSize = 36.0;
        var gridWidth = gridSize * cellSize;
        var startX = (width - gridWidth) * 0.5;
        var startY = 90.0;

        for (i in 0...gridSize * gridSize) {

            var cell = new Quad();
            cell.size(cellSize - 2, cellSize - 2);
            cell.pos(
                startX + (i % gridSize) * cellSize,
                startY + Math.floor(i / gridSize) * cellSize
            );
            applyPixel(cell, pixels[i]);
            add(cell);
            cells.push(cell);

            var index = i;
            cell.onPointerDown(this, _ -> paintCell(index));

        }

    }

    function applyPixel(cell:Quad, value:Int) {

        cell.color = value >= 0 ? COLORS[value] : 0x222228;

    }

    function paintCell(index:Int) {

        // Update the visual
        applyPixel(cells[index], selectedColor);

        // Then persist the whole drawing
        var pixels:Array<Int> = saveData.exists('pixels') ? saveData.get('pixels') : emptyPixels();
        pixels[index] = selectedColor;
        saveData.set('pixels', pixels);
        saveData.save();

    }

    function createSwatches() {

        var swatchSize = 28.0;
        var startX = (width - COLORS.length * (swatchSize + 8)) * 0.5;
        var y = 90.0 + gridSize * 36.0 + 20;

        for (i in 0...COLORS.length) {

            var swatch = new Quad();
            swatch.size(swatchSize, swatchSize);
            swatch.color = COLORS[i];
            swatch.pos(startX + i * (swatchSize + 8), y);
            add(swatch);
            swatches.push(swatch);

            var index = i;
            swatch.onPointerDown(this, _ -> selectColor(index));

        }

        selectColor(0);

    }

    function selectColor(index:Int) {

        selectedColor = index;

        // Highlight the selected swatch
        for (i in 0...swatches.length) {
            swatches[i].alpha = (i == index) ? 1 : 0.4;
        }

    }

}
