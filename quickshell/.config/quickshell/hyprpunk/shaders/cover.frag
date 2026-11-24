#version 440

// CoverArt's picture, cut to its rounded shape: the new cover over the last one as it
// fades in, both cropped to a square, and the old one rolling out beside it as the new
// one rolls in, on a track change. Drawn straight from the pictures, with no layer in
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
    float leavingAlpha;
    vec2 frontCrop;
    vec2 backCrop;
    vec2 leavingCrop;
    // How far across each cover stands from its place, in pixels, and how far it has
    // turned, in radians: the new one, and the old one leaving.
    float frontOffset;
    float frontAngle;
    float leavingOffset;
    float leavingAngle;
    // Where each picture sits in Qt's texture atlas, which holds the small ones.
    vec4 qt_SubRect_front;
    vec4 qt_SubRect_back;
    vec4 qt_SubRect_leaving;
};

layout(binding = 1) uniform sampler2D front;
layout(binding = 2) uniform sampler2D back;
layout(binding = 3) uniform sampler2D leaving;

// How much of a pixel (given from the middle) the rounded shape covers, a pixel of
// antialiasing across its edge.
float shape(vec2 point) {
    vec2 middle = size * 0.5;
    vec2 corner = abs(point) - (middle - radius);
    float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
    return clamp(0.5 - distance, 0.0, 1.0);
}

// A pixel (given from the middle) in a cover moved across and turned.
vec2 moved(vec2 point, float offset, float angle) {
    vec2 from = point - vec2(offset, 0.0);
    float c = cos(angle);
    float s = sin(angle);
    return vec2(from.x * c + from.y * s, -from.x * s + from.y * c);
}

// The middle square of a picture that isn't one, at its place in the atlas. Always the
// full picture: decoded near the size shown, it needs no smaller levels (which Qt doesn't
// make here).
vec4 picture(sampler2D image, vec2 point, vec2 crop, vec4 place) {
    vec2 uv = clamp(point / size + 0.5, 0.0, 1.0);
    return textureLod(image, place.xy + (0.5 + (uv - 0.5) * crop) * place.zw, 0.0);
}

void main() {
    vec2 point = qt_TexCoord0 * size - size * 0.5;
    float inside = shape(point);

    // Premultiplied, so the front simply goes over the back. Each cover is its own shape,
    // seen through the cover's place.
    vec2 coming = moved(point, frontOffset, frontAngle);
    float comingInside = min(inside, shape(coming));
    vec4 over = picture(front, coming, frontCrop, qt_SubRect_front) * frontAlpha;
    vec4 under = picture(back, coming, backCrop, qt_SubRect_back) * backAlpha;
    vec4 cover = (over + under * (1.0 - over.a)) * comingInside;

    vec2 going = moved(point, leavingOffset, leavingAngle);
    float goingInside = min(inside, shape(going));
    vec4 old = picture(leaving, going, leavingCrop, qt_SubRect_leaving) * leavingAlpha * goingInside;
    fragColor = (cover + old * (1.0 - cover.a)) * qt_Opacity;
}
