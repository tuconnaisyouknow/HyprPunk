#version 440

// The lock screen's background in one pass (LockSurface): the screen as it was blurs
// and darkens, then the blurred wallpaper comes over it, and under the lock's pills the
// bar's blur shows through their glass until the wallpaper covers it. Every blur is worked
// out once as the lock comes, a few times smaller than the screen: each frame only
// blends them. In neon, a wrong password glitches it for a moment: bands torn sideways,
// their colors pulled apart, and thin lines of the error's red. After editing, rebuild
// the .qsb next to it with
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
    // The glitch: how strong, 0 for none, a number that changes its pattern, and the
    // color of its lines.
    float glitch;
    float glitchSeed;
    vec4 glitchColor;
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

// A number between 0 and 1 that looks random, the same for the same input.
float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

// The background at a point of the screen.
vec4 backdrop(vec2 uv) {
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
    return mix(screen, wallColor, wall);
}

void main() {
    vec2 uv = qt_TexCoord0;
    if (glitch <= 0.0) {
        fragColor = backdrop(uv) * qt_Opacity;
        return;
    }

    // About a band in four is torn sideways, by up to a twentieth of the screen.
    float band = floor(uv.y * 14.0 + glitchSeed * 7.3);
    float torn = step(0.72, hash(band + glitchSeed * 31.0));
    vec2 at = vec2(uv.x + (hash(band * 3.1 + glitchSeed) - 0.5) * 0.1 * glitch * torn, uv.y);

    // Red and blue pulled apart, further in the torn bands. The background is a blur, so
    // it takes this much to show.
    vec2 split = vec2((0.006 + 0.02 * torn) * glitch, 0.0);
    vec4 color = backdrop(at);
    color.r = backdrop(at + split).r;
    color.b = backdrop(at - split).b;

    // A few lines, three pixels each, lit in the error's color.
    float line = floor(uv.y * size.y / 3.0);
    float lit = step(0.985, hash(line * 1.7 + glitchSeed * 53.0));
    color.rgb = min(color.rgb + glitchColor.rgb * lit * 0.7 * glitch, vec3(1.0));

    fragColor = color * qt_Opacity;
}
