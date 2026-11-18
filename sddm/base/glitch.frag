#version 440

// The login screen's glitch at a wrong password, over the theme's video (Main.qml), the
// lock screen's own (the shell's lockbackdrop.frag): bands torn sideways, their colors
// pulled apart, and thin lines of the error's red. A copy rather than the shell's file:
// SDDM can't read your home. After editing, rebuild the .qsb next to it with
//   /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o glitch.frag.qsb glitch.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // How strong, a number that changes its pattern, and the color of its lines.
    float glitch;
    float glitchSeed;
    vec4 glitchColor;
};

// The video as it plays.
layout(binding = 1) uniform sampler2D source;

// A number between 0 and 1 that looks random, the same for the same input.
float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;

    // About a band in four is torn sideways, by up to a twentieth of the screen.
    float band = floor(uv.y * 14.0 + glitchSeed * 7.3);
    float torn = step(0.72, hash(band + glitchSeed * 31.0));
    vec2 at = vec2(uv.x + (hash(band * 3.1 + glitchSeed) - 0.5) * 0.1 * glitch * torn, uv.y);

    // Red and blue pulled apart, further in the torn bands. The video is sharp, so it
    // takes less than the lock screen's blur.
    vec2 split = vec2((0.003 + 0.01 * torn) * glitch, 0.0);
    vec4 color = texture(source, at);
    color.r = texture(source, at + split).r;
    color.b = texture(source, at - split).b;

    // A few lines, three pixels each, lit in the error's color.
    float line = floor(uv.y * size.y / 3.0);
    float lit = step(0.985, hash(line * 1.7 + glitchSeed * 53.0));
    color.rgb = min(color.rgb + glitchColor.rgb * lit * 0.7 * glitch, vec3(1.0));

    fragColor = color * qt_Opacity;
}
