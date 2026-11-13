import QtQuick

// The music as one smooth wave rising from its bottom edge, for the desktop's visualizer
// and the lock screen. It fades in while a player plays and away when it stops. The GPU
// draws it (shaders/wave.frag): only the levels change at each frame, where tracing the
// curve here kept a core busy.
ShaderEffect {
    id: wave

    // A CavaLevels.
    required property var music
    // How much of the wave stands, from 0 (melted into the floor) to 1. It goes from the
    // sides first and comes back from the middle out, so it settles and rises rather
    // than only shrinking.
    property real presence: 1
    readonly property vector2d size: Qt.vector2d(width, height)
    readonly property var levels: music.levels
    readonly property vector4d levels0: group(0)
    readonly property vector4d levels1: group(1)
    readonly property vector4d levels2: group(2)
    readonly property vector4d levels3: group(3)
    readonly property vector4d levels4: group(4)
    readonly property vector4d levels5: group(5)
    readonly property color topColor: Theme.alpha(Theme.primary, 0.85)
    readonly property color bottomColor: Theme.alpha(Theme.secondary, 0.15)

    // Four levels at a time, as the shader takes them: none while nothing plays.
    function group(index) {
        const at = (i) => {
            return levels[4 * index + i] || 0;
        };
        return Qt.vector4d(at(0), at(1), at(2), at(3));
    }

    fragmentShader: Qt.resolvedUrl("shaders/wave.frag.qsb")
    opacity: music.playing ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 600
            easing.type: Easing.InOutSine
        }

    }

}
