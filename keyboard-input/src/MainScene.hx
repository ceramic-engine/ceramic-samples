package;

import ceramic.Key;
import ceramic.KeyCode;
import ceramic.ScanCode;
import ceramic.Scene;
import ceramic.Text;

class MainScene extends Scene {

    /**
     * A text object to display info about keyboard input
     */
    var text:Text;

    /**
     * The list of currently pressed key codes
     */
    var pressedKeyCodes:Array<KeyCode> = [];

    /**
     * The list of currently pressed scan codes
     */
    var pressedScanCodes:Array<ScanCode> = [];

    override function create() {

        // Use a text object to display info about keyboard input
        text = new Text();
        text.anchor(0.5, 0.5);
        text.pos(width * 0.5, height * 0.5);
        text.align = CENTER;
        add(text);

        // Bind keyboard input events
        input.onKeyDown(this, keyDown);
        input.onKeyUp(this, keyUp);

        updateText();

    }

    function keyDown(key:Key) {

        if (!pressedKeyCodes.contains(key.keyCode)) {
            pressedKeyCodes.push(key.keyCode);
            pressedScanCodes.push(key.scanCode);
        }

        updateText();

    }

    function keyUp(key:Key) {

        pressedKeyCodes.remove(key.keyCode);
        pressedScanCodes.remove(key.scanCode);

        updateText();

    }

    function updateText() {

        // Update text depending on the currently pressed keys

        if (pressedKeyCodes.length > 0) {
            var content = [];
            for (i in 0...pressedKeyCodes.length) {
                var keyCode = pressedKeyCodes[i];
                var scanCode = pressedScanCodes[i];
                content.push(KeyCode.name(keyCode) + ' (key code)          ' + ScanCode.name(scanCode) + ' (scan code)');
            }
            text.content = content.join('\n');
        }
        else {
            text.content = 'press any key (keyboard)';
        }

    }

}
