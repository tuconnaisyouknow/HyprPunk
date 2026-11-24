#version 440

// The player's progress bar (MediaPlayerCard): the round track, and the level filling it
// from the left with a round end, cut to the track's shape. It starts empty and fills
// from its first pixel, its end never past the track's round start, which a narrow
// rounded rectangle couldn't do. After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o progress.frag.qsb progress.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // Where the level ends, in pixels from the left.
    float level;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 trackColor;
    vec4 fillColor;
};

// How far a point (from the middle of the left edge) stands outside a round-ended bar
// between two places along it.
float capsule(vec2 point, float from, float to, float radius) {
    return length(vec2(point.x - clamp(point.x, from, to), point.y)) - radius;
}

void main() {
    vec2 point = qt_TexCoord0 * size - vec2(0.0, size.y * 0.5);
    float radius = size.y * 0.5;
    // A pixel of antialiasing across each edge.
    float track = clamp(0.5 - capsule(point, radius, size.x - radius, radius), 0.0, 1.0);
    float fill = min(track, clamp(0.5 - capsule(point, -size.y, level - radius, radius), 0.0, 1.0));
    fragColor = (fillColor * fill + trackColor * (track - fill)) * qt_Opacity;
}
