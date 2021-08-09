package;

import ceramic.TouchInfo;
import ceramic.Color;
import ceramic.Text;
import ceramic.Quad;
import ceramic.Scene;

class QuadDrag extends Scene {

    /**
     * Displayed quad
     */
    var quad:Quad;

    var quadStartX:Float = 0.0;
    var quadStartY:Float = 0.0;
    var pointerStartX:Float = 0.0;
    var pointerStartY:Float = 0.0;

    override function create() {
        
        // Create and display a quad
        quad = new Quad();
        quad.anchor(0.5, 0.5);
        quad.color = Color.YELLOW;
        quad.pos(screen.width * 0.5, screen.height * 0.5);
        quad.size(64, 64);
        add(quad);

        // Bind pointer down event
        quad.onPointerDown(this, quadDown);

    }

    function quadDown(info:TouchInfo) {

        // Start dragging
        quad.color = Color.RED;
        quadStartX = quad.x;
        quadStartY = quad.y;
        pointerStartX = screen.pointerX;
        pointerStartY = screen.pointerY;
        
        // Follow movement from screen
        screen.onPointerMove(this, quadMove);

        // Stop dragging when releasing pointer
        quad.oncePointerUp(this, quadUp);

    }

    function quadMove(info:TouchInfo) {

        // Update quad position from pointer movement
        quad.pos(
            quadStartX + screen.pointerX - pointerStartX,
            quadStartY + screen.pointerY - pointerStartY
        );

    }

    function quadUp(info:TouchInfo) {

        // Unbind move event
        screen.offPointerMove(quadMove);
        quad.color = Color.YELLOW;

    }
    
}
