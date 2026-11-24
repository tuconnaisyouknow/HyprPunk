#version 440

// The player's shuffle and repeat glyphs (ModeGlyph): lines with round ends, drawn as one
// distance so crossings and joins never overlap, even at half opacity. Shuffle's two
// paths run side by side while it's off and cross while it's on, and repeat's "1" grows
// out of the loop's middle for repeating the track. After editing, rebuild the .qsb
// next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o modes.frag.qsb modes.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // 0 for shuffle, 1 for repeat.
    float loop;
    // How far shuffle's paths have crossed.
    float shuffled;
    // How much of the "1" shows.
    float one;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 color;
};

// The lines' half width, in the glyph's unit square.
const float stroke = 0.055;

// How far a point stands from a line between two places.
float line(vec2 point, vec2 from, vec2 to) {
    vec2 along = to - from;
    vec2 toPoint = point - from;
    return length(toPoint - along * clamp(dot(toPoint, along) / max(dot(along, along), 1e-6), 0.0, 1.0));
}

// How far a point stands from a quarter of a circle, the one on the given side of its
// center.
float corner(vec2 point, vec2 center, float radius, vec2 side) {
    vec2 toPoint = point - center;
    if (toPoint.x * side.x >= 0.0 && toPoint.y * side.y >= 0.0)
        return abs(length(toPoint) - radius);
    return min(length(toPoint - vec2(side.x * radius, 0.0)), length(toPoint - vec2(0.0, side.y * radius)));
}

// An arrowhead's two sides, from its tip back along the given direction.
float arrow(vec2 point, vec2 tip, vec2 back) {
    vec2 across = vec2(-back.y, back.x);
    return min(line(point, tip, tip + 0.09 * (back + across)), line(point, tip, tip + 0.09 * (back - across)));
}

// Two paths, each going to the other's side as they cross, the one going down broken
// where the other goes over it. Off, both run straight on.
float shuffle(vec2 p) {
    float upEnd = 0.76 - 0.52 * shuffled;
    float downEnd = 0.24 + 0.52 * shuffled;
    float up = min(min(line(p, vec2(0.12, 0.76), vec2(0.3, 0.76)), line(p, vec2(0.3, 0.76), vec2(0.62, upEnd))), line(p, vec2(0.62, upEnd), vec2(0.86, upEnd)));
    // The break follows where they cross, which only happens past halfway, and opens as
    // they do.
    vec2 from = vec2(0.3, 0.24);
    vec2 along = vec2(0.62, downEnd) - from;
    float crossing = 0.5 / max(shuffled, 0.5);
    float gap = 0.2875 * clamp(2.0 * shuffled - 1.0, 0.0, 1.0);
    float slope = min(line(p, from, from + along * (crossing - gap)), line(p, from + along * min(crossing + gap, 1.0), from + along));
    float down = min(min(line(p, vec2(0.12, 0.24), from), slope), line(p, vec2(0.62, downEnd), vec2(0.86, downEnd)));
    float heads = min(arrow(p, vec2(0.86, upEnd), vec2(-1.0, 0.0)), arrow(p, vec2(0.86, downEnd), vec2(-1.0, 0.0)));
    return min(min(up, down), heads);
}

// A loop of two arrows going round, and the "1" in its middle.
float repeat(vec2 p) {
    float top = min(min(line(p, vec2(0.16, 0.56), vec2(0.16, 0.38)), corner(p, vec2(0.3, 0.38), 0.14, vec2(-1.0, -1.0))), line(p, vec2(0.3, 0.24), vec2(0.84, 0.24)));
    float bottom = min(min(line(p, vec2(0.84, 0.44), vec2(0.84, 0.62)), corner(p, vec2(0.7, 0.62), 0.14, vec2(1.0, 1.0))), line(p, vec2(0.7, 0.76), vec2(0.16, 0.76)));
    float heads = min(arrow(p, vec2(0.84, 0.24), vec2(-1.0, 0.0)), arrow(p, vec2(0.16, 0.76), vec2(1.0, 0.0)));
    // Scaled from the middle, so it grows out of nothing, and gone at nothing.
    float digit = 1.0;
    if (one > 0.0) {
        vec2 q = vec2(0.5) + (p - vec2(0.5)) / one;
        digit = (min(line(q, vec2(0.52, 0.39), vec2(0.52, 0.61)), line(q, vec2(0.46, 0.44), vec2(0.52, 0.39))) - stroke) * one + stroke;
    }
    return min(min(top, bottom), min(heads, digit));
}

void main() {
    vec2 p = qt_TexCoord0;
    float distance = (loop < 0.5 ? shuffle(p) : repeat(p)) - stroke;
    // A pixel of antialiasing across the edge.
    float coverage = clamp(0.5 - distance * size.x, 0.0, 1.0);
    fragColor = color * coverage * qt_Opacity;
}
