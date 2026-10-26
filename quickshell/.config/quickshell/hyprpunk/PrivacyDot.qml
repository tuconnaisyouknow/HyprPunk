import QtQuick

// The privacy dot out of the island (beside a card covering it): green for the camera,
// orange for the microphone, in a ring of the pills' card as thick as the player's.
Item {
    id: dot

    property bool camera: false

    implicitWidth: 14
    implicitHeight: 14

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
    }

    GlassSurface {
        radius: dot.width / 2
        tinted: false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: 4
        color: dot.camera ? "#a6e3a1" : "#fab387"

        Behavior on color {
            ColorAnimation {
                duration: 200
            }

        }

    }

}
