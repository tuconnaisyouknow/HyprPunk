#version 440

// The player's transport glyphs (TransportGlyph): two four-cornered shapes, rounded by a
// radius, which a skip (a triangle and its bar) and play and pause (a triangle cut in two,
// two bars) are all made of. Moving the corners morphs one into the other. After
// editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o transport.frag.qsb transport.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // Each shape's corners, in pixels, two to a vector, going round.
    vec4 firstA;
    vec4 firstB;
    vec4 secondA;
    vec4 secondB;
    float radius;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 color;
};

// Brings one edge of a shape into how far the point stands from it and which side it's
// on: crossing an edge's height once more flips inside and outside.
void edge(vec2 point, vec2 from, vec2 to, inout float distance, inout float side) {
    vec2 along = to - from;
    vec2 toPoint = point - from;
    vec2 nearest = toPoint - along * clamp(dot(toPoint, along) / max(dot(along, along), 1e-6), 0.0, 1.0);
    distance = min(distance, dot(nearest, nearest));
    bvec3 crossing = bvec3(point.y >= from.y, point.y < to.y, along.x * toPoint.y > along.y * toPoint.x);
    if (all(crossing) || all(not(crossing)))
        side = -side;
}

// How far a point stands outside a four-cornered shape, negative inside. Corners may
// meet, down to a point or a line, which the rounding then turns into a dot or a bar.
float quad(vec2 point, vec2 v0, vec2 v1, vec2 v2, vec2 v3) {
    float distance = dot(point - v0, point - v0);
    float side = 1.0;
    edge(point, v0, v3, distance, side);
    edge(point, v1, v0, distance, side);
    edge(point, v2, v1, distance, side);
    edge(point, v3, v2, distance, side);
    return side * sqrt(distance);
}

void main() {
    vec2 point = qt_TexCoord0 * size;
    float first = quad(point, firstA.xy, firstA.zw, firstB.xy, firstB.zw);
    float second = quad(point, secondA.xy, secondA.zw, secondB.xy, secondB.zw);
    // A pixel of antialiasing across the edge.
    float coverage = clamp(0.5 - (min(first, second) - radius), 0.0, 1.0);
    fragColor = color * coverage * qt_Opacity;
}
