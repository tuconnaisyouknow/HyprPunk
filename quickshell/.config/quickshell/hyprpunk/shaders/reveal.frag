#version 440

// An icon while it changes (IconMorph): the new drawing shows inside a band that sweeps
// across the icon, the old one outside it, mixed in one pass so the band's soft edge
// never lets the background through. The band runs between two lines across a
// direction, or between two circles around a center, so a level rises, a slash cuts or
// a change spreads from where it happens. Or the new drawing takes over everywhere at
// once, by an amount. Without an old drawing, it only keeps the new one inside the band.
// After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o reveal.frag.qsb reveal.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The drawing's size in pixels.
    vec2 size;
    // 0 across a direction, 1 around a center.
    float circular;
    // The direction, or the center, in pixels.
    vec2 origin;
    // Where the band starts and ends, in pixels along the direction or from the center.
    float from;
    float to;
    // How far the new drawing has taken over outside the band, from 0 to 1.
    float fade;
};

layout(binding = 1) uniform sampler2D before;
layout(binding = 2) uniform sampler2D after;

void main() {
    vec2 point = qt_TexCoord0 * size;
    float along = circular > 0.5 ? length(point - origin) : dot(point, origin);
    // Inside the band, with a pixel of antialiasing at each of its edges.
    float low = min(from, to);
    float high = max(from, to);
    float band = clamp(along - low + 0.5, 0.0, 1.0) * clamp(high - along + 0.5, 0.0, 1.0);
    fragColor = mix(texture(before, qt_TexCoord0), texture(after, qt_TexCoord0), max(band, fade)) * qt_Opacity;
}
