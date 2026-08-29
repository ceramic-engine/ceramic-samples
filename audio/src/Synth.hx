package;

import ceramic.Float32Array;
import ceramic.Sound;

/**
 * Tiny procedural audio synthesizer: every sound of this sample
 * is generated at runtime with `Sound.fromSamplesBuffer()`.
 * No audio file needed!
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
     * A two-note coin arpeggio (E6 then B6)
     */
    public static function coin():Sound {

        var duration = 0.27;
        return generate(duration, t -> {
            if (t < 0.09) {
                return 0.55 * Math.sin(2 * Math.PI * 1318.5 * t) * envelope(t, 0.09, 0.005, 0.02);
            }
            else {
                var t2 = t - 0.09;
                return 0.55 * Math.sin(2 * Math.PI * 1975.5 * t2) * envelope(t2, 0.18, 0.005, 0.1);
            }
        });

    }

    /**
     * A descending laser sweep (sawtooth from 1600Hz to 200Hz)
     */
    public static function laser():Sound {

        var duration = 0.3;
        var phase = 0.0;
        var prevT = 0.0;
        return generate(duration, t -> {
            var freq = 1600 + (200 - 1600) * (t / duration);
            phase += freq * (t - prevT);
            prevT = t;
            var saw = 2 * (phase - Math.ffloor(phase + 0.5));
            return 0.4 * saw * envelope(t, duration, 0.005, 0.1);
        });

    }

    /**
     * An 8 second music loop: a chord arpeggio (Am, F, C, G)
     * played with a soft triangle wave, plus a sine bass.
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

            return value;

        });

    }

}
