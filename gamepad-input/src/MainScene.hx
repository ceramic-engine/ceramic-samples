package;

import ceramic.GamepadAxis;
import ceramic.GamepadButton;
import ceramic.Key;
import ceramic.KeyCode;
import ceramic.ScanCode;
import ceramic.Scene;
import ceramic.Text;

class MainScene extends Scene {

    /**
     * A text object to display info about gamepad input
     */
    var text:Text;

    /**
     * The list of currently pressed buttons
     */
    var pressedButtons:Map<Int,Array<GamepadButton>> = new Map();

    /**
     * The known axis values
     */
    var axisValues:Map<Int,Map<GamepadAxis,Float>> = new Map();

    override function create() {

        // Use a text object to display info about keyboard input
        text = new Text();
        text.anchor(0.5, 0.5);
        text.pos(width * 0.5, height * 0.5);
        text.align = CENTER;
        add(text);

        // Bind gamepad input events
        input.onGamepadDown(this, gamepadDown);
        input.onGamepadUp(this, gamepadUp);

        updateText();

    }

    function gamepadDown(gamepadId:Int, button:GamepadButton) {

        var pressedButtonsForGamepad = pressedButtons.get(gamepadId);
        if (pressedButtonsForGamepad == null) {
            pressedButtonsForGamepad = [];
            pressedButtons.set(gamepadId, pressedButtonsForGamepad);
        }

        if (!pressedButtonsForGamepad.contains(button)) {
            pressedButtonsForGamepad.push(button);
        }

        updateText();

    }

    function gamepadUp(gamepadId:Int, button:GamepadButton) {

        var pressedButtonsForGamepad = pressedButtons.get(gamepadId);
        if (pressedButtonsForGamepad != null) {
            pressedButtonsForGamepad.remove(button);
        }

        updateText();

    }

    function updateText() {

        // Update text depending on the currently pressed buttons

        var hasButtonsPressed = false;
        for (gamepadId => pressedButtonsForGamepad in pressedButtons) {
            if (pressedButtonsForGamepad.length > 0) {
                hasButtonsPressed = true;
                var content = [];
                for (i in 0...pressedButtonsForGamepad.length) {
                    var button = pressedButtonsForGamepad[i];
                    content.push(
                        '$button #$gamepadId'
                    );
                }
                text.content = content.join('\n');
            }
        }

        if (!hasButtonsPressed) {
            text.content = 'press any button (gamepad)';
        }

    }

}
