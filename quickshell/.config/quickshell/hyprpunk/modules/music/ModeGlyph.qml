import QtQuick
import Quickshell
import qs.components
import qs.theme

// The player's shuffle and repeat glyphs, drawn in lines with round ends to sit by the
// transport's rounded shapes (modes.frag). Whether a mode is on reads in their color, and
// in their shape changing rather than swapping: shuffle's paths cross, and repeating the
// track grows a "1" in the loop.
ShaderEffect {
    id: glyph

    // "shuffle" or "repeat".
    property string kind: "shuffle"
    property bool shuffles: false
    property bool repeatsTrack: false
    property color color: Colors.primary
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property real loop: kind === "repeat" ? 1 : 0
    // How far shuffle's paths have crossed.
    property real shuffled: shuffles ? 1 : 0
    // How much of the "1" shows.
    property real one: repeatsTrack ? 1 : 0

    fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/modes.frag.qsb"))

    Behavior on shuffled {
        Anim {
            token: Motion.move.normal
        }

    }

    Behavior on one {
        Anim {
            token: Motion.move.normal
        }

    }

}
