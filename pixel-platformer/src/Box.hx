package;

import ceramic.Assets;
import ceramic.Sprite;
import ceramic.SpriteSheet;
import ceramic.Visual;

class Box extends Sprite {

    static var _sheet:SpriteSheet = null;

    /**
     * A flag to know if this box has been triggered or not
     */
    var triggered:Bool = false;

    public function new(assets:Assets) {

        super();

        // Ensure physics are enabled
        initArcadePhysics();

        // Mark this box as immovable
        immovable = true;

        // Create sprite sheet needed for this box
        // (reuse the same sheet instance for each Box object)
        if (_sheet == null) {
            _sheet = new SpriteSheet();
            _sheet.texture = assets.texture(Images.TILES);
            _sheet.grid(18, 18);
            _sheet.addGridAnimation('box-exclam-default', [10], 0);
            _sheet.addGridAnimation('box-exclam-used', [30], 0);
        }
        sheet = _sheet;

        size(18, 18);

        animation = 'box-exclam-default';

        onCollide(this, handleCollide);

    }

    function handleCollide(visual1:Visual, visual2:Visual) {

        if (triggered)
            return;

        var subject = visual1 == this ? visual2 : visual1;
        if (subject is Player) {
            triggered = true;
            animation = 'box-exclam-used';

            var player:Player = cast subject;
            player.triggerBox(this);
        }

    }

}
