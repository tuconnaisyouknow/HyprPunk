import QtQuick
import QtQuick.Effects

// The lock screen clock's liquid glass on a rounded rectangle, for GlassSurface's liquid
// mode. Instead of a crisp 1px ring, the light soaks a few pixels into the edges and
// fades inward, like on the minutes.
Item {
    id: liquid

    property real radius: 18
    // How far the light reaches into the glass, in pixels.
    property real rimWidth: 3
    property color rimTop
    property color rimMiddle
    property color rimBottom
    // Room around the shape, so the blur fades to nothing instead of stopping at the edge.
    readonly property int padding: 8

    anchors.fill: parent

    // The shape, white, for the masks.
    Item {
        id: shape

        anchors.fill: parent
        anchors.margins: -liquid.padding
        visible: false
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: liquid.padding
            radius: liquid.radius
            color: "white"
        }

    }

    // The shape blurred a little: what stays opaque is its inside, without the edges.
    Item {
        id: shapeInner

        anchors.fill: shape
        visible: false
        layer.enabled: true

        MultiEffect {
            anchors.fill: parent
            source: shape
            autoPaddingEnabled: false
            blurEnabled: true
            blur: Math.min(1, liquid.rimWidth / 16)
            blurMax: 16
        }

    }

    Rectangle {
        id: rimLight

        anchors.fill: shape
        visible: false
        layer.enabled: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: liquid.rimTop
            }

            GradientStop {
                position: 0.45
                color: liquid.rimMiddle
            }

            GradientStop {
                position: 1
                color: liquid.rimBottom
            }

        }

    }

    // The light inside the shape only.
    Item {
        id: rimInShape

        anchors.fill: shape
        visible: false
        layer.enabled: true

        MultiEffect {
            anchors.fill: parent
            source: rimLight
            maskEnabled: true
            maskSource: shape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

    }

    // Then only where the blurred shape fades, along the edges.
    MultiEffect {
        anchors.fill: shape
        source: rimInShape
        maskEnabled: true
        maskSource: shapeInner
        maskInverted: true
        maskThresholdMin: 0.85
        maskSpreadAtMin: 0.15
    }

}
