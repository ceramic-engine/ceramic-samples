package;

import ceramic.Color;
import ceramic.KeyCode;
import ceramic.LowPassFilter;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Sound;
import ceramic.SoundPlayer;
import ceramic.Text;
import ceramic.TouchInfo;

class MainScene extends Scene {

    // The synth music is 120 BPM (see Synth.hx): one beat every 0.5 second
    static final BEAT_DURATION:Float = 0.5;

    // Background colors: the screen gets darker as the filter closes
    static final BG_OPEN:Color = 0x1c1c26;
    static final BG_CLOSED:Color = 0x07070c;

    var blipSound:Sound;

    var musicSound:Sound;

    var musicPlayer:SoundPlayer = null;

    var lowPass:LowPassFilter;

    var filterEngaged:Bool = false;

    var bg:Quad;

    var logo:Quad;

    var logoBaseScale:Float;

    var lastBeat:Int = -1;

    var statusText:Text;

    override function preload() {

        assets.add(Images.CERAMIC);

    }

    override function create() {

        // Both sounds are synthesized at runtime (see Synth.hx)
        blipSound = Synth.blip();
        musicSound = Synth.music();

        // Audio filters process a whole bus. Here, the music plays on
        // bus 1 and the low-pass filter is added to that same bus, so the
        // blip sound effect (played on the default bus 0) always stays
        // unfiltered. The filter is added ONCE and stays on the bus: when
        // not engaged, its params are simply set to neutral values (see
        // resetFilter() below), which make it transparent.
        lowPass = new LowPassFilter();
        resetFilter();
        audio.addFilter(lowPass, 1);

        bg = new Quad();
        bg.size(width, height);
        bg.color = BG_OPEN;
        bg.depth = 1;
        add(bg);

        // The logo pulses on the music beat (see update() below)
        logo = new Quad();
        logo.texture = assets.texture(Images.CERAMIC);
        logo.anchor(0.5, 0.5);
        logoBaseScale = 180.0 / logo.height;
        logo.scale(logoBaseScale);
        logo.pos(width * 0.5, height * 0.45);
        logo.depth = 2;
        add(logo);

        statusText = new Text();
        statusText.pointSize = 14;
        statusText.color = Color.WHITE;
        statusText.align = CENTER;
        statusText.anchor(0.5, 0);
        statusText.pos(width * 0.5, height * 0.72);
        statusText.depth = 2;
        add(statusText);

        // The filter is engaged while the pointer is held down,
        // and swept by dragging (like a DJ filter sweep)
        screen.onPointerDown(this, handlePointerDown);
        screen.onPointerMove(this, handlePointerMove);
        screen.onPointerUp(this, handlePointerUp);

        // 'B' plays the (unfiltered) blip: a mnemonic shortcut,
        // so it is matched by keyCode (layout independent)
        input.onKeyDown(this, key -> {
            if (key.keyCode == KeyCode.KEY_B) {
                blipSound.play(0, false, 0.8, 0, 0.9 + Math.random() * 0.2);
            }
        });

        updateStatus();

    }

    override function update(delta:Float) {

        // Make the logo pulse on the music beat: instead of a separate
        // timer that would drift away from the audio, the current beat is
        // derived from the actual playback position of the music player,
        // so the pulse stays in sync with what you hear (even when the
        // music loops).
        if (musicPlayer != null) {
            var beat = Std.int(musicPlayer.position / BEAT_DURATION);
            if (beat != lastBeat) {
                lastBeat = beat;
                logo.tween(QUAD_EASE_OUT, 0.25, logoBaseScale * 1.12, logoBaseScale, (value, _) -> {
                    logo.scale(value);
                });
            }
        }

    }

    function handlePointerDown(info:TouchInfo) {

        if (musicPlayer == null) {
            // First tap: start the music. (On web, audio can only start
            // after a user interaction anyway.)
            // play(position, loop, volume, pan, pitch, bus)
            musicPlayer = musicSound.play(0, true, 0.5, null, null, 1);
            updateStatus();
            return;
        }

        // Engage the filter while the pointer is held down
        filterEngaged = true;
        applyFilterFromPointer(info.x, info.y);

    }

    function handlePointerMove(info:TouchInfo) {

        if (filterEngaged) {
            applyFilterFromPointer(info.x, info.y);
        }

    }

    function handlePointerUp(info:TouchInfo) {

        if (filterEngaged) {
            filterEngaged = false;
            resetFilter();
            bg.color = BG_OPEN;
            updateStatus();
        }

    }

    /**
     * Reset the filter to neutral values: with its cutoff frequency well
     * above the audible range and no resonance, it lets the sound through
     * unchanged.
     */
    function resetFilter() {

        lowPass.cutoffFrequency = 20000;
        lowPass.resonance = 0.707;

    }

    /**
     * Map the pointer position to the filter params:
     * left/right sweeps the cutoff frequency, up/down the resonance.
     * Filter params can be changed live, while the filter is running.
     */
    function applyFilterFromPointer(x:Float, y:Float) {

        // Cutoff frequency: exponential sweep from 100 Hz (left) to 8000 Hz (right)
        var cutoffRatio = Math.max(0, Math.min(1, x / width));
        lowPass.cutoffFrequency = 100 * Math.pow(80, cutoffRatio);

        // Resonance (Q): stronger towards the top
        var resonanceRatio = Math.max(0, Math.min(1, 1 - y / height));
        lowPass.resonance = 0.707 + resonanceRatio * 8;

        // Visual feedback: the more the filter closes, the darker the screen
        bg.color = Color.interpolate(BG_CLOSED, BG_OPEN, cutoffRatio);

        updateStatus();

    }

    function updateStatus() {

        if (musicPlayer == null) {
            statusText.content = 'Tap anywhere to start the music';
        }
        else if (filterEngaged) {
            statusText.content =
                'cutoff: ' + Math.round(lowPass.cutoffFrequency) + ' Hz'
                + '  -  Q: ' + (Math.round(lowPass.resonance * 100) / 100);
        }
        else {
            statusText.content =
                'Hold & drag to sweep the low-pass filter\n' +
                'left/right: cutoff  -  up/down: resonance\n' +
                'B: play a blip on bus 0 (never filtered)';
        }

    }

}
