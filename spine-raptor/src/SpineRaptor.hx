package;

import ceramic.Scene;
import ceramic.Spine;
import ceramic.Timer;
import ceramic.Utils;
import elements.Im;

using ceramic.SpinePlugin;

class SpineRaptor extends Scene {

    var spine:Spine;

    var animationList:Array<String>;

    // Just a mapping to know which animation should loop
    var shouldLoop:Map<String,Bool> = [
        Spines.RAPTOR_PRO.WALK => true
    ];

    var someText:String = 'Hello World';

    var someText2:String = 'Youpi World';

    var animationList2:Array<String>;

    var animation2:String;

    override function preload() {

        // Load spine asset
        assets.add(Spines.RAPTOR_PRO);

    }

    override function create() {

        // Create spine object to display animation
        spine = new Spine();
        spine.spineData = assets.spine(Spines.RAPTOR_PRO);
        spine.pos(screen.width * 0.5, screen.height * 0.85);
        spine.animation = Spines.RAPTOR_PRO.WALK;
        spine.loop = shouldLoop.exists(spine.animation);
        spine.skeletonScale = 0.33;
        add(spine);

        // Create animation list (for debug menu)
        animationList = [];
        for (anim in spine.spineData.skeletonData.animations)
            animationList.push(anim.name);
        animationList.sort(Reflect.compare);

        animationList2 = ['youpi', 'bref'];
        animation2 = 'bref';

    }

    override function update(delta:Float) {

        // Some debug UI to choose animation

        Im.begin('Spine', 200);

        if (Im.select('Animation', Im.string(spine.animation), animationList)) {
            spine.loop = shouldLoop.exists(spine.animation);
        }

        Im.select('Animation', Im.string(animation2), animationList2);

        // Im.editText(Im.string(someText));

        // Im.editText(Im.string(someText2));

        Im.end();

    }

}
