package;

import ceramic.Scene;
import ceramic.Tilemap;

using ceramic.TilemapPlugin;

class MainScene extends Scene {

    var ldtkName = Tilemaps.WORLD_MAP_GRID_VANIA_LAYOUT;

    override function preload() {

        assets.add(ldtkName);

    }

    override function create() {

        var tilemap:Tilemap = null;

        var ldtkData = assets.ldtk(ldtkName);
        var level = ldtkData.worlds[0].levels[0];

        level.ensureLoaded(() -> {

            // ensureLoaded() wrapping is only needed when using external levels,
            // but can still be used on any LDtk project too

            // Create and display tilemap
            tilemap = new Tilemap();
            tilemap.depth = 1;
            tilemap.tilemapData = level.ceramicTilemap;
            add(tilemap);

            // Also create visuals for applicable entities
            level.createVisualsForEntities(tilemap);

        });

    }

}
