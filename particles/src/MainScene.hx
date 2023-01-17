package;

import ceramic.Particles;
import ceramic.Scene;

class MainScene extends Scene {

    override function preload() {

        assets.add(Images.CERAMIC_PARTICLE);

    }

    override function create() {

        var particles = new Particles(new CeramicEmitter(assets));
        particles.pos(width * 0.5, height * 0.5);
        particles.autoEmit = true;
        add(particles);

    }

}
