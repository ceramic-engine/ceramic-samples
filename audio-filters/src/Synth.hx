package;

import ceramic.Float32Array;
import ceramic.Sound;

/**
 * Tiny procedural audio synthesizer, borrowed from the audio sample:
 * both sounds of this sample are generated at runtime with
 * `Sound.fromSamplesBuffer()`. No audio file needed!
 */
class Synth {

    static inline final SAMPLE_RATE:Int = 44100;

    /**
     * Build a mono Sound from a generator function
     * called for each sample with the time in seconds.
     */
    static function generate(duration:Float, generator:(t:Float)->Float):Sound {

        var count = Math.round(SAMPLE_RATE * duration);
        var buffer = new Float32Array(count);
        for (i in 0...count) {
            buffer[i] = generator(i / SAMPLE_RATE);
        }
        return Sound.fromSamplesBuffer(buffer, count, 1, SAMPLE_RATE, true);

    }

    /**
     * A simple attack/release envelope (t and duration in seconds)
     */
    static function envelope(t:Float, duration:Float, attack:Float, release:Float):Float {

        if (t < attack) return t / attack;
        var releaseStart = duration - release;
        if (t > releaseStart) return Math.max(0, (duration - t) / release);
        return 1;

    }

    /**
     * A short square wave blip
     */
    public static function blip():Sound {

        var duration = 0.12;
        return generate(duration, t -> {
            var square = Math.sin(2 * Math.PI * 880 * t) >= 0 ? 1.0 : -1.0;
            return 0.5 * square * envelope(t, duration, 0.005, 0.06);
        });

    }

    /**
     * A deterministic "noise" from the time (same value for a
     * given t), used to synthesize the hi-hat and the snare.
     */
    static function noise(t:Float):Float {

        var v = Math.sin(t * 127453.1) * 43758.5453;
        return (v - Math.ffloor(v)) * 2 - 1;

    }

    /**
     * An 8 second music loop: a chord arpeggio (Am, F, C, G)
     * played with a soft triangle wave, a sine bass, and a punchy
     * drum kit (kick on every beat, snare on 2 & 4, off-beat hi-hat).
     */
    public static function music():Sound {

        // Note frequencies of each chord
        var chords = [
            [220.00, 261.63, 329.63],         // A minor
            [174.61, 220.00, 261.63],         // F major
            [130.81, 164.81, 196.00, 261.63], // C major
            [196.00, 246.94, 293.66]          // G major
        ];

        var beat = 0.5;             // 120 BPM
        var duration = beat * 16;   // 4 chords of 4 beats
        var step = beat / 4;        // 4 arpeggio notes per beat

        return generate(duration, t -> {

            var chord = chords[Std.int(t / (beat * 4)) % 4];

            // Arpeggio: cycle through the chord notes, one octave up
            var noteIndex = Std.int(t / step);
            var noteT = t - noteIndex * step;
            var freq = chord[noteIndex % chord.length] * 2;
            var phase = freq * noteT;
            var tri = 4 * Math.abs((phase - Math.ffloor(phase + 0.5))) - 1;
            var value = 0.22 * tri * envelope(noteT, step, 0.01, 0.06);

            // Bass: the chord's root note, one octave down
            var chordT = t % (beat * 4);
            value += 0.18 * Math.sin(2 * Math.PI * (chord[0] * 0.5) * t)
                * envelope(chordT, beat * 4, 0.02, 0.4);

            // Kick: a pitch-diving sine thump on EVERY beat (the logo
            // pulses on those same beats, see MainScene)
            var beatT = t % beat;
            // Closed-form phase of the 160 Hz -> 50 Hz frequency dive,
            // so the sine stays continuous while its pitch drops
            var kickPhase = 50 * beatT + (110 / 35) * (1 - Math.exp(-beatT * 35));
            value += 0.4 * Math.sin(2 * Math.PI * kickPhase) * Math.exp(-beatT * 14);

            // Snare: a noise burst plus a short tone, on beats 2 and 4
            var beatIndex = Std.int(t / beat);
            if (beatIndex % 2 == 1) {
                value += (0.2 * noise(t) + 0.1 * Math.sin(2 * Math.PI * 190 * beatT))
                    * Math.exp(-beatT * 22);
            }

            // Hi-hat: a tiny noise tick on every off-beat
            var hatT = (t + beat * 0.5) % beat;
            value += 0.07 * noise(t) * Math.exp(-hatT * 80);

            // Safety clamp: all layers together may exceed [-1, 1]
            return Math.max(-1, Math.min(1, value));

        });

    }

}
