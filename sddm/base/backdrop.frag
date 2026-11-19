#version 440

// What's behind a pill's glass on the login screen (Pill.qml): its own piece of the video
// blurred, cut to its rounded shape. Hyprland does this for the shell's pills, and SDDM
// has no one to ask. After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o backdrop.frag.qsb backdrop.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The pill, in pixels.
    vec2 size;
    float radius;
    // Where it is in the blurred picture, as shares of it: x, y, width and height.
    vec4 place;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    // How far from the rounded shape's edge this pixel is, negative inside.
    vec2 p = (qt_TexCoord0 - 0.5) * size;
    float r = min(radius, min(size.x, size.y) * 0.5);
    vec2 q = abs(p) - size * 0.5 + r;
    float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;

    fragColor = texture(source, place.xy + qt_TexCoord0 * place.zw) * clamp(0.5 - d, 0.0, 1.0) * qt_Opacity;
}
