package;

import ceramic.Spine;
import ceramic.SpineData;

/**
 * Bounding box rendering and hit test: spineboy has a bounding box attachment
 * (`head` in the `head-bb` slot) that is not shown by default. It is shown on every
 * update, and the spine is hit tested with its first bounding box.
 */
class BoundingBoxScenario {

    public var spine:Spine;

    public var frames:Array<Dynamic> = [];

    public function new(spineData:SpineData) {

        spine = new Spine();
        spine.spineData = spineData;
        spine.autoUpdate = false;
        spine.autoFreeze = false;
        spine.renderWhenInvisible = true;
        spine.skeletonScale = 0.5;
        spine.pos(700, 700);
        spine.hitWithFirstBoundingBox = true;
        spine.onUpdateWorldTransform(null, () -> {
            spine.skeleton.setAttachment('head-bb', 'head');
        });
        spine.computeContent();
        spine.animate('walk', true);

    }

    public function update(dt:Float):Void {

        spine.update(dt);

    }

    public function dump(step:Int, time:Float):Dynamic {

        var hits = new StringBuf();
        var y = 300;
        while (y <= 700) {
            var x = 550;
            while (x <= 850) {
                hits.add(spine.hits(x, y) ? '1' : '0');
                x += 15;
            }
            hits.add('|');
            y += 20;
        }

        return {
            step: step,
            time: time,
            hits: hits.toString(),
            visuals: ConformanceScene.dumpChildren(spine)
        };

    }

}
