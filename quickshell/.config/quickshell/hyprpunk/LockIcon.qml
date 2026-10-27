import QtQuick
import QtQuick.Shapes

// The lock screen's padlock, drawn so it can move: closing, the shackle swings back
// over the body and drops into it with a small click; opening, it pops up and swings
// round its right leg. Starts open unless closed is set from the start.
Item {
    id: icon

    property bool closed: false
    property color color: "#cba6f7"
    // The shackle's two positions: down in the body, or lifted and swung out.
    readonly property real downY: 1
    readonly property real upY: -2.5
    readonly property real openAngle: -165

    implicitWidth: 14
    implicitHeight: 17

    Component.onCompleted: {
        shackle.y = closed ? downY : upY;
        swing.angle = closed ? 0 : openAngle;
    }
    onClosedChanged: {
        openAnimation.stop();
        closeAnimation.stop();
        if (closed)
            closeAnimation.start();
        else
            openAnimation.start();
    }

    Shape {
        id: shackle

        x: 2.6
        width: 8.8
        height: 9
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: icon.color
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            startX: 1
            startY: 9

            PathLine {
                x: 1
                y: 4.4
            }

            PathArc {
                x: 7.8
                y: 4.4
                radiusX: 3.4
                radiusY: 3.4
            }

            PathLine {
                x: 7.8
                y: 9
            }

        }

        transform: Rotation {
            id: swing

            origin.x: 7.8
            origin.y: 0
            axis {
                x: 0
                y: 1
                z: 0
            }
        }

    }

    Rectangle {
        id: body

        y: 7.5
        width: 14
        height: 9.5
        radius: 2.6
        color: icon.color

        // The keyhole.
        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: 3.6
            radius: 1
            color: "#1e1e2e"
        }

    }

    SequentialAnimation {
        id: closeAnimation

        NumberAnimation {
            target: swing
            property: "angle"
            to: 0
            duration: 320
            easing.type: Easing.InOutCubic
        }

        NumberAnimation {
            target: shackle
            property: "y"
            to: icon.downY
            duration: 160
            easing.type: Easing.InCubic
        }

        // The click: the body gives a little under the shackle.
        NumberAnimation {
            target: body
            property: "scale"
            to: 0.9
            duration: 70
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: body
            property: "scale"
            to: 1
            duration: 220
            easing.type: Easing.OutBack
        }

    }

    SequentialAnimation {
        id: openAnimation

        NumberAnimation {
            target: shackle
            property: "y"
            to: icon.upY
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: swing
            property: "angle"
            to: icon.openAngle
            duration: 380
            easing.type: Easing.OutBack
        }

    }

}
