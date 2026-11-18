import QtQuick
import Quickshell

// The light on GlassSurface's edge: a crisp ring in the classic style, or the lock screen
// clock's liquid glass, where the light soaks a few pixels into the edges and fades
// inward. One shader draws either, so a surface that grows every frame costs nothing to
// redraw: no path to rebuild, no offscreen layer. A surface that emits gets its halo from
// the same pass, in a margin the rim only takes then.
ShaderEffect {
    // The shape, in pixels: the item without the halo's margin.
    readonly property size size: Qt.size(width - 2 * margin, height - 2 * margin)
    property real radius: 18
    // The ring's width, or how far the liquid light reaches into the glass, in pixels.
    property real rimWidth: 1
    property bool liquid: false
    readonly property real soft: liquid ? 1 : 0
    property color rimTop
    property color rimMiddle
    property color rimBottom
    // The halo's color, transparent for none, and how far it reaches.
    property color glow: "transparent"
    readonly property real reach: glow.a > 0 ? 8 : 0
    // The glass itself lighting up, from its edge inward, with no halo around it.
    property bool inward: false
    readonly property real margin: inward ? 0 : reach

    anchors.fill: parent
    anchors.margins: -margin
    fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/glassrim.frag.qsb"))
}
