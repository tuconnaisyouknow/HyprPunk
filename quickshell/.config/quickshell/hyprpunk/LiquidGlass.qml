import QtQuick

// The lock screen clock's liquid glass on a rounded rectangle, for GlassSurface's liquid
// mode. Instead of a crisp 1px ring, the light soaks a few pixels into the edges and
// fades inward, like on the minutes. One shader draws it, so a surface that grows every
// frame costs no offscreen layers.
ShaderEffect {
    // The shader reads it in pixels.
    readonly property size size: Qt.size(width, height)
    property real radius: 18
    // How far the light reaches into the glass, in pixels.
    property real rimWidth: 3
    property color rimTop
    property color rimMiddle
    property color rimBottom

    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")
}
