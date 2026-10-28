import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Services.UPower

// What the control pill shows: network (a spinner while it connects), caffeine,
// volume and battery. The bar and the lock screen both use it.
RowLayout {
    id: status

    required property var bar
    // Behind the Ethernet padlock badge: the pill's own color.
    property color badgeColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)

    spacing: 10

    // Spinner in place of the icon while NetworkManager connects (VPN included).
    Item {
        implicitWidth: status.bar.networkConnecting ? 16 : networkLabel.implicitWidth
        implicitHeight: networkLabel.implicitHeight

        Label {
            id: networkLabel

            visible: !status.bar.networkConnecting
            text: status.bar.networkIcon()
        }

        Shape {
            id: networkSpinner

            property real sweep: 90

            visible: status.bar.networkConnecting
            anchors.centerIn: parent
            width: 14
            height: 14
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.25)
                strokeWidth: 2

                PathAngleArc {
                    centerX: networkSpinner.width / 2
                    centerY: networkSpinner.height / 2
                    radiusX: networkSpinner.width / 2 - 1
                    radiusY: networkSpinner.height / 2 - 1
                    startAngle: 0
                    sweepAngle: 360
                }

            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: "#cba6f7"
                strokeWidth: 2
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: networkSpinner.width / 2
                    centerY: networkSpinner.height / 2
                    radiusX: networkSpinner.width / 2 - 1
                    radiusY: networkSpinner.height / 2 - 1
                    startAngle: -90
                    sweepAngle: networkSpinner.sweep
                }

            }

            // A plain animation on purpose: an Animator here held the whole shell
            // to 30 frames a second, and everything played in slow motion.
            RotationAnimation on rotation {
                running: networkSpinner.visible
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }

            // The arc stretches and shrinks as it turns.
            SequentialAnimation on sweep {
                running: networkSpinner.visible
                loops: Animation.Infinite

                NumberAnimation {
                    to: 270
                    duration: 700
                    easing.type: Easing.InOutCubic
                }

                NumberAnimation {
                    to: 40
                    duration: 700
                    easing.type: Easing.InOutCubic
                }

            }

        }

        // No locked Ethernet glyph in Material Design: a padlock badge instead.
        Rectangle {
            visible: status.bar.wiredLocked && !status.bar.networkConnecting
            anchors.right: networkLabel.right
            anchors.bottom: networkLabel.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: 1
            width: 11
            height: 11
            radius: width / 2
            color: status.badgeColor

            Label {
                anchors.centerIn: parent
                text: "󰌾"
                font.pixelSize: 9
            }

        }

    }

    // Caffeine on: the computer stays awake.
    Label {
        visible: status.bar.shellState.caffeine
        text: "󰅶"
    }

    IconText {
        visible: status.bar.audioSink !== null
        icon: status.bar.volumeIcon()
        text: status.bar.audioVolume + "%"
    }

    IconText {
        id: batteryPill

        visible: status.bar.hasBattery
        // Red only when it's running out, not while charging.
        color: UPower.onBattery && status.bar.batteryPercent <= 20 ? status.bar.red : status.bar.mauve
        icon: status.bar.batteryIcon()
        text: status.bar.batteryPercent + "%"

        // Pulses from 10 %.
        SequentialAnimation on opacity {
            running: status.bar.hasBattery && UPower.onBattery && status.bar.batteryPercent <= 10
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    batteryPill.opacity = 1;

            }

            NumberAnimation {
                to: 0.4
                duration: 900
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 900
                easing.type: Easing.InOutSine
            }

        }

    }

}
