package;

import ceramic.PixelArt;
import ceramic.Scene;
import ceramic.Tilemap;
import ceramic.TilemapData;
import ceramic.TilemapLayerData;
import ceramic.Tileset;
import ceramic.Transform;
import elements.Im;

class MainScene extends Scene {

    var pixelArt:PixelArt;

    var zoom:Float = 1.0;

    override function preload() {

        assets.add(Images.SINGLE_TILE);

    }

    override function create() {

        // Getting pixel art filter back (created in `Project.hx`)
        pixelArt = cast app.scenes.filter;

        createTilemap();

    }

    function createTilemap() {

        // Create our very simple one-tile tileset
        var tileset = new Tileset();
        // 0 = no tile
        // 1 = our single tile
        tileset.firstGid = 1;
        tileset.tileSize(8, 8);
        tileset.texture = assets.texture(Images.SINGLE_TILE);
        tileset.columns = 1;

        // Create our tile layer
        var layerData = new TilemapLayerData();
        layerData.name = 'main';
        layerData.grid(10, 10);
        layerData.tileSize(8, 8);
        layerData.tiles = [
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            1, 0, 1, 1, 1, 0, 0, 1, 1, 1,
            1, 0, 0, 0, 0, 0, 0, 1, 0, 1,
            1, 0, 0, 0, 0, 0, 0, 0, 0, 1,
            1, 0, 0, 1, 1, 1, 0, 0, 0, 1,
            1, 1, 1, 1, 0, 1, 1, 0, 0, 1,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1
        ];

        // Create the tilemap data holding our tile layer
        var tilemapData = new TilemapData();
        tilemapData.size(
            layerData.columns * tileset.tileWidth,
            layerData.rows * tileset.tileHeight
        );
        tilemapData.tilesets = [tileset];
        tilemapData.layers = [layerData];

        // Then create the actual tilemap visual and assign it tilemap data
        var tilemap = new Tilemap();
        tilemap.tilemapData = tilemapData;
        tilemap.pos(8, 8);

        add(tilemap);

    }

    override function update(delta:Float) {

        // Just some settings to see how pixel art rendering
        // looks when changing sharpness and zoom

        Im.begin('Settings', 320);

        Im.slideFloat('Sharpness', Im.float(pixelArt.sharpness), 1, 16, 1);

        if (Im.slideFloat('Zoom', Im.float(zoom), 1, 8, 10)) {
            if (pixelArt.transform == null)
                pixelArt.transform = new Transform();
            pixelArt.transform.identity();
            pixelArt.transform.translate(-8, -8);
            pixelArt.transform.scale(zoom, zoom);
            pixelArt.transform.translate(8, 8);
        }

        Im.end();

    }

}
