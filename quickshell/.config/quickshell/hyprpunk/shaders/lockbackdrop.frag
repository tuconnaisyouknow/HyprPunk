#version 440

// The lock screen's background in one pass (LockSurface): the screen as it was blurs
// and darkens, then the blurred wallpaper comes over it, and under the lock's pills the
// bar's blur shows through their glass until the wallpaper covers it. Every blur is worked
// out once as the lock comes, a few times smaller than the screen: each frame only
// blends them. After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o lockbackdrop.frag.qsb lockbackdrop.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // How blurred the screen is, from 0 (as it was) to 1, how much of the lock's
    // darkening it has, how much the wallpaper covers it, and the wallpaper's zoom.
    float blur;
    float dim;
    float wall;
    float zoom;
    // The pills the lock keeps, in pixels, and how much each is there.
    vec4 pill0;
    vec4 pill1;
    vec4 pill2;
    vec3 pillOpacity;
};

// The screen as it was, then blurred more and more.
layout(binding = 1) uniform sampler2D sharp;
layout(binding = 2) uniform sampler2D soft;
layout(binding = 3) uniform sampler2D mid;
layout(binding = 4) uniform sampler2D heavy;
// The wallpaper as the lock shows it, and as the bar's blur shows it.
layout(binding = 5) uniform sampler2D wallpaperBlur;
layout(binding = 6) uniform sampler2D pillBlur;

// How much of a pill (fully round ends) covers this pixel, its edge smoothed over a pixel.
float coverage(vec2 point, vec4 pill) {
    vec2 halfSize = pill.zw * 0.5;
    float radius = min(halfSize.x, halfSize.y);
    vec2 q = abs(point - pill.xy - halfSize) - (halfSize - radius);
    float outside = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    return clamp(0.5 - outside, 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    // From one blur to the next: three steps, each about three times wider.
    float level = blur * 3.0;
    vec4 screen;
    if (level < 1.0)
        screen = mix(texture(sharp, uv), texture(soft, uv), level);
    else if (level < 2.0)
        screen = mix(texture(soft, uv), texture(mid, uv), level - 1.0);
    else
        screen = mix(texture(mid, uv), texture(heavy, uv), level - 2.0);
    screen.rgb = max(screen.rgb - 0.12 * dim * screen.a, 0.0);

    vec2 point = uv * size;
    float underPill = max(max(pillOpacity.x * coverage(point, pill0), pillOpacity.y * coverage(point, pill1)), pillOpacity.z * coverage(point, pill2));
    screen = mix(screen, texture(pillBlur, uv), underPill);

    vec4 wallColor = texture(wallpaperBlur, (uv - 0.5) / zoom + 0.5);
    fragColor = mix(screen, wallColor, wall) * qt_Opacity;
}
