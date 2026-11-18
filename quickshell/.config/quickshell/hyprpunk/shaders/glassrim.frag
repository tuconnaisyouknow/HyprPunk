#version 440

// GlassRim's light on the edge of a rounded rectangle, drawn in a single pass: a crisp
// ring in the classic style, light soaking a few pixels in and fading inward in the
// liquid one. A surface that emits also glows: a halo around the edge, drawn in the margin
// the item keeps around the shape. After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o glassrim.frag.qsb glassrim.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    // Classic: the ring's width. Liquid: how far the light reaches into the glass.
    float rimWidth;
    // 1 for the liquid style, 0 for the classic one.
    float soft;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 rimTop;
    vec4 rimMiddle;
    vec4 rimBottom;
    // The halo of a surface that emits and how far it reaches, nothing at all where the
    // alpha is 0. It spreads around the shape, in the margin the item keeps around it, or
    // with no margin lights the glass from its edge inward.
    vec4 glow;
    float reach;
    float margin;
};

// How far from the rounded rectangle's edge a point is, negative inside.
float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// How much of a pixel a shape covers, from its distance to the shape's edge.
float coverage(float d) {
    return clamp(0.5 - d, 0.0, 1.0);
}

// Close enough to the real erf for a blur's falloff, and cheap.
float erfApprox(float x) {
    float x2 = x * x;
    float t = sqrt(1.0 - exp(-x2 * (1.2732395 + 0.147 * x2) / (1.0 + 0.147 * x2)));
    return x < 0.0 ? -t : t;
}

// The liquid light: the shape as if blurred, then only where that blur fades, the band
// along the edge. These numbers were matched pixel by pixel to the old MultiEffect version.
float liquidEdge(float d) {
    float sigma = 1.94 + 0.42 * rimWidth;
    float blurred = 0.5 - 0.5 * erfApprox(d / (sigma * 1.41421356));
    return smoothstep(0.0, 1.0, coverage(d)) * (1.0 - smoothstep(0.55, 0.81, blurred));
}

// The classic ring: the shape minus the same shape inset by the ring's width, its corners
// shrunk alike, as the two rectangles of the old Shape cut it.
float ring(vec2 p, float d, float r) {
    vec2 innerHalf = max(size * 0.5 - rimWidth, vec2(0.0));
    float inner = roundedBox(p, innerHalf, max(r - rimWidth, 0.0));
    return coverage(d) - coverage(inner);
}

// Light falling off with the distance to the edge.
float bell(float d, float sigma) {
    return exp(-d * d / (2.0 * sigma * sigma));
}

// The halo: light falling off on both sides of the edge, further outward than into the
// tube, and gone where the item's margin ends. A glass lit inward has three lights
// instead: a bright line right at its edge, what that line sheds a few pixels in, and a
// faint bloom soaking deep into the glass.
float halo(float d) {
    if (margin == 0.0)
        return coverage(d) * (0.9 * bell(d, 1.2) + 0.6 * bell(d, reach / 2.6) + 0.3 * bell(d, reach * 1.6));

    return bell(d, d > 0.0 ? reach / 2.6 : reach / 4.0) * (1.0 - smoothstep(0.7 * reach, reach, d));
}

void main() {
    vec2 p = qt_TexCoord0 * (size + 2.0 * margin) - margin;
    vec2 centered = p - size * 0.5;
    float r = min(radius, min(size.x, size.y) * 0.5);
    float d = roundedBox(centered, size * 0.5, r);

    float edge = mix(ring(centered, d, r), liquidEdge(d), soft);

    // The light runs from the top to the bottom: of the shape for the ring, of the shape
    // plus 8px around it for the liquid light, as the old version's padded layers did.
    float pad = 8.0 * soft;
    float y = clamp((p.y + pad) / (size.y + 2.0 * pad), 0.0, 1.0);
    vec4 light = y < 0.45 ? mix(rimTop, rimMiddle, y / 0.45) : mix(rimMiddle, rimBottom, (y - 0.45) / 0.55);

    vec4 color = light * edge;
    // Emitted light adds to what's behind rather than covering it: half the alpha.
    if (glow.a > 0.0)
        color = min(color + glow * halo(d) * vec4(1.0, 1.0, 1.0, 0.5), vec4(1.0));

    fragColor = color * qt_Opacity;
}
