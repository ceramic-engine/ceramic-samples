package;

import ceramic.GifCapture;
import ceramic.Particles;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Timer;

class MainScene extends Scene {

    var logo:Quad;

    override function preload() {

        // Add any asset you want to load here

        assets.add(Images.CERAMIC_PARTICLE);

    }

    override function create() {

        var particles = new Particles(new CeramicEmitter(assets));
        particles.pos(width * 0.5, height * 0.5);
        add(particles);

        particles.emitter.emitContinuously();

    }

    override function update(delta:Float) {

        // Here, you can add code that will be executed at every frame

    }

    override function resize(width:Float, height:Float) {

        // Called everytime the scene size has changed

    }

    override function destroy() {

        // Perform any cleanup before final destroy

        super.destroy();

    }

}
