package;

import ceramic.GamepadButton;
import ceramic.Scene;
import ceramic.Text;
import ceramic.Utils;

class MainScene extends Scene {

    /**
     * A text object to display info about gamepad input
     */
    var text:Text;

    /**
     * The list of currently pressed buttons
     */
    var pressedButtons:Map<Int,Array<GamepadButton>> = new Map();

    override function create() {

        // Use a text object to display info about keyboard input
        text = new Text();
        text.pointSize = 16;
        text.anchor(0.5, 0.5);
        text.pos(width * 0.5, height * 0.5);
        text.align = CENTER;
        add(text);

        // Bind gamepad button events
        input.onGamepadDown(this, gamepadDown);
        input.onGamepadUp(this, gamepadUp);

        updateText();

    }

    override function update(delta:Float) {

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

    }

    function gamepadUp(gamepadId:Int, button:GamepadButton) {

        var pressedButtonsForGamepad = pressedButtons.get(gamepadId);
        if (pressedButtonsForGamepad != null) {
            pressedButtonsForGamepad.remove(button);
        }

    }

    function updateText() {

        // Update text depending on the currently pressed buttons

        var hasButtonsPressed = false;
        var content = [];
        for (gamepadId => pressedButtonsForGamepad in pressedButtons) {
            if (pressedButtonsForGamepad.length > 0) {

                hasButtonsPressed = true;
                content.push('[[ GAMEPAD #$gamepadId ]]');
                content.push('');
                for (i in 0...pressedButtonsForGamepad.length) {
                    var button = pressedButtonsForGamepad[i];
                    content.push(
                        '$button'
                    );
                }

                // Also add some axis values
                content.push('LEFT AXIS: ' + Utils.round(input.gamepadAxisValue(gamepadId, LEFT_X), 2) + ', ' + Utils.round(input.gamepadAxisValue(gamepadId, LEFT_Y), 2));
                content.push('RIGHT AXIS: ' + Utils.round(input.gamepadAxisValue(gamepadId, RIGHT_X), 2) + ', ' + Utils.round(input.gamepadAxisValue(gamepadId, RIGHT_Y), 2));
                content.push('');
            }
        }

        if (!hasButtonsPressed) {
            text.content = 'press any button (gamepad)';
        }
        else {
            text.content = content.join('\n');
        }

    }

}
