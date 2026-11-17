package;

import ceramic.Mesh;
import ceramic.Quad;
import ceramic.Visual;
import ceramic.Platform;
import ceramic.Scene;
import ceramic.Shape;
import ceramic.Spine;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using ceramic.SpinePlugin;
using StringTools;

/**
 * Plays every animation of every Spine skeleton found in the assets with a fixed
 * time step, and dumps what the spine plugin sends to the renderer (meshes,
 * clip shapes, events) at a few frames.
 *
 * The output is meant to be compared byte for byte between two builds (legacy
 * golden files), or converted and compared with an official reference runtime.
 *
 * Environment:
 * - SPINE_CONFORMANCE_OUT: output directory (required)
 * - SPINE_CONFORMANCE_ONLY: optional comma separated list of skeleton names
 * - SPINE_CONFORMANCE_EXCLUDE: optional comma separated list of skeleton names to skip
 * - SPINE_CONFORMANCE_FPS: optional number of fixed steps per second (default 30)
 * - SPINE_CONFORMANCE_LEVEL_A: directory of level A scenarios (tools/make-scenarios.py):
 *   plays them with the spine runtime only (spine-haxe), writes the results to
 *   SPINE_CONFORMANCE_OUT and exits
 * - SPINE_CONFORMANCE_CLIPPING: `stencil` to render clipping attachments with the stencil buffer
 *   (default: the default clipping of the runtime)
 */
class ConformanceScene extends Scene {

    /**
     * Fixed time step used to advance animations: 1/30 s by default (legacy golden files),
     * or SPINE_CONFORMANCE_FPS steps per second. Level B comparisons use 31, so that sampled
     * times never fall exactly on keyframes (exported at 30 fps), where float rounding
     * differences between runtimes pick a different side of the keyframe.
     */
    static var DT:Float = 1.0 / 30.0;

    /** Number of fixed steps played per animation */
    static inline final STEPS:Int = 30;

    /** Frames (number of steps already played) at which a dump is written */
    static final DUMP_FRAMES:Array<Int> = [0, 1, 7, 15, 30];

    var outDir:String;

    var skeletons:Array<String> = [];

    var runs:Array<Run> = [];

    var step:Int = -1;

    var bindings:BindingsScenario = null;

    var boundingBox:BoundingBoxScenario = null;

    override function preload() {

        outDir = Platform.getEnv('SPINE_CONFORMANCE_OUT');
        if (outDir == null || outDir.trim() == '') {
            log.error('SPINE_CONFORMANCE_OUT is not set');
            Sys.exit(1);
        }

        if (Platform.getEnv('SPINE_CONFORMANCE_CLIPPING') == 'stencil') {
            Spine.defaultClipping = STENCIL;
        }

        var fpsEnv = Std.parseInt(Platform.getEnv('SPINE_CONFORMANCE_FPS'));
        if (fpsEnv != null && fpsEnv > 0) {
            DT = 1.0 / fpsEnv;
        }

        var only:Array<String> = null;
        var onlyEnv = Platform.getEnv('SPINE_CONFORMANCE_ONLY');
        if (onlyEnv != null && onlyEnv.trim() != '') {
            only = [for (name in onlyEnv.split(',')) name.trim()];
        }

        var exclude:Array<String> = [];
        var excludeEnv = Platform.getEnv('SPINE_CONFORMANCE_EXCLUDE');
        if (excludeEnv != null && excludeEnv.trim() != '') {
            exclude = [for (name in excludeEnv.split(',')) name.trim()];
        }

        for (dir in ceramic.Assets.allDirs) {
            if (dir.endsWith('.spine')) {
                var name = dir.substr(0, dir.length - '.spine'.length);
                if ((only == null || only.indexOf(name) != -1) && exclude.indexOf(name) == -1) {
                    skeletons.push(name);
                }
            }
        }
        skeletons.sort(Reflect.compare);

        for (name in skeletons) {
            assets.addSpine(name);
        }

        // Never stay alive when an asset fails to load
        assets.onceComplete(this, success -> {
            if (!success) {
                log.error('Spine conformance: failed to load assets');
                Sys.exit(1);
            }
        });

    }

    override function create() {

        #if !spine_legacy
        var levelA = Platform.getEnv('SPINE_CONFORMANCE_LEVEL_A');
        if (levelA != null && levelA.trim() != '') {
            var count = LevelAScenarios.run(levelA, outDir, name -> skeletons.indexOf(name) != -1 ? assets.spine(name) : null);
            log.success('Spine conformance level A: $count scenario(s) written to $outDir');
            Sys.exit(0);
        }
        #end

        for (name in skeletons) {
            var spineData = assets.spine(name);
            if (spineData == null) {
                log.error('Failed to load spine data: $name');
                Sys.exit(1);
            }
            var animationNames = [for (animation in spineData.skeletonData.animations) animation.name];
            animationNames.sort(Reflect.compare);
            for (animationName in animationNames) {
                runs.push(new Run(name, animationName, spineData));
            }
        }

        log.info('Spine conformance: ${skeletons.length} skeleton(s), ${runs.length} animation run(s)');

        for (run in runs) {
            run.spine.autoUpdate = false;
            run.spine.renderWhenInvisible = true;
            run.spine.pos(screen.width * 0.5, screen.height * 0.5);
            add(run.spine);
            run.spine.onSpineEvent(this, (entry, event) -> {
                run.events.push({
                    step: step,
                    track: entry.trackIndex,
                    name: #if spine_legacy event.getData().name #else event.data.name #end,
                    time: event.time,
                    intValue: event.intValue,
                    floatValue: event.floatValue,
                    stringValue: event.stringValue
                });
            });
            run.spine.onComplete(this, () -> {
                run.events.push({ step: step, track: 0, name: '<complete>', time: 0, intValue: 0, floatValue: 0, stringValue: null });
            });
        }

        if (skeletons.indexOf('spineboy-pro') != -1) {
            bindings = new BindingsScenario(assets.spine('spineboy-pro'));
            add(bindings.root);
            add(bindings.slotHitSpine);
            add(bindings.colorsSpine);
            // SPINE_CONFORMANCE_SKIP_BBOX=1: skip bounding boxes (they crashed the legacy plugin before it was fixed)
            if (Platform.getEnv('SPINE_CONFORMANCE_SKIP_BBOX') != '1') {
                boundingBox = new BoundingBoxScenario(assets.spine('spineboy-pro'));
                add(boundingBox.spine);
            }
        }

        // Start every animation, then advance one fixed step per app frame, so that
        // deferred callbacks (immediate callbacks, scheduled renders) run between steps
        // the same way as in a regular app.
        for (run in runs) {
            run.spine.computeContent();
            run.spine.animate(run.animation, true);
        }
        step = 0;

    }

    override function update(delta:Float) {

        if (step < 0)
            return;

        if (step > 0) {
            for (run in runs) {
                run.spine.update(DT);
            }
            if (bindings != null) {
                bindings.update(DT);
            }
            if (boundingBox != null) {
                boundingBox.update(DT);
            }
        }

        if (DUMP_FRAMES.indexOf(step) != -1) {
            for (run in runs) {
                run.frames.push(dumpSpine(run.spine, step));
            }
            if (bindings != null) {
                bindings.frames.push(bindings.dump(step, step * DT));
            }
            if (boundingBox != null) {
                boundingBox.frames.push(boundingBox.dump(step, step * DT));
            }
        }

        if (step >= STEPS) {
            writeResults();
            log.success('Spine conformance dump written to $outDir');
            Sys.exit(0);
        }

        step++;

    }

    function dumpSpine(spine:Spine, step:Int):Dynamic {

        return {
            step: step,
            time: step * DT,
            visuals: dumpChildren(spine)
        };

    }

    /**
     * Dump the children of a visual, recursively for child spines,
     * with everything that affects how they are rendered.
     */
    public static function dumpChildren(parent:Visual):Array<Dynamic> {

        var visuals:Array<Dynamic> = [];
        var index = 0;
        var children = parent.children != null ? parent.children.original : [];
        for (child in children) {
            var kind = Std.isOfType(child, Spine) ? 'spine' : Std.isOfType(child, Shape) ? 'shape' : Std.isOfType(child, Mesh) ? 'mesh' : Std.isOfType(child, Quad) ? 'quad' : Type.getClassName(Type.getClass(child));
            var item:Dynamic = {
                index: index++,
                kind: kind,
                visible: child.visible,
                active: child.active,
                depth: child.depth,
                depthRange: child.depthRange,
                blending: (child.blending:Int),
                alpha: child.alpha,
                x: child.x,
                y: child.y,
                scaleX: child.scaleX,
                scaleY: child.scaleY
            };
            var transform = child.transform;
            if (transform != null) {
                item.transform = [transform.a, transform.b, transform.c, transform.d, transform.tx, transform.ty];
            }
            if (child.clip != null) {
                item.clip = children.indexOf(child.clip);
            }
            if (child.shader != null) {
                item.shader = child.shader.asset != null ? child.shader.asset.path : 'custom';
            }
            if (Std.isOfType(child, Mesh)) {
                var mesh:Mesh = cast child;
                item.colorMapping = Std.string(mesh.colorMapping);
                item.customFloatAttributesSize = mesh.customFloatAttributesSize;
                item.texture = textureName(mesh.texture);
                item.vertices = mesh.vertices.copy();
                item.uvs = mesh.uvs != null ? mesh.uvs.copy() : null;
                item.indices = mesh.indices != null ? mesh.indices.copy() : null;
                item.colors = mesh.colors != null ? [for (color in mesh.colors) (color:Int)] : null;
            }
            else if (Std.isOfType(child, Quad)) {
                var quad:Quad = cast child;
                item.color = (quad.color:Int);
                item.width = quad.width;
                item.height = quad.height;
                item.texture = textureName(quad.texture);
            }
            if (Std.isOfType(child, Spine)) {
                item.children = dumpChildren(child);
            }
            visuals.push(item);
        }
        return visuals;

    }

    static function textureName(texture:ceramic.Texture):String {

        return texture == null ? null : texture.asset != null ? texture.asset.path : texture.id;

    }

    function writeResults():Void {

        for (run in runs) {
            var dir = Path.join([outDir, run.skeleton]);
            if (!FileSystem.exists(dir))
                FileSystem.createDirectory(dir);
            var content = haxe.Json.stringify({
                skeleton: run.skeleton,
                animation: run.animation,
                dt: DT,
                frames: run.frames,
                events: run.events
            }, null, ' ');
            File.saveContent(Path.join([dir, safeName(run.animation) + '.json']), content);
        }

        if (bindings != null) {
            var dir = Path.join([outDir, '_bindings']);
            if (!FileSystem.exists(dir))
                FileSystem.createDirectory(dir);
            File.saveContent(Path.join([dir, 'spineboy-pro.json']), haxe.Json.stringify({
                dt: DT,
                frames: bindings.frames,
                events: bindings.events
            }, null, ' '));
        }

        if (boundingBox != null) {
            var dir = Path.join([outDir, '_bbox']);
            if (!FileSystem.exists(dir))
                FileSystem.createDirectory(dir);
            File.saveContent(Path.join([dir, 'spineboy-pro.json']), haxe.Json.stringify({
                dt: DT,
                frames: boundingBox.frames
            }, null, ' '));
        }

    }

    static function safeName(name:String):String {

        var result = new StringBuf();
        for (i in 0...name.length) {
            var c = name.charCodeAt(i);
            var ok = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '-'.code || c == '_'.code;
            result.addChar(ok ? c : '_'.code);
        }
        return result.toString();

    }

}

class Run {

    public var skeleton:String;

    public var animation:String;

    public var spine:Spine;

    public var frames:Array<Dynamic> = [];

    public var events:Array<Dynamic> = [];

    public function new(skeleton:String, animation:String, spineData:ceramic.SpineData) {

        this.skeleton = skeleton;
        this.animation = animation;
        spine = new Spine();
        spine.spineData = spineData;

    }

}
