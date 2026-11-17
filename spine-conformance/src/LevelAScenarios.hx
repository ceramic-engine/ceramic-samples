package;

#if !spine_legacy

import ceramic.SpineData;
import haxe.Json;
import haxe.io.Path;
import spine.Physics;
import spine.Skeleton;
import spine.animation.AnimationState;
import spine.animation.AnimationStateData;
import spine.animation.TrackEntry;
import sys.FileSystem;
import sys.io.File;

/**
 * Level A: plays the scenarios of tools/make-scenarios.py with the spine-haxe runtime,
 * built with the flags of a Ceramic app, and writes the skeleton state at the snapshot
 * steps, in the same format as reference-java/src/ScenarioRunner.java.
 */
class LevelAScenarios {

    public static function run(scenariosDir:String, outputDir:String, spineDataFor:String->SpineData):Int {

        if (!FileSystem.exists(outputDir))
            FileSystem.createDirectory(outputDir);

        var files = FileSystem.readDirectory(scenariosDir);
        files.sort(Reflect.compare);
        var count = 0;
        for (file in files) {
            if (!StringTools.endsWith(file, '.json')) continue;
            var scenario:Dynamic = Json.parse(File.getContent(Path.join([scenariosDir, file])));
            var spineData = spineDataFor(scenario.skeleton);
            if (spineData == null) continue;
            File.saveContent(Path.join([outputDir, file]), runScenario(scenario, spineData));
            count++;
        }
        return count;

    }

    static function runScenario(scenario:Dynamic, spineData:SpineData):String {

        var data = spineData.skeletonData;
        var skeleton = new Skeleton(data);
        var stateData = new AnimationStateData(data);
        stateData.defaultMix = scenario.defaultMix != null ? scenario.defaultMix : 0;
        var state = new AnimationState(stateData);
        skeleton.setupPose();
        skeleton.updateWorldTransform(Physics.pose);

        var dt:Float = scenario.dt;
        var steps:Int = scenario.steps;
        var snapshots:Array<Int> = scenario.snapshots;
        var actions:Array<Dynamic> = scenario.actions;

        var out = new StringBuf();
        out.add('{"skeleton":' + Json.stringify(scenario.skeleton) + ',"scenario":' + Json.stringify(scenario.name) + ',"snapshots":[');
        var firstSnapshot = true;

        for (step in 0...steps + 1) {
            for (action in actions) {
                if (action.step != step) continue;
                apply(action, skeleton, state);
            }
            if (step > 0) {
                state.update(dt);
                state.apply(skeleton);
                skeleton.update(dt);
                skeleton.updateWorldTransform(Physics.update);
            }
            else {
                state.update(0);
                state.apply(skeleton);
                skeleton.update(0);
                skeleton.updateWorldTransform(Physics.pose);
            }
            if (snapshots.indexOf(step) != -1) {
                if (!firstSnapshot) out.add(',');
                firstSnapshot = false;
                snapshot(out, skeleton, step);
            }
        }
        out.add(']}\n');
        return out.toString();

    }

    static function apply(action:Dynamic, skeleton:Skeleton, state:AnimationState):Void {

        var op:String = action.op;
        var track:Int = action.track != null ? action.track : 0;
        var entry:TrackEntry = null;
        switch op {
            case 'setAnimation':
                entry = state.setAnimationByName(track, action.name, action.loop == true);
            case 'addAnimation':
                entry = state.addAnimationByName(track, action.name, action.loop == true, action.delay != null ? action.delay : 0);
            case 'setEmptyAnimation':
                entry = state.setEmptyAnimation(track, action.mix != null ? action.mix : 0);
            case 'setSkin':
                skeleton.skinName = action.name;
                skeleton.setupPoseSlots();
            case _:
                throw 'Unknown action: ' + op;
        }
        if (entry != null && op != 'setEmptyAnimation') {
            if (action.mix != null) entry.mixDuration = action.mix;
            if (action.alpha != null) entry.alpha = action.alpha;
            if (action.additive != null) entry.additive = action.additive;
        }

    }

    static function snapshot(out:StringBuf, skeleton:Skeleton, step:Int):Void {

        out.add('\n{"step":' + step + ',"bones":[');
        for (i in 0...skeleton.bones.length) {
            if (i > 0) out.add(',');
            var p = skeleton.bones[i].appliedPose;
            out.add('[' + [p.x, p.y, p.rotation, p.scaleX, p.scaleY, p.shearX, p.shearY, p.a, p.b, p.c, p.d, p.worldX, p.worldY].map(num).join(',') + ']');
        }
        out.add('],"slots":[');
        for (i in 0...skeleton.slots.length) {
            if (i > 0) out.add(',');
            var slot = skeleton.slots[i];
            var p = slot.appliedPose;
            var attachment = slot.bone.active ? p.attachment : null;
            out.add('{"a":' + Json.stringify(attachment != null ? attachment.name : null));
            out.add(',"s":' + p.sequenceIndex);
            out.add(',"c":[' + [p.color.r, p.color.g, p.color.b, p.color.a].map(num).join(',') + ']');
            out.add(',"f":[' + p.deform.map(num).join(',') + ']}');
        }
        out.add('],"o":[');
        var drawOrder = skeleton.drawOrder.appliedPose;
        for (i in 0...drawOrder.length) {
            if (i > 0) out.add(',');
            out.add(drawOrder[i].data.index);
        }
        out.add(']}');

    }

    static function num(value:Float):String {

        // Rounded as a Float (Math.round returns a 32 bit Int, which overflows for large values)
        var rounded = Math.fround(value * 1000000) / 1000000;
        return '' + rounded;

    }

}

#end
