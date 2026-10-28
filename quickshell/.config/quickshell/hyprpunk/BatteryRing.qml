import QtQuick
import QtQuick.Shapes

// An AirPods battery ring, with the pod's letter inside (a bolt while charging)
// and the level below. Used by the popup and the sound page.
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
                strokeColor: Theme.alpha(Theme.surface1, 0.8)
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
                strokeColor: ring.low ? Theme.red : Theme.green
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
            color: ring.charging ? Theme.green : Theme.text
            font.family: Theme.font
            font.pixelSize: ring.charging ? 17 : 13
            font.weight: Font.Bold
        }

    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: ring.level === null ? "--" : ring.level + "%"
        color: ring.low ? Theme.red : Theme.text
        font.family: Theme.font
        font.pixelSize: 17
        font.weight: Font.Medium
    }

}
