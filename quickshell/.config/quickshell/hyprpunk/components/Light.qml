import QtQuick
import qs.theme

// A plain shape in a light's color (the workspace you're on, today's date), or only its
// outline around something to look at (the wallpaper under the selection): drawn in
// daydream, emitted by GlassSurface in neon. What's written on it takes Colors.over.
Item {
    id: light

    property color color: Colors.primary
    property real radius: height / 2
    // Only the outline.
    property bool hollow: false

    Rectangle {
        anchors.fill: parent
        visible: !Colors.emits
        radius: light.radius
        color: light.hollow ? "transparent" : light.color
        border.width: light.hollow ? 2 : 0
        border.color: light.color
    }

    GlassSurface {
        visible: Colors.emits
        radius: light.radius
        tinted: false
        lit: true
        hollow: light.hollow
        backgroundColor: light.color
    }

}
