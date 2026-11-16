import QtQuick
import qs.components
import qs.theme

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

    GlassSurface {
        radius: dot.height / 2
        tinted: false
        backgroundColor: Colors.panel
    }

    BlurShape {
        radius: dot.height / 2
        shown: dot.opacity > 0.5
    }

    Row {
        id: dots

        anchors.centerIn: parent
        spacing: Metrics.spacing.small

        Rectangle {
            visible: dot.privacy
            width: 8
            height: 8
            radius: 4
            color: dot.camera ? Colors.green : Colors.peach

            ColorFade on color {
                token: Motion.color.normal
            }

        }

        Rectangle {
            id: recordingDot

            visible: dot.recording
            width: 8
            height: 8
            radius: 4
            color: Colors.red

            SequentialAnimation on opacity {
                running: recordingDot.visible && dot.visible
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        recordingDot.opacity = 1;

                }

                NumberAnimation {
                    to: 0.3
                    duration: Motion.pulse.duration
                    easing.type: Motion.pulse.easing
                }

                NumberAnimation {
                    to: 1
                    duration: Motion.pulse.duration
                    easing.type: Motion.pulse.easing
                }

            }

        }

    }

}
