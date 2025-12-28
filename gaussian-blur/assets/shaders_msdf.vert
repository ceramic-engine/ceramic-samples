#version 300 es

uniform mat4 projectionMatrix;
uniform mat4 modelViewMatrix;

in vec3 vertexPosition;
in vec2 vertexTCoord;
in vec4 vertexColor;

out vec2 tcoord;
out vec4 color;

void main(void) {
    tcoord = vertexTCoord;
    color = vertexColor;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(vertexPosition, 1.0);
    gl_PointSize = 1.0;
}
