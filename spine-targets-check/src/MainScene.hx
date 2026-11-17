package;

import ceramic.Quad;
import ceramic.Scene;
import ceramic.Spine;
import ceramic.SpineBindVisual;

using ceramic.SpinePlugin;

/**
 * Uses the main features of the spine plugin, so that compiling this project for a
 * target checks that the plugin (and the selected spine runtime) builds on it.
 */
class MainScene extends Scene {

    override function preload() {

        assets.addSpine('spineboy-pro');
        assets.addSpine('tank-pro');
        #if !spine_legacy
        assets.addSpine('celestial-circus-pro');
        assets.addSpine('alien-pro');
        #end

    }

    override function create() {

        var spineboy = createSpine('spineboy-pro', 'portal', 250, 650, 0.4);
        #if !spine_legacy
        spineboy.clipping = STENCIL;
        #end

        // Child spine following a slot, and a visual bound to a slot
        var child = new Spine();
        child.spineData = assets.spine('spineboy-pro');
        child.skeletonScale = 0.2;
        spineboy.add(child);
        child.bindParentSlot('gun');
        child.animation = 'idle';

        var marker = new Quad();
        marker.size(10, 10);
        SpineBindVisual.bindVisual(spineboy, 'head', marker);

        var tank = createSpine('tank-pro', 'drive', 600, 650, 0.2);
        #if !spine_legacy
        tank.clipping = SOFTWARE;
        createSpine('celestial-circus-pro', 'swing', 850, 700, 0.15);
        createSpine('alien-pro', 'run', 450, 300, 0.4);
        #end

        log.info('Spine targets check: running');

    }

    function createSpine(name:String, animation:String, x:Float, y:Float, scale:Float):Spine {

        var spine = new Spine();
        spine.spineData = assets.spine(name);
        spine.skeletonScale = scale;
        spine.pos(x, y);
        spine.animation = animation;
        spine.loop = true;
        add(spine);
        return spine;

    }

}
