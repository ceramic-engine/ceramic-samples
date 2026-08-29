package;

import ceramic.Color;
import ceramic.Graphics;
import ceramic.Scene;
import ceramic.Text;
import ceramic.TextAlign;

class GraphicsDemo extends Scene {

    var graphics:Graphics;
    var time:Float = 0;

    override function create() {
        super.create();

        // Create graphics instance
        graphics = new Graphics();
        graphics.pos(0, 0);
        add(graphics);

    }

    var didDraw = false;

    override function update(delta:Float) {
        super.update(delta);

        time += delta;

        //if (!didDraw) {
            // Clear and redraw every frame (tests pooling efficiency)
            graphics.clear();
            drawFrame();
            //didDraw = true;
        //}
        //testFoldBack();
    }

    function testFoldBack() {
        // Animated fold-back test case - same as original drawFrame test
        var foldX = 250.0;
        var foldY = 200.0;
        var foldLen = 60.0;
        var narrowAngle = Math.sin(time) * 0.15 + 0.1; // Oscillates between ~5° and ~25°

        // MITER join with narrow angle
        graphics.lineStyle(6, Color.fromRGB(255, 200, 100), 1.0, MITER, BUTT);
        graphics.moveTo(foldX, foldY);
        graphics.lineTo(foldX + foldLen, foldY);
        graphics.lineTo(foldX + foldLen - Math.cos(narrowAngle) * foldLen, foldY - Math.sin(narrowAngle) * foldLen);
        graphics.drawPath();

        // BEVEL join with narrow angle
        graphics.lineStyle(6, Color.fromRGB(100, 255, 200), 1.0, BEVEL, BUTT);
        graphics.moveTo(foldX, foldY + 25);
        graphics.lineTo(foldX + foldLen, foldY + 25);
        graphics.lineTo(foldX + foldLen - Math.cos(narrowAngle) * foldLen, foldY + 25 - Math.sin(narrowAngle) * foldLen);
        graphics.drawPath();

        // ROUND join with narrow angle
        graphics.lineStyle(6, Color.fromRGB(200, 100, 255), 1.0, ROUND, BUTT);
        graphics.moveTo(foldX, foldY + 50);
        graphics.lineTo(foldX + foldLen, foldY + 50);
        graphics.lineTo(foldX + foldLen - Math.cos(narrowAngle) * foldLen, foldY + 50 - Math.sin(narrowAngle) * foldLen);
        graphics.drawPath();

        // Near-180° fold-back test (almost going back on itself)
        var foldBack = Math.PI - 0.1; // ~170° turn
        graphics.lineStyle(8, Color.fromRGB(255, 100, 100), 1.0, MITER, BUTT);
        graphics.moveTo(foldX + 150, foldY);
        graphics.lineTo(foldX + 150 + 40, foldY);
        graphics.lineTo(foldX + 150 + 40 - Math.cos(foldBack) * 40, foldY - Math.sin(foldBack) * 40);
        graphics.drawPath();

        graphics.lineStyle(8, Color.fromRGB(100, 255, 100), 1.0, BEVEL, BUTT);
        graphics.moveTo(foldX + 150, foldY + 30);
        graphics.lineTo(foldX + 150 + 40, foldY + 30);
        graphics.lineTo(foldX + 150 + 40 - Math.cos(foldBack) * 40, foldY + 30 - Math.sin(foldBack) * 40);
        graphics.drawPath();

        graphics.lineStyle(8, Color.fromRGB(100, 100, 255), 1.0, ROUND, BUTT);
        graphics.moveTo(foldX + 150, foldY + 60);
        graphics.lineTo(foldX + 150 + 40, foldY + 60);
        graphics.lineTo(foldX + 150 + 40 - Math.cos(foldBack) * 40, foldY + 60 - Math.sin(foldBack) * 40);
        graphics.drawPath();
    }

    function drawFrame() {
        var offsetX = Math.sin(time * 2) * 30;
        var offsetY = Math.cos(time * 2) * 20;

        // === COMBINED FILL + STROKE DEMO ===

        // Rectangle with fill and stroke (uses new combined fill+stroke feature)
        graphics.beginFill(Color.fromRGB(200, 50, 50));
        graphics.lineStyle(0, Color.WHITE);
        graphics.drawRect(100 + offsetX, 100, 150, 80);
        graphics.endFill();

        // Circle with fill and stroke (combined)
        var circleRadius = 40 + Math.sin(time * 3) * 10;
        graphics.beginFill(Color.fromRGB(50, 150, 200));
        graphics.lineStyle(3, Color.fromRGB(200, 230, 255));
        graphics.drawCircle(400 + offsetX, 150 + offsetY, circleRadius);
        graphics.endFill();
        graphics.lineStyle(); // Disable stroke

        // === FILLED SHAPES ===

        // Animated filled triangle
        graphics.beginFill(Color.fromRGB(50, 200, 50));
        graphics.drawTriangle(
            300, 280 + offsetY,
            350 + offsetX, 230,
            400, 280 + offsetY
        );
        graphics.endFill();

        // Rotating filled hexagon
        var hexagon:Array<Float> = [];
        var sides = 6;
        var radius = 35 + Math.sin(time * 2.5) * 5;
        var centerX = 400 + offsetX;
        var centerY = 400 + offsetY;
        var rotation = time * 0.5;

        for (i in 0...sides) {
            var angle = rotation + (i / sides) * Math.PI * 2;
            hexagon.push(centerX + Math.cos(angle) * radius);
            hexagon.push(centerY + Math.sin(angle) * radius);
        }

        graphics.beginFill(Color.fromRGB(150, 50, 200));
        graphics.lineStyle(2, Color.fromRGB(200, 150, 255));
        graphics.drawPolygon(hexagon);
        graphics.endFill();
        graphics.lineStyle();

        // Star shape with fill and stroke
        var star:Array<Float> = [];
        var starPoints = 5;
        var outerRadius = 40;
        var innerRadius = 20;
        var starX = 150;
        var starY = 250;
        var starRotation = time;

        for (i in 0...starPoints * 2) {
            var angle = starRotation + (i / (starPoints * 2)) * Math.PI * 2;
            var r = (i % 2 == 0) ? outerRadius : innerRadius;
            star.push(starX + Math.cos(angle) * r);
            star.push(starY + Math.sin(angle) * r);
        }

        graphics.beginFill(Color.fromRGB(255, 220, 50));
        graphics.lineStyle(2, Color.fromRGB(200, 150, 0));
        graphics.drawPolygon(star);
        graphics.endFill();
        graphics.lineStyle();

        // === STROKED SHAPES ===

        // Rotating arc (stroke only)
        var arcAngle = (time * 60) % 360;
        graphics.lineStyle(4, Color.fromRGB(255, 200, 50));
        graphics.drawArc(200, 400, 60, arcAngle, arcAngle + 90);

        // === PATH DRAWING ===

        // Path with curves
        graphics.lineStyle(2, Color.fromRGB(100, 255, 200));
        graphics.moveTo(100, 500);
        graphics.lineTo(150, 520);
        graphics.quadraticCurveTo(200 + offsetX * 0.5, 490, 250, 520);
        graphics.bezierCurveTo(300, 540, 350, 480, 400 + offsetX, 500);
        graphics.drawPath();

        // Closed path triangle
        graphics.lineStyle(2, Color.CYAN, 1.0, ROUND, BUTT);
        graphics.moveTo(500, 500);
        graphics.lineTo(550, 480);
        graphics.lineTo(570, 520);
        graphics.closePath();
        graphics.drawPath();

        // === GRID STRESS TEST ===

        var gridSize = 10;
        var cellSize = 8;
        var spacing = 12;
        var gridX = 550;
        var gridY = 100;

        for (row in 0...gridSize) {
            for (col in 0...gridSize) {
                var intensity = Math.sin(time * 3 + row * 0.3 + col * 0.3) * 0.5 + 0.5;
                graphics.lineStyle(0.5, Color.WHITE);
                graphics.beginFill(Color.fromRGB(
                    Std.int(255 * intensity),
                    Std.int(100 * intensity),
                    Std.int(200 * (1 - intensity))
                ), 0.8);
                graphics.drawRect(
                    gridX + col * spacing,
                    gridY + row * spacing,
                    cellSize,
                    cellSize
                );
                graphics.endFill();
            }
        }

        // === COMBINED FILL+STROKE CIRCLE (previously required two calls) ===

        var circleX = 650;
        var circleY = 480;
        var circleR = 30 + Math.sin(time * 2.8) * 5;

        // Now uses combined fill+stroke in a single operation
        graphics.beginFill(Color.fromRGB(200, 100, 250), 0.5);
        graphics.lineStyle(2, Color.fromRGB(250, 150, 200));
        graphics.drawCircle(circleX, circleY, circleR);
        graphics.endFill();

        // === MULTIPLE LINES ===

        graphics.lineStyle(3, Color.fromRGB(255, 150, 100), 1, null, ROUND);
        var lineCount = 8;
        for (i in 0...lineCount) {
            var y = 350 + i * 8;
            var wave = Math.sin(time * 4 + i * 0.5) * 20;
            graphics.drawLine(
                550,
                y,
                650 + wave,
                y + Math.cos(time * 3 + i * 0.3) * 5
            );
        }

    }

    override function destroy() {
        super.destroy();
    }

}
