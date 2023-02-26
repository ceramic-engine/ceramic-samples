package;

import ceramic.Camera;
import ceramic.Group;
import ceramic.PixelArt;
import ceramic.Scene;
import ceramic.Tilemap;
import ceramic.Timer;
import ceramic.Visual;
import format.tmx.Data.TmxMap;

using ceramic.TilemapPlugin;

class MainScene extends Scene {

    /**
     * The pixel art filter used to render
     * pixel perfect low resolution visuals
     */
    var pixelArt:PixelArt;

    /**
     * The loaded tilemap in ceramic format
     */
    var tilemap:Tilemap;

    /**
     * The original TMX data that comes from Tiled Map Editor.
     * Contains additional data that used to construct the level
     */
    var tmxMap:TmxMap;

    /**
     * The player object we'll control
     */
    var player:Player;

    /**
     * The boxes in the level
     */
    var boxes:Group<Box>;

    /**
     * The camera ajusting the display to follow the player and stop at map bounds
     */
    var camera:Camera;

    override function preload() {

        assets.add(Images.TILES);
        assets.add(Images.CHARACTERS);
        assets.add(Tilemaps.TILEMAP);

    }

    override function create() {

        // Set background color
        color = 0x00A6FF;
        transparent = false;

        // Keep the TMX data around
        tmxMap = assets.tilemapAsset(Tilemaps.TILEMAP).tmxMap;

        // Use NEAREST filtering
        assets.texture(Images.TILES).filter = NEAREST;
        assets.texture(Images.CHARACTERS).filter = NEAREST;

        // Render as low resolution / pixel art
        pixelArt = new PixelArt();
        pixelArt.size(width, height);
        app.scenes.filter = pixelArt;

        initTilemap();
        initPlayer();
        initBoxes();
        initPhysics();
        initCamera();

    }

    function initTilemap() {

        tilemap = new Tilemap();
        tilemap.tilemapData = assets.tilemap(Tilemaps.TILEMAP);
        tilemap.depth = 1;
        add(tilemap);

    }

    function initPlayer() {

        player = new Player(assets);
        player.depth = 10;
        tilemap.add(player);

        var tmxPlayer = findTmxObject('player', 'objects');
        player.pos(
            tmxPlayer.x,
            tmxPlayer.y
        );

    }

    function initBoxes() {

        boxes = new Group('boxes');

        for (tmxBox in findTmxObjects('box', 'objects')) {
            var box = new Box(assets);
            box.pos(
                tmxBox.x,
                tmxBox.y
            );
            box.depth = 2;
            tilemap.add(box);
            boxes.add(box);
        }

    }

    function initPhysics() {

        // We don't want Ceramic to update world bounds from screen.
        // Instead, if set world bounds to match tilemap size
        app.arcade.autoUpdateWorldBounds = false;
        app.arcade.world.setBounds(
            0, 0, tilemap.width, tilemap.height
        );

        // Mark the layer named `collidable` as... collidable!
        tilemap.initArcadePhysics();
        tilemap.collidableLayers = ['collidable-up', 'collidable']; // The order matters

        // Only check collision with `collidable-up` layer
        // when the player is falling down
        tilemap.layer('collidable-up').checkCollision(true, false, false, false);

        // Bind our physics update callback to setup our custom collisions
        app.arcade.onUpdate(this, updatePhysics);

    }

    function updatePhysics(delta:Float) {

        var world = app.arcade.world;

        player.updatePhysics(delta, world, tilemap, boxes);

    }

    function initCamera() {

        // Configure camera
        camera = new Camera();

        // We tweak some camera settings to make it work
        // better with our low-res pixel art display
        camera.movementThreshold = 0.5;
        camera.trackSpeedX = 40;
        camera.trackCurve = 1;
        camera.brakeNearBounds(0, 0);

        // We update the camera after everything else has been updated
        // so that we are sure it won't be based on some intermediate state
        app.onPostUpdate(this, updateCamera);

        // Update the camera once right away
        // (we use a very big delta so that it starts at a stable position)
        updateCamera(99999);

    }

    function updateCamera(delta:Float) {

        // Tell the camera what is the size of the viewport
        camera.viewportWidth = width;
        camera.viewportHeight = height;

        // Tell the camera what is the size and position of the content
        camera.contentX = 0;
        camera.contentY = 0;
        camera.contentWidth = tilemap.tilemapData.width;
        camera.contentHeight = tilemap.tilemapData.height;

        // Tell the camera what position to target (the player's position)
        camera.followTarget = true;
        camera.targetX = player.x;
        camera.targetY = player.y;

        // Then, let the camera handle these infos
        // so that it updates itself accordingly
        camera.update(delta);

        // Now that the camera has updated,
        // set the content position from the computed data
        tilemap.x = camera.contentTranslateX;
        tilemap.y = camera.contentTranslateY;

        // Update tile clipping
        // (disables tiles that are outside viewport)
        tilemap.clipTiles(
            Math.floor(camera.x - camera.viewportWidth * 0.5),
            Math.floor(camera.y - camera.viewportHeight * 0.5),
            Math.ceil(camera.viewportWidth) + tilemap.tilemapData.maxTileWidth,
            Math.ceil(camera.viewportHeight) + tilemap.tilemapData.maxTileHeight
        );

    }

/// Helpers

    /**
     * A helper to find an object from TMX data
     * @param name The name of the object we are looking for
     * @param layer (optional) The name of the layer containing the object in TMX data
     */
    function findTmxObject(name:String, ?layer:String) {

        for (layerData in tmxMap.layers) {
            switch layerData {
                default:
                case LObjectGroup(group):
                    if (layer == null || group.name == layer) {
                        for (obj in group.objects) {
                            if (obj.name == name) {
                                return obj;
                            }
                        }
                    }
            }
        }

        return null;

    }

    /**
     * A helper to find a list of objects from TMX data
     * @param name The name of the objects we are looking for
     * @param layer (optional) The name of the layer containing the object in TMX data
     */
    function findTmxObjects(name:String, ?layer:String) {

        var result = [];

        for (layerData in tmxMap.layers) {
            switch layerData {
                default:
                case LObjectGroup(group):
                    if (layer == null || group.name == layer) {
                        for (obj in group.objects) {
                            if (obj.name == name) {
                                result.push(obj);
                            }
                        }
                    }
            }
        }

        return result;

    }

}
