#version 440

// CoverArt's picture, cut to its rounded shape: the new cover over the last one as it
// fades in, both cropped to a square. Drawn straight from the pictures, with no layer in
// between, so it shows from the first frame. After editing, rebuild the .qsb next to it
// with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o cover.frag.qsb cover.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float radius;
    // How much of each picture shows, and the share of it the square takes on each axis.
    float frontAlpha;
    float backAlpha;
    vec2 frontCrop;
    vec2 backCrop;
    // Where each picture sits in Qt's texture atlas, which holds the small ones.
    vec4 qt_SubRect_front;
    vec4 qt_SubRect_back;
};

layout(binding = 1) uniform sampler2D front;
layout(binding = 2) uniform sampler2D back;

// The middle square of a picture that isn't one, at its place in the atlas.
vec2 cropped(vec2 uv, vec2 crop, vec4 place) {
    return place.xy + (0.5 + (uv - 0.5) * crop) * place.zw;
}

void main() {
    // Distance to the rounded edge, a pixel of antialiasing across it.
    vec2 middle = size * 0.5;
    vec2 corner = abs(qt_TexCoord0 * size - middle) - (middle - radius);
    float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
    float inside = clamp(0.5 - distance, 0.0, 1.0);

    // Premultiplied, so the front simply goes over the back. Always the full picture:
    // decoded near the size shown, it needs no smaller levels (which Qt doesn't make here).
    vec4 over = textureLod(front, cropped(qt_TexCoord0, frontCrop, qt_SubRect_front), 0.0) * frontAlpha;
    vec4 under = textureLod(back, cropped(qt_TexCoord0, backCrop, qt_SubRect_back), 0.0) * backAlpha;
    fragColor = (over + under * (1.0 - over.a)) * inside * qt_Opacity;
}
