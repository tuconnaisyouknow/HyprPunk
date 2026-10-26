import QtQuick
import QtQuick.Shapes

// Battery ring of the AirPods (the popup and the control center's sound page): a bolt
// inside while charging, else the pod's letter, the level below.
Column {
    id: ring

    // {level, charging, label}, level 0-100 or null when unknown.
    property var battery: null
    readonly property var level: battery !== null ? battery.level : null
    readonly property bool charging: battery !== null && battery.charging
    readonly property bool low: level !== null && level <= 20 && !charging

    spacing: 6

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 40
        height: 40

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(69 / 255, 71 / 255, 90 / 255, 0.8)
                strokeWidth: 4
                fillColor: "transparent"

                PathAngleArc {
                    centerX: 20
                    centerY: 20
                    radiusX: 18
                    radiusY: 18
                    startAngle: 0
                    sweepAngle: 360
                }

            }

            ShapePath {
                strokeColor: ring.low ? "#f38ba8" : "#a6e3a1"
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: 20
                    centerY: 20
                    radiusX: 18
                    radiusY: 18
                    startAngle: -90
                    sweepAngle: ring.level === null ? 0 : 3.6 * ring.level

                    Behavior on sweepAngle {
                        NumberAnimation {
                            duration: 450
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

        Text {
            anchors.centerIn: parent
            text: ring.charging ? "󱐋" : ring.battery !== null && ring.battery.label ? ring.battery.label : ""
            color: ring.charging ? "#a6e3a1" : "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: ring.charging ? 17 : 13
            font.weight: Font.Bold
        }

    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.level === null ? "--" : ring.level + "%"
        color: ring.low ? "#f38ba8" : "#cdd6f4"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
        font.weight: Font.Medium
    }

}
