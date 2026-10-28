import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Round album cover, spun like a record by the bar's music pill.
Item {
    id: disc

    property url source
    // Blank record shown until the cover is loaded (crust and mauve).
    property color vinylColor: Theme.crust
    property color labelColor: Theme.mauve
    // Decoding size, 0 = the displayed size (set it when the disc is resized).
    property int decodeSize: 0
    readonly property int status: art.status

    Item {
        id: vinyl

        anchors.fill: parent
        opacity: art.status === Image.Ready ? 0 : 1

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: disc.vinylColor
        }

        // Grooves.
        Repeater {
            model: [0.84, 0.68]

            Rectangle {
                required property real modelData

                anchors.centerIn: parent
                width: parent.width * modelData
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.07)
                antialiasing: true
            }

        }

        // Light reflected on one side only, so the spinning shows.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(Theme.text, 0.28)
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: disc.width / 2
                    centerY: disc.height / 2
                    radiusX: disc.width * 0.38
                    radiusY: disc.height * 0.38
                    startAngle: 200
                    sweepAngle: 55
                }

            }

        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.4
            height: width
            radius: width / 2
            color: disc.labelColor
            antialiasing: true

            Rectangle {
                anchors.centerIn: parent
                width: 3
                height: 3
                radius: 1.5
                color: disc.vinylColor
                antialiasing: true
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }

        }

    }

    Image {
        id: art

        anchors.fill: parent
        source: disc.source
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        // Decoded at the size it's shown: letting the GPU shrink the 640px art
        // leaves ragged black edges on some covers.
        sourceSize.width: disc.decodeSize > 0 ? disc.decodeSize : width
        sourceSize.height: disc.decodeSize > 0 ? disc.decodeSize : height
        visible: false
    }

    // MultiEffect for the round mask, a ClippingRectangle drew it half a pixel off.
    Rectangle {
        id: artMask

        anchors.fill: parent
        radius: width / 2
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        // A cover arriving late (slow network) fades in over the placeholder.
        opacity: art.status === Image.Ready ? 1 : 0
        maskEnabled: true
        maskSource: artMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1

        Behavior on opacity {
            NumberAnimation {
                duration: 220
            }

        }

    }

}
