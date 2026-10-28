import QtQuick

// The privacy dots, for when the island is busy showing something else: green for
// the camera, orange for the microphone, red while the screen is being recorded.
Item {
    id: dot

    property bool camera: false
    property bool microphone: false
    property bool recording: false
    readonly property bool privacy: camera || microphone
    readonly property bool active: privacy || recording

    implicitWidth: dots.implicitWidth + 6
    implicitHeight: 14

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
    }

    GlassSurface {
        radius: dot.height / 2
        tinted: false
    }

    Row {
        id: dots

        anchors.centerIn: parent
        spacing: 4

        Rectangle {
            visible: dot.privacy
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

        Rectangle {
            id: recordingDot

            visible: dot.recording
            width: 8
            height: 8
            radius: 4
            color: "#f38ba8"

            SequentialAnimation on opacity {
                running: recordingDot.visible && dot.visible
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        recordingDot.opacity = 1;

                }

                NumberAnimation {
                    to: 0.3
                    duration: 700
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }

            }

        }

    }

}
