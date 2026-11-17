package;

import haxe.Timer;
import sys.io.File;

#if spine_legacy
import spine.*;
import spine.attachments.*;
import spine.support.graphics.TextureAtlas;
import spine.support.graphics.TextureLoader;
import spine.support.utils.JsonValue;
#else
import spine.*;
import spine.animation.*;
import spine.atlas.*;
import spine.attachments.*;
#end

#if spine_legacy
class NoTextureLoader implements TextureLoader {
    public function new() {}
    public function loadPage(page:AtlasPage, path:String):Void {}
    public function loadRegion(region:AtlasRegion):Void {}
    public function unloadPage(page:AtlasPage):Void {}
}
#else
class NoTextureLoader implements TextureLoader {
    public function new() {}
    public function loadPage(page:TextureAtlasPage, path:String):Void { page.texture = {}; }
    public function loadRegion(region:TextureAtlasRegion):Void {}
    public function unloadPage(page:TextureAtlasPage):Void {}
}
#end

/**
 * Spine runtime only benchmark (no Ceramic, no rendering), for targets where the
 * Ceramic app cannot run headless (node for JS): N skeletons updated with a fixed
 * time step, timed by phase.
 *
 * - anim: AnimationState update and apply
 * - world: world transforms (and physics)
 * - vertices: world vertices of every region and mesh attachment (what a renderer computes)
 *
 * Usage: RuntimeBench <data-dir> <skeleton> <animation> <count> <frames>
 */
class RuntimeBench {

    static inline final DT:Float = 1.0 / 60.0;

    static function main() {

        var args = Sys.args();
        var dir = args[0] + '/' + args[1] + '.spine';
        var skeletonName = args[1];
        var animationName = args[2];
        var count = Std.parseInt(args[3]);
        var frames = Std.parseInt(args[4]);

        var atlasFile = null;
        for (f in sys.FileSystem.readDirectory(dir)) if (StringTools.endsWith(f, '.atlas')) atlasFile = f;
        var atlas = new TextureAtlas(File.getContent(dir + '/' + atlasFile), new NoTextureLoader());
        var json = File.getContent(dir + '/' + skeletonName + '.json');

        var loadStart = Timer.stamp();
        #if spine_legacy
        var data = new SkeletonJson(new AtlasAttachmentLoader(atlas)).readSkeletonData(new JsonDynamic(haxe.Json.parse(json)));
        #else
        var data = new SkeletonJson(new AtlasAttachmentLoader(atlas)).readSkeletonData(json);
        #end
        var loadMs = (Timer.stamp() - loadStart) * 1000;

        var skeletons = [];
        var states = [];
        var seed = 12345;
        for (i in 0...count) {
            var skeleton = new Skeleton(data);
            var state = new AnimationState(new AnimationStateData(data));
            var entry = state.setAnimation(0, data.findAnimation(animationName), true);
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            entry.trackTime = (seed % 2000) / 1000.0;
            skeletons.push(skeleton);
            states.push(state);
        }

        var buffer = new Array<Float>();
        var anim = [];
        var world = [];
        var vertices = [];
        var total = [];
        var warmup = 120;

        for (frame in 0...(warmup + frames)) {
            var a = 0.0, w = 0.0, v = 0.0;
            var t0 = Timer.stamp();
            for (i in 0...count) {
                var skeleton = skeletons[i];
                var state = states[i];
                var s0 = Timer.stamp();
                #if spine_legacy
                skeleton.update(DT);
                state.update(DT);
                state.apply(skeleton);
                #else
                state.update(DT);
                state.apply(skeleton);
                skeleton.update(DT);
                #end
                var s1 = Timer.stamp();
                #if spine_legacy
                skeleton.updateWorldTransform();
                #else
                skeleton.updateWorldTransform(Physics.update);
                #end
                var s2 = Timer.stamp();
                computeVertices(skeleton, buffer);
                var s3 = Timer.stamp();
                a += s1 - s0;
                w += s2 - s1;
                v += s3 - s2;
            }
            var t = Timer.stamp() - t0;
            if (frame >= warmup) {
                anim.push(a * 1000);
                world.push(w * 1000);
                vertices.push(v * 1000);
                total.push(t * 1000);
            }
        }

        var runtime = #if spine_legacy 'legacy' #else 'spine-haxe' #end;
        Sys.println('BENCH CONFIG: runtime=$runtime target=' + #if js 'js' #elseif cpp 'cpp' #else 'other' #end + ' skeleton=$skeletonName animation=$animationName count=$count frames=$frames');
        Sys.println('BENCH load ms: ' + r3(loadMs));
        Sys.println('BENCH anim ms: ' + stats(anim));
        Sys.println('BENCH world ms: ' + stats(world));
        Sys.println('BENCH vertices ms: ' + stats(vertices));
        Sys.println('BENCH total ms: ' + stats(total));
        Sys.println('BENCH DONE');

    }

    static function computeVertices(skeleton:Skeleton, buffer:Array<Float>):Void {

        #if spine_legacy
        var drawOrder = skeleton.drawOrder;
        for (i in 0...drawOrder.length) {
            var slot = drawOrder[i];
            var attachment = slot.attachment;
            if (Std.isOfType(attachment, RegionAttachment)) {
                var region:RegionAttachment = cast attachment;
                region.computeWorldVertices(slot.bone, buffer, 0, 2);
            }
            else if (Std.isOfType(attachment, MeshAttachment)) {
                var mesh:MeshAttachment = cast attachment;
                mesh.computeWorldVertices(slot, 0, mesh.getWorldVerticesLength(), buffer, 0, 2);
            }
        }
        #else
        var drawOrder = skeleton.drawOrder.appliedPose;
        for (i in 0...drawOrder.length) {
            var slot = drawOrder[i];
            if (!slot.bone.active) continue;
            var pose = slot.appliedPose;
            var attachment = pose.attachment;
            if (Std.isOfType(attachment, RegionAttachment)) {
                var region:RegionAttachment = cast attachment;
                region.computeWorldVertices(slot, region.getOffsets(pose), buffer, 0, 2);
            }
            else if (Std.isOfType(attachment, MeshAttachment)) {
                var mesh:MeshAttachment = cast attachment;
                mesh.computeWorldVertices(skeleton, slot, 0, mesh.worldVerticesLength, buffer, 0, 2);
            }
        }
        #end

    }

    static function stats(values:Array<Float>):String {

        var sorted = values.copy();
        sorted.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        var sum = 0.0;
        for (v in sorted) sum += v;
        return 'mean=' + r3(sum / sorted.length) + ' p50=' + r3(sorted[Std.int(sorted.length * 0.5)]) + ' p95=' + r3(sorted[Std.int(sorted.length * 0.95)]) + ' p99=' + r3(sorted[Std.int(sorted.length * 0.99)]) + ' max=' + r3(sorted[sorted.length - 1]);

    }

    static function r3(v:Float):String {

        return '' + (Math.round(v * 1000) / 1000);

    }

}
