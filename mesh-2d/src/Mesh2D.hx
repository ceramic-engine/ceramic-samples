package;

import ceramic.AlphaColor;
import ceramic.Color;
import ceramic.Mesh;
import ceramic.Scene;
import ceramic.Timer;

class Mesh2D extends Scene {

    /**
     * Displayed mesh
     */
    var mesh:Mesh;

    override function create() {

        // Create a new Mesh object
        mesh = new Mesh();

        // Mesh position
        mesh.pos(
            screen.width * 0.5 - 100,
            screen.height * 0.5 - 100
        );

        // Mesh vertices
        mesh.vertices = [
            0, 0,
            200, 0,
            200, 200,
            0, 200
        ];

        // Mesh triangles
        mesh.indices = [
            0, 1, 2,
            0, 2, 3
        ];

        // Mesh (random) colors
        mesh.colorMapping = VERTICES;
        mesh.colors = [
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random())
        ];

        // // (optional) Mesh texture and uvs
        // mesh.texture = someTexture;
        // mesh.uvs = [
        //     0, 0,
        //     1, 0,
        //     1, 1,
        //     0, 1
        // ];

        add(mesh);

        // Randomize and animate vertices positions and colors every second
        Timer.interval(this, 1.0, randomVertices);

    }

    function randomVertices() {

        inline function rnd() {
            return (Math.random() - 0.5) * 100;
        }

        var prevVertices = [].concat(mesh.vertices);

        var newVertices = [
            0 + rnd(), 0 + rnd(),
            200 + rnd(), 0 + rnd(),
            200 + rnd(), 200 + rnd(),
            0 + rnd(), 200 + rnd()
        ];

        var prevColors = [].concat(mesh.colors);

        var newColors = [
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random()),
            new AlphaColor(Color.random())
        ];

        tween(0.5, 0, 1, (v, t) -> {

            for (i in 0...newVertices.length) {
                mesh.vertices[i] = prevVertices[i] + (newVertices[i] - prevVertices[i]) * v;
            }

            for (i in 0...newColors.length) {
                mesh.colors[i] = new AlphaColor(
                    Color.interpolate(prevColors[i].color, newColors[i].color, v)
                );
            }

        });

    }

}
