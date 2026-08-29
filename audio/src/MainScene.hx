package;

import ceramic.Color;
import ceramic.Scene;
import ceramic.Sound;
import ceramic.SoundPlayer;
import ceramic.Text;

class MainScene extends Scene {

    var blipSound:Sound;

    var coinSound:Sound;

    var laserSound:Sound;

    var musicSound:Sound;

    var musicPlayer:SoundPlayer = null;

    var musicPaused:Bool = false;

    var musicButton:UiButton;

    override function create() {

        // Every sound of this sample is synthesized at runtime
        // (see Synth.hx). To load audio files instead, put them in
        // assets/ and use assets.add(Sounds.MY_SOUND) in preload().
        blipSound = Synth.blip();
        coinSound = Synth.coin();
        laserSound = Synth.laser();
        musicSound = Synth.music();

        var x = width * 0.5 - 220;
        var y = 40.0;

        var title = new Text();
        title.content = 'Sounds';
        title.pointSize = 18;
        title.color = Color.WHITE;
        title.pos(x, y);
        add(title);

        y += 40;

        // A few sound effect buttons.
        // Each click plays the sound with a slightly randomized
        // pitch, a cheap trick to make repeated sounds less robotic.

        var blipButton = new UiButton('Play blip');
        blipButton.pos(x, y);
        blipButton.onClick(this, () -> {
            blipSound.play(0, false, 0.8, 0, 0.9 + Math.random() * 0.2);
        });
        add(blipButton);

        var coinButton = new UiButton('Play coin');
        coinButton.pos(x + 190, y);
        coinButton.onClick(this, () -> {
            coinSound.play(0, false, 0.8, 0, 0.9 + Math.random() * 0.2);
        });
        add(coinButton);

        var laserButton = new UiButton('Play laser');
        laserButton.pos(x, y + 48);
        laserButton.onClick(this, () -> {
            laserSound.play(0, false, 0.8, 0, 0.9 + Math.random() * 0.2);
        });
        add(laserButton);

        y += 104;

        var musicTitle = new Text();
        musicTitle.content = 'Music (looped)';
        musicTitle.pointSize = 18;
        musicTitle.color = Color.WHITE;
        musicTitle.pos(x, y);
        add(musicTitle);

        y += 40;

        musicButton = new UiButton('Play music');
        musicButton.pos(x, y);
        musicButton.onClick(this, toggleMusic);
        add(musicButton);

        y += 64;

        // Live controls on the music player: these properties
        // can be changed at any time while the sound is playing.

        var volumeSlider = new UiSlider('volume', 0, 1, 0.5);
        volumeSlider.pos(x, y);
        volumeSlider.onValueChange(this, value -> {
            if (musicPlayer != null) musicPlayer.volume = value;
        });
        add(volumeSlider);

        y += 40;

        var pitchSlider = new UiSlider('pitch', 0.5, 2, 1);
        pitchSlider.pos(x, y);
        pitchSlider.onValueChange(this, value -> {
            if (musicPlayer != null) musicPlayer.pitch = value;
        });
        add(pitchSlider);

        y += 40;

        var panSlider = new UiSlider('pan', -1, 1, 0);
        panSlider.pos(x, y);
        panSlider.onValueChange(this, value -> {
            if (musicPlayer != null) musicPlayer.pan = value;
        });
        add(panSlider);

        y += 40;

        // Every sound belongs to a mixer group (0 by default).
        // Muting the mixer silences sound effects and music at once.

        var muteButton = new UiButton('Mute all: OFF', 200);
        muteButton.pos(x, y);
        muteButton.onClick(this, () -> {
            var mixer = audio.mixer(0);
            mixer.mute = !mixer.mute;
            muteButton.content = mixer.mute ? 'Mute all: ON' : 'Mute all: OFF';
        });
        add(muteButton);

        var hint = new Text();
        hint.content = 'Every sound is synthesized in Haxe at runtime: zero audio file.';
        hint.pointSize = 12;
        hint.color = Color.GRAY;
        hint.anchor(0.5, 1);
        hint.pos(width * 0.5, height - 16);
        add(hint);

    }

    function toggleMusic() {

        if (musicPlayer == null) {
            // play(position, loop, volume, pan, pitch)
            musicPlayer = musicSound.play(0, true, 0.5);
            musicButton.content = 'Pause music';
        }
        else if (musicPaused) {
            musicPaused = false;
            musicPlayer.resume();
            musicButton.content = 'Pause music';
        }
        else {
            musicPaused = true;
            musicPlayer.pause();
            musicButton.content = 'Resume music';
        }

    }

}
