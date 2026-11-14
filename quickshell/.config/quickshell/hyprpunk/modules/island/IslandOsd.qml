import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.theme

// Everything the island can briefly show: a level (volume, brightness), an on/off
// switch, the screenshot you just took, battery alerts and the AirPods.
// The bar's island and the lock screen's both use it.
RowLayout {
    id: osd

    required property var bar

    spacing: 8

    Text {
        visible: bar.statusOsdVisible && bar.statusOsdKind === ""
        text: bar.statusOsdIcon
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: 20
    }

    // Volume and screen brightness only show their icon and bar.
    Text {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel <= 10
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        text: bar.statusOsdLabel
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: 15
        font.weight: Font.Bold
    }

    Rectangle {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel <= 0
        implicitWidth: statusOsdStateText.implicitWidth + 16
        implicitHeight: 24
        radius: 12
        color: bar.statusOsdEnabled ? Colors.primary : Colors.surface1

        Text {
            id: statusOsdStateText

            anchors.centerIn: parent
            text: bar.statusOsdEnabled ? "On" : "Off"
            color: bar.statusOsdEnabled ? Colors.base : Colors.secondary
            font.family: Metrics.font
            font.pixelSize: 12
            font.weight: Font.Bold
        }

    }

    Row {
        readonly property int segments: bar.statusOsdMaxLevel
        readonly property int filled: bar.statusOsdLevel

        visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel > 0 && bar.statusOsdMaxLevel <= 10
        spacing: 4

        Repeater {
            model: parent.segments

            Rectangle {
                required property int index

                width: 18
                height: 8
                radius: 4
                color: index < parent.filled ? Colors.primary : Colors.surface1

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

        }

    }

    // Screenshot: a thumbnail, then where it went.
    ClippingRectangle {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
        implicitWidth: Math.round(30 * Math.min(1.8, Math.max(0.6, screenshotThumbnail.implicitWidth / Math.max(1, screenshotThumbnail.implicitHeight))))
        implicitHeight: 30
        radius: 6
        color: Colors.surface1

        Image {
            id: screenshotThumbnail

            anchors.fill: parent
            source: bar.statusOsdKind === "screenshot" && bar.statusOsdImage !== "" ? "file://" + bar.statusOsdImage : ""
            sourceSize.height: 90
            fillMode: Image.PreserveAspectCrop
            cache: false
            smooth: true
            mipmap: true
        }

        // A recording's play sign.
        Text {
            anchors.centerIn: parent
            visible: bar.statusOsdTitle === "Recording"
            text: "󰐊"
            color: Colors.primary
            style: Text.Outline
            styleColor: Colors.alpha(Colors.crust, 0.6)
            font.family: Metrics.font
            font.pixelSize: 14
        }

    }

    Column {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
        Layout.leftMargin: 2
        spacing: 0

        Text {
            text: bar.statusOsdTitle
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            text: bar.statusOsdLabel
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: 11
        }

    }

    // Battery: green when plugged in, the accent when unplugged, red when low (pulsing when
    // it's critical), with the time left or until full.
    Text {
        id: batteryOsdIcon

        visible: bar.statusOsdVisible && bar.statusOsdKind === "battery"
        text: Icons.battery(bar.battery.percentage, UPower.onBattery)
        color: bar.batteryOsdColor()
        font.family: Metrics.font
        font.pixelSize: 22

        SequentialAnimation on opacity {
            running: bar.batteryCritical && batteryOsdIcon.visible
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    batteryOsdIcon.opacity = 1;

            }

            NumberAnimation {
                to: 0.35
                duration: 600
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 600
                easing.type: Easing.InOutSine
            }

        }

    }

    Column {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "battery"
        Layout.leftMargin: 2
        spacing: 0

        Text {
            text: bar.statusOsdLabel
            color: bar.batteryOsdColor()
            font.family: Metrics.font
            font.pixelSize: 14
            font.weight: Font.Bold
        }

        Text {
            text: bar.batteryDetail()
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: 11
        }

    }

    // AirPods: the pods on the left, their battery ring on the right.
    Item {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
        // As tall as the battery ring.
        implicitWidth: 40
        implicitHeight: 26

        Image {
            id: airPodsOsdImage

            anchors.fill: parent
            source: bar.statusOsdImage !== "" ? "file://" + bar.statusOsdImage : ""
            fillMode: Image.PreserveAspectFit
            sourceSize.height: 60
            smooth: true
            mipmap: true
        }

        // No picture yet (or AirPods Max): the glyph instead.
        Text {
            visible: airPodsOsdImage.status !== Image.Ready
            anchors.centerIn: parent
            text: "󱡏"
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: 22
        }

    }

    Item {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
        implicitWidth: 136
        implicitHeight: 1
    }

    Shape {
        id: airPodsOsdRing

        readonly property bool low: bar.statusOsdRingLevel !== null && bar.statusOsdRingLevel <= 20 && !bar.statusOsdRingCharging

        visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
        implicitWidth: 26
        implicitHeight: 26
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Colors.surface1
            strokeWidth: 3.5
            fillColor: "transparent"

            PathAngleArc {
                centerX: 13
                centerY: 13
                radiusX: 11
                radiusY: 11
                startAngle: 0
                sweepAngle: 360
            }

        }

        ShapePath {
            strokeColor: airPodsOsdRing.low ? Colors.red : Colors.green
            strokeWidth: 3.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: 13
                centerY: 13
                radiusX: 11
                radiusY: 11
                startAngle: -90
                sweepAngle: bar.statusOsdRingLevel === null ? 0 : 3.6 * bar.statusOsdRingLevel
            }

        }

    }

    // Fine-grained levels (volume, screen brightness): continuous bar.
    Rectangle {
        visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel > 10
        implicitWidth: 160
        implicitHeight: 8
        radius: 4
        color: Colors.surface1

        Rectangle {
            width: parent.width * Math.min(1, bar.statusOsdLevel / Math.max(1, bar.statusOsdMaxLevel))
            height: parent.height
            radius: parent.radius
            // The secondary color when muted, the bar still shows the level it'll come back to.
            color: bar.statusOsdEnabled ? Colors.primary : Colors.secondary

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

}
