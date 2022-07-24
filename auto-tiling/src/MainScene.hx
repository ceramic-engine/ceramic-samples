package;

import ceramic.AutoTiler;
import ceramic.PixelArt;
import ceramic.Scene;
import ceramic.Tilemap;
import ceramic.TilemapData;
import ceramic.TilemapEditor;
import ceramic.TilemapLayerData;
import ceramic.Tileset;

class MainScene extends Scene {

    var pixelArt:PixelArt;

    override function preload() {

        assets.add(Images.AUTOTILE_GRASS);

    }

    override function create() {

        // Render as low resolution / pixel art
        pixelArt = new PixelArt();
        pixelArt.size(width, height);
        app.scenes.filter = pixelArt;

        createTilemap();

    }

    function createTilemap() {

        // Create our very simple one-tile tileset
        var tileset = new Tileset();
        // 0 = no tile
        // 1 = our single tile
        tileset.firstGid = 1;
        tileset.tileSize(8, 8);
        tileset.texture = assets.texture(Images.AUTOTILE_GRASS);
        tileset.columns = 16;

        // Create our tile layer
        var layerData = new TilemapLayerData();
        layerData.name = 'main';
        layerData.size(20, 16);
        layerData.tiles = [
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0,
            0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0,
            0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 1, 0, 0,
            0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 0,
            0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
        ];

        // Enable auto-tiling
        layerData.component(new AutoTiler([
            EXPANDED_48 // The kind of auto-tiling to use
        ], [
            1 // The corresponding "first gid" to apply auto-tiling on
        ]));

        // Create the tilemap data holding our tile layer
        var tilemapData = new TilemapData();
        tilemapData.tileSize(8, 8);
        tilemapData.size(layerData.width, layerData.height);
        tilemapData.tilesets = [tileset];
        tilemapData.layers = [layerData];

        // Then create the actual tilemap visual and assign it tilemap data
        var tilemap = new Tilemap();
        tilemap.tilemapData = tilemapData;

        // Make this tilemap editable
        tilemap.component(new TilemapEditor('main', 1, 0));

        add(tilemap);

    }

}
