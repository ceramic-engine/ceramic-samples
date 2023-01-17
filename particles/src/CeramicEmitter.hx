package;

import ceramic.Assets;
import ceramic.ParticleEmitter;
import ceramic.Quad;
import ceramic.Visual;

/**
 * A custom particles class to emit particles
 * that are small ceramic logo cups
 */
class CeramicEmitter extends ParticleEmitter {

    var assets:Assets;

    public function new(assets:Assets) {

        super();

        this.assets = assets;

        applyDefaultSettings();

    }

    function applyDefaultSettings():Void {

        // Edit emitter settings to change how particles are thrown
        // (look at ParticleEmitter API docs: https://ceramic-engine.com/api-docs/ceramic/ParticleEmitter.html)

        // Scale from 0.0001 to 1
        scaleStart(0.0001, 0.0001);
        scaleEnd(1, 1);

        // Launch toward the top
        launchAngle(-25, 25);
        speedStart(200, 160);
        speedEnd(200, 160);

        // Rotate particles
        angularVelocityStart(-100, 100);
        angularVelocityEnd(-100, 100);

        // Create some gravity
        accelerationStart(0, 300, 0, 200);
        accelerationEnd(0, 700, 0, 600);

    }

    override function getParticleVisual(existingVisual:Visual):Visual {

        // Overriding this method to customize which visual to emit.
        // Here we want to emit small particles that look like Ceramic logo

        // Reuse existing visual if provided
        if (existingVisual != null) {
            existingVisual.active = true;
            return existingVisual;
        }

        // Or create a new visual otherwise
        var quad = new Quad();
        quad.anchor(0.5, 0.5);
        quad.texture = assets.texture(Images.CERAMIC_PARTICLE);

        return quad;

    }

}
