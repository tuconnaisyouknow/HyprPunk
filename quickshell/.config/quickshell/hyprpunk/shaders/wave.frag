#version 440

// VisualizerWave's wave, drawn on the GPU: the music's levels go in, mirrored with the
// low notes in the middle, and each pixel finds the wave's height through the same
// Catmull-Rom curve the levels used to be traced with. After editing, rebuild the .qsb
// next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o wave.frag.qsb wave.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float presence;
    // The 24 levels, from 0 to 1, low notes first, four by four.
    vec4 levels0;
    vec4 levels1;
    vec4 levels2;
    vec4 levels3;
    vec4 levels4;
    vec4 levels5;
    // Qt hands colors over premultiplied, ready to blend.
    vec4 topColor;
    vec4 bottomColor;
};

const int LEVELS = 24;
// The floor at both ends, and the levels mirrored in between.
const int POINTS = 2 * LEVELS + 2;

float level(int i) {
    vec4 group = i < 4 ? levels0 : i < 8 ? levels1 : i < 12 ? levels2 : i < 16 ? levels3 : i < 20 ? levels4 : levels5;
    int j = i - (i / 4) * 4;
    return clamp(j == 0 ? group.x : j == 1 ? group.y : j == 2 ? group.z : group.w, 0.0, 1.0);
}

// How high the wave stands at a point, as a share of its height. The ends stay on the
// floor, the sides are softened so the highs don't stand up as walls, and presence
// melts it from the sides first.
float pointHeight(int k) {
    if (k <= 0 || k >= POINTS - 1)
        return 0.0;
    float t = float(k) / float(POINTS - 1);
    int mirrored = k - 1 < LEVELS ? LEVELS - k : k - 1 - LEVELS;
    float envelope = pow(sin(3.14159265 * t), 0.6);
    float standing = clamp(2.0 * presence - abs(2.0 * t - 1.0), 0.0, 1.0);
    return level(mirrored) * envelope * standing * standing * (3.0 - 2.0 * standing);
}

void main() {
    // Which stretch between two points the pixel is on, and how far along it.
    float along = qt_TexCoord0.x * float(POINTS - 1);
    int i = int(clamp(floor(along), 0.0, float(POINTS - 2)));
    float u = along - float(i);

    float p0 = pointHeight(max(i - 1, 0));
    float p1 = pointHeight(i);
    float p2 = pointHeight(i + 1);
    float p3 = pointHeight(min(i + 2, POINTS - 1));
    // Catmull-Rom: through every point, no corner anywhere.
    float share = 0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u * u * u);

    float y = qt_TexCoord0.y * size.y;
    float surface = size.y - max(share, 0.0) * (size.y - 4.0);
    // Antialiased along the curve, however steep: the distance in pixels across it.
    float below = y - surface;
    float coverage = clamp(below / max(fwidth(below), 1e-4) + 0.5, 0.0, 1.0);

    fragColor = mix(topColor, bottomColor, qt_TexCoord0.y) * coverage * qt_Opacity;
}
