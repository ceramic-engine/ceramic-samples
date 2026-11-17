package;

import ceramic.Platform;
import ceramic.Scene;
import ceramic.Spine;
import haxe.Timer;

using ceramic.SpinePlugin;
using StringTools;

/**
 * CPU cost of the spine plugin, split by phase, for a given scenario.
 *
 * Every spine is updated manually with a fixed time step (autoUpdate = false), so the
 * measured work is identical from one run to another and does not depend on vsync.
 * For each spine update, timestamps are taken from the plugin's own events:
 *
 * - anim:   updateSkeleton -> updateWorldTransform (AnimationState update + apply, skeleton update)
 * - world:  updateWorldTransform -> beginRender (skeleton world transforms)
 * - render: beginRender -> end of update (computing the Ceramic meshes)
 *
 * Environment:
 * - SPINE_BENCH_SCENARIO: scenario name (see `setupScenario()`)
 * - SPINE_BENCH_COUNT: number of spine instances (optional, scenario default otherwise)
 * - SPINE_BENCH_FRAMES: number of measured frames (default 3000)
 * - SPINE_BENCH_CLIPPING: `stencil` or `software`, clipping mode of the spine-haxe runtime
 *   (default: Spine.defaultClipping)
 * - SPINE_BENCH_CONTROL: when set to 1, the spines are created but never updated.
 *   The allocator volume is only increased when a thread claims a new memory range,
 *   so allocations cannot be attributed to a code section within a frame: the
 *   allocations of the spine plugin are the difference between a regular run and
 *   a control run of the same scenario.
 */
class BenchScene extends Scene {

    static inline final DT:Float = 1.0 / 60.0;

    static inline final WARMUP_FRAMES:Int = 120;

    var scenario:String;

    var count:Int;

    var benchFrames:Int;

    var control:Bool = false;

    var spines:Array<Spine> = [];

    var step:Int = 0;

    /** Called every frame with the frame index, to drive scenario specific changes */
    var drive:Int->Void = null;

    // Timestamps set by the spine events during one spine update
    var tSkeleton:Float = 0;
    var tWorld:Float = 0;
    var tRender:Float = 0;

    var animTimes:Array<Float> = [];
    var worldTimes:Array<Float> = [];
    var renderTimes:Array<Float> = [];
    var totalTimes:Array<Float> = [];

    var allocStart:Float = 0;
    var cpuStart:Float = 0;
    var gcCyclesStart:Float = 0;
    var minorPausesStart:Float = 0;

    override function preload() {

        scenario = envString('SPINE_BENCH_SCENARIO', 'mass');
        benchFrames = envInt('SPINE_BENCH_FRAMES', 3000);
        control = envInt('SPINE_BENCH_CONTROL', 0) == 1;
        #if !spine_legacy
        switch envString('SPINE_BENCH_CLIPPING', '') {
            case 'stencil': Spine.defaultClipping = STENCIL;
            case 'software': Spine.defaultClipping = SOFTWARE;
            case _:
        }
        #end

        for (name in skeletonsForScenario(scenario)) {
            assets.addSpine(name);
        }

    }

    override function create() {

        setupScenario();

        var gc = #if HXCPP_GC_CONCURRENT 'CONCURRENT' #elseif HXCPP_GC_GENERATIONAL 'GENERATIONAL' #elseif cpp 'CLASSIC' #else 'NONE' #end;
        var runtime = #if spine_legacy 'legacy' #else 'spine-haxe' #end;
        var clipping = #if spine_legacy 'STENCIL' #else '' + Spine.defaultClipping #end;
        trace('BENCH CONFIG: scenario=$scenario runtime=$runtime count=${spines.length} frames=$benchFrames gc=$gc control=$control clipping=$clipping');
        trace('BENCH DEFINES: ' + BenchConfig.relevantDefines());

        for (spine in spines) {
            spine.autoUpdate = false;
            spine.autoFreeze = false;
            spine.renderWhenInvisible = true;
            spine.onUpdateSkeleton(this, () -> tSkeleton = Timer.stamp());
            spine.onUpdateWorldTransform(this, () -> tWorld = Timer.stamp());
            spine.onBeginRender(this, () -> tRender = Timer.stamp());
        }

        #if cpp
        cpp.vm.Gc.run(true);
        #end

    }

    function setupScenario():Void {

        var rand = new ceramic.SeedRandom(12345);

        inline function spawn(name:String, animation:String, defaultCount:Int):Void {
            count = envInt('SPINE_BENCH_COUNT', defaultCount);
            for (i in 0...count) {
                var spine = new Spine();
                spine.spineData = assets.spine(name);
                spine.skeletonScale = 0.25;
                spine.pos(
                    50 + rand.random() * (screen.width - 100),
                    50 + rand.random() * (screen.height - 100)
                );
                add(spine);
                spine.computeContent();
                // Random start time, so that instances are not all in the same pose
                spine.animate(animation, true, 0, rand.random() * 2.0);
                spines.push(spine);
            }
        }

        switch scenario {

            case 'mass':
                // Meshes, IK, events
                spawn('spineboy-pro', 'run', 300);

            case 'raptor':
                // Weighted meshes, deform, IK
                spawn('raptor-pro', 'walk', 100);

            case 'clipping':
                // Clipping attachment (portal) + meshes
                spawn('spineboy-pro', 'portal', 100);

            case 'clipped-container':
                // Same, inside a container clipped by a rectangle (scissor): clipped slots
                // must stay inside the container
                var container = new ceramic.Quad();
                container.transparent = true;
                container.size(screen.width, screen.height);
                add(container);
                var clipRect = new ceramic.Quad();
                clipRect.size(screen.width - 200, screen.height - 200);
                clipRect.pos(100, 100);
                clipRect.visible = false;
                add(clipRect);
                container.clip = clipRect;
                spawn('spineboy-pro', 'portal', 100);
                for (spine in spines) {
                    remove(spine);
                    container.add(spine);
                }

            case 'path':
                // Path constraints, clipping (tank treads)
                spawn('tank-pro', 'drive', 100);

            case 'vine':
                // Path constraint with many bones
                spawn('vine-pro', 'grow', 100);

            case 'skins':
                // Skin changes and attachment timelines
                spawn('goblins-pro', 'walk', 200);
                drive = step -> {
                    if (step % 30 == 0) {
                        var index = 0;
                        for (spine in spines) {
                            spine.skin = ((step / 30 + index) % 2 == 0) ? 'goblin' : 'goblingirl';
                            index++;
                        }
                    }
                };

            case 'tracks':
                // Several tracks, frequent crossfades, events
                spawn('spineboy-pro', 'run', 200);
                for (spine in spines) {
                    spine.stateData.defaultMix = 0.2;
                    spine.animate('aim', true, 1);
                }
                drive = step -> {
                    if (step % 40 == 0) {
                        var index = 0;
                        for (spine in spines) {
                            var walk = ((step / 40 + index) % 2 == 0);
                            spine.animate(walk ? 'walk' : 'run', true, 0);
                            index++;
                        }
                    }
                    if (step % 25 == 0) {
                        for (spine in spines) {
                            spine.animate('shoot', false, 2);
                        }
                    }
                };

            case 'mixmatch':
                // Many skins and attachments
                spawn('mix-and-match-pro', 'dance', 100);

            default:
                log.error('Unknown scenario: $scenario');
                Sys.exit(1);
        }

    }

    static function skeletonsForScenario(scenario:String):Array<String> {

        return switch scenario {
            case 'mass' | 'clipping' | 'clipped-container' | 'tracks': ['spineboy-pro'];
            case 'raptor': ['raptor-pro'];
            case 'path': ['tank-pro'];
            case 'vine': ['vine-pro'];
            case 'skins': ['goblins-pro'];
            case 'mixmatch': ['mix-and-match-pro'];
            case _: [];
        }

    }

    override function update(delta:Float) {

        if (spines.length == 0)
            return;

        if (drive != null && !control)
            drive(step);

        var measuring = step >= WARMUP_FRAMES;

        if (step == WARMUP_FRAMES) {
            allocStart = allocationVolume();
            cpuStart = Sys.cpuTime();
            gcCyclesStart = gcInfo(100);
            minorPausesStart = gcInfo(107);
        }

        var anim = 0.0;
        var world = 0.0;
        var render = 0.0;
        var t0 = Timer.stamp();

        if (!control) for (i in 0...spines.length) {
            var spine = spines[i];
            var start = Timer.stamp();
            spine.update(DT);
            var end = Timer.stamp();
            anim += tWorld - tSkeleton;
            world += tRender - tWorld;
            render += end - tRender;
        }

        var total = Timer.stamp() - t0;

        if (measuring) {
            animTimes.push(anim * 1000);
            worldTimes.push(world * 1000);
            renderTimes.push(render * 1000);
            totalTimes.push(total * 1000);
        }

        step++;

        if (step >= WARMUP_FRAMES + benchFrames) {
            report();
            Sys.exit(0);
        }

    }

    function report():Void {

        var cpu = Sys.cpuTime() - cpuStart;
        var n = totalTimes.length;

        trace('BENCH anim ms: ' + stats(animTimes));
        trace('BENCH world ms: ' + stats(worldTimes));
        trace('BENCH render ms: ' + stats(renderTimes));
        trace('BENCH total ms: ' + stats(totalTimes));
        trace('BENCH process cpu ms/frame: ' + r3(cpu * 1000 / n));
        #if clay
        // Draw calls of the last rendered frame (the counter is reset at the start of each render)
        trace('BENCH draw calls: ' + @:privateAccess app.backend.draw.renderer.drawCalls);
        #end
        #if cpp
        trace('BENCH alloc whole frame: ' + Std.int((allocationVolume() - allocStart) / n) + ' bytes/frame (compare with a control run)');
        trace('BENCH gc: concurrentCycles=' + Std.int(gcInfo(100) - gcCyclesStart) + ' minorPauses=' + Std.int(gcInfo(107) - minorPausesStart)
            + ' usage=' + Std.int(gcInfo(0) / 1024 / 1024) + 'MB');
        #end
        trace('BENCH DONE');

    }

    static function stats(values:Array<Float>):String {

        var sorted = values.copy();
        sorted.sort((a, b) -> a < b ? -1 : a > b ? 1 : 0);
        var sum = 0.0;
        for (v in sorted) sum += v;
        inline function pc(p:Float):Float {
            return sorted[Std.int(Math.min(sorted.length - 1, Math.floor(p * sorted.length)))];
        }
        return 'mean=' + r3(sum / sorted.length) + ' p50=' + r3(pc(0.50)) + ' p95=' + r3(pc(0.95)) + ' p99=' + r3(pc(0.99)) + ' max=' + r3(sorted[sorted.length - 1]);

    }

    static function r3(v:Float):String {

        return '' + (Math.round(v * 1000) / 1000);

    }

    static function allocationVolume():Float {

        return gcInfo(117);

    }

    static function gcInfo(key:Int):Float {

        #if cpp
        return cpp.vm.Gc.memInfo64(key);
        #else
        return 0;
        #end

    }

    static function envString(name:String, defaultValue:String):String {

        var value = Platform.getEnv(name);
        return value != null && value.trim() != '' ? value.trim() : defaultValue;

    }

    static function envInt(name:String, defaultValue:Int):Int {

        var value = Std.parseInt(envString(name, ''));
        return value != null ? value : defaultValue;

    }

}
