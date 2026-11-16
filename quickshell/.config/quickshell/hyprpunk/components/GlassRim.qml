import QtQuick
import Quickshell

// The light on GlassSurface's edge: a crisp ring in the classic style, or the lock screen
// clock's liquid glass, where the light soaks a few pixels into the edges and fades
// inward. One shader draws either, so a surface that grows every frame costs nothing to
// redraw: no path to rebuild, no offscreen layer.
ShaderEffect {
    // The shader reads it in pixels.
    readonly property size size: Qt.size(width, height)
    property real radius: 18
    // The ring's width, or how far the liquid light reaches into the glass, in pixels.
    property real rimWidth: 1
    property bool liquid: false
    readonly property real soft: liquid ? 1 : 0
    property color rimTop
    property color rimMiddle
    property color rimBottom

    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/glassrim.frag.qsb"))
}
