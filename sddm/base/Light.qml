import QtQuick

// A plain shape in a light's color (an action armed): drawn in daydream, emitted by the
// glass in neon. What's written on it takes Colors.over.
Item {
    id: light

    property color color: Colors.primary
    property real radius: height / 2

    Rectangle {
        anchors.fill: parent
        visible: !Colors.emits
        radius: light.radius
        color: light.color
    }

    GlassSurface {
        visible: Colors.emits
        radius: light.radius
        lit: true
        backgroundColor: light.color
    }

}
