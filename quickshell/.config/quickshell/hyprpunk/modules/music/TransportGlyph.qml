import QtQuick
import Quickshell
import qs.components
import qs.theme

// The player's play, pause and skip glyphs, drawn rather than typed so their corners
// round like the progress bar's ends. Each is two four-cornered shapes (transport.frag):
// play is a triangle cut in two and pause its two bars, so one morphs into the other
// instead of swapping, and a skip is a triangle and its bar.
ShaderEffect {
    id: glyph

    // "play", "previous" or "next". Play turns into pause while playing.
    property string kind: "play"
    property bool playing: false
    property color color: Colors.primary
    // How far play has turned into pause.
    property real paused: kind === "play" && playing ? 1 : 0
    // The corners of each shape in a unit square, going round, the two shapes one after
    // the other. Rounding adds its radius all around, so they keep that far from the edge.
    // Play's tip leans right of the middle, where a triangle looks centered.
    readonly property real rounding: 0.08
    readonly property var play: [0.26, 0.14, 0.56, 0.32, 0.56, 0.68, 0.26, 0.86, 0.56, 0.32, 0.86, 0.5, 0.86, 0.5, 0.56, 0.68]
    readonly property var pause: [0.24, 0.14, 0.32, 0.14, 0.32, 0.86, 0.24, 0.86, 0.68, 0.14, 0.76, 0.14, 0.76, 0.86, 0.68, 0.86]
    readonly property var next: [0.16, 0.16, 0.62, 0.5, 0.62, 0.5, 0.16, 0.84, 0.84, 0.16, 0.84, 0.16, 0.84, 0.84, 0.84, 0.84]
    // The corners as drawn, in pixels: on their way between play and pause, or mirrored
    // for previous.
    readonly property var corners: {
        const drawn = [];
        for (let i = 0; i < 16; i += 2) {
            const x = kind === "play" ? play[i] + (pause[i] - play[i]) * paused : kind === "next" ? next[i] : 1 - next[i];
            const y = kind === "play" ? play[i + 1] + (pause[i + 1] - play[i + 1]) * paused : next[i + 1];
            drawn.push(x * width, y * height);
        }
        return drawn;
    }
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property vector4d firstA: Qt.vector4d(corners[0], corners[1], corners[2], corners[3])
    readonly property vector4d firstB: Qt.vector4d(corners[4], corners[5], corners[6], corners[7])
    readonly property vector4d secondA: Qt.vector4d(corners[8], corners[9], corners[10], corners[11])
    readonly property vector4d secondB: Qt.vector4d(corners[12], corners[13], corners[14], corners[15])
    readonly property real radius: rounding * width

    fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/transport.frag.qsb"))

    Behavior on paused {
        Anim {
            token: Motion.move.normal
        }

    }

}
