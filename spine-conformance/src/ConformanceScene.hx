package;

import ceramic.Mesh;
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
 */
class ConformanceScene extends Scene {

    /** Fixed time step used to advance animations */
    static inline final DT:Float = 1.0 / 30.0;

    /** Number of fixed steps played per animation */
    static inline final STEPS:Int = 30;

    /** Frames (number of steps already played) at which a dump is written */
    static final DUMP_FRAMES:Array<Int> = [0, 1, 7, 15, 30];

    var outDir:String;

    var skeletons:Array<String> = [];

    var runs:Array<Run> = [];

    var step:Int = -1;

    override function preload() {

        outDir = Platform.getEnv('SPINE_CONFORMANCE_OUT');
        if (outDir == null || outDir.trim() == '') {
            log.error('SPINE_CONFORMANCE_OUT is not set');
            Sys.exit(1);
        }

        var only:Array<String> = null;
        var onlyEnv = Platform.getEnv('SPINE_CONFORMANCE_ONLY');
        if (onlyEnv != null && onlyEnv.trim() != '') {
            only = [for (name in onlyEnv.split(',')) name.trim()];
        }

        for (dir in ceramic.Assets.allDirs) {
            if (dir.endsWith('.spine')) {
                var name = dir.substr(0, dir.length - '.spine'.length);
                if (only == null || only.indexOf(name) != -1) {
                    skeletons.push(name);
                }
            }
        }
        skeletons.sort(Reflect.compare);

        for (name in skeletons) {
            assets.addSpine(name);
        }

    }

    override function create() {

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
        }

        if (DUMP_FRAMES.indexOf(step) != -1) {
            for (run in runs) {
                run.frames.push(dumpSpine(run.spine, step));
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

        var visuals:Array<Dynamic> = [];
        var index = 0;
        var children = spine.children != null ? spine.children.original : [];
        for (child in children) {
            var item:Dynamic = {
                index: index++,
                kind: Std.isOfType(child, Shape) ? 'shape' : Std.isOfType(child, Mesh) ? 'mesh' : Type.getClassName(Type.getClass(child)),
                visible: child.visible,
                depth: child.depth,
                blending: (child.blending:Int),
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
                item.texture = mesh.texture == null ? null : mesh.texture.asset != null ? mesh.texture.asset.path : mesh.texture.id;
                item.vertices = mesh.vertices.copy();
                item.uvs = mesh.uvs.copy();
                item.indices = mesh.indices.copy();
                item.colors = [for (color in mesh.colors) (color:Int)];
            }
            visuals.push(item);
        }

        return {
            step: step,
            time: step * DT,
            visuals: visuals
        };

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
