#version 440

// LiquidGlass's rim, drawn in a single pass: light that soaks a couple of pixels into
// the edges of a rounded rectangle and fades inward. After editing, rebuild the .qsb
// next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o liquidglass.frag.qsb liquidglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    float rimWidth;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 rimTop;
    vec4 rimMiddle;
    vec4 rimBottom;
};

// How far from the rounded rectangle's edge a point is, negative inside.
float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Close enough to the real erf for a blur's falloff, and cheap.
float erfApprox(float x) {
    float x2 = x * x;
    float t = sqrt(1.0 - exp(-x2 * (1.2732395 + 0.147 * x2) / (1.0 + 0.147 * x2)));
    return x < 0.0 ? -t : t;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = roundedBox(p - size * 0.5, size * 0.5, min(radius, min(size.x, size.y) * 0.5));

    // The shape's own antialiased edge, so nothing leaks outside it.
    float inShape = smoothstep(0.0, 1.0, clamp(0.5 - d, 0.0, 1.0));

    // The shape as if blurred, then only where that blur fades: the band along the edge.
    // These numbers were matched pixel by pixel to the old MultiEffect version.
    float sigma = 1.94 + 0.42 * rimWidth;
    float blurred = 0.5 - 0.5 * erfApprox(d / (sigma * 1.41421356));
    float edge = 1.0 - smoothstep(0.55, 0.81, blurred);

    // The light runs from the top to the bottom of the shape plus 8px around it, as the
    // old version's padded layers did.
    float y = (p.y + 8.0) / (size.y + 16.0);
    vec4 light = y < 0.45 ? mix(rimTop, rimMiddle, y / 0.45) : mix(rimMiddle, rimBottom, (y - 0.45) / 0.55);

    fragColor = light * inShape * edge * qt_Opacity;
}
