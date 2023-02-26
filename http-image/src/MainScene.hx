package;

import ceramic.Http;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Texture;
import ceramic.Utils;

class MainScene extends Scene {

    override function create() {

        // Get a random image from the internet
        Http.request({
            url: 'https://picsum.photos/640/480'
        }, response -> {

            if (response.status == 200 && response.binaryContent != null) {

                // Create a texture from binary data
                Texture.fromBytes(response.binaryContent, texture -> {
                    if (texture != null) {

                        // Display the result inside a quad
                        var quad = new Quad();
                        quad.texture = texture;
                        quad.scale(
                            Math.min(width / texture.width, height / texture.height)
                        );
                        add(quad);

                    }
                    else {
                        log.error('Failed to decode binary data');
                    }
                });
            }
            else {
                log.error('Failed to retrieve an image from the internet');
            }
        });

    }

}
