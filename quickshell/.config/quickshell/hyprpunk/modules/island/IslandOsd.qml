import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.services
import qs.components
import qs.theme

// Everything the island can briefly show (Osd): a level (volume, brightness), an on/off
// switch, the screenshot you just took, battery alerts and the AirPods. The bar's island,
// its OSD beside a card and the lock screen's island all draw it.
RowLayout {
    id: view

    // Showing, and what: one of Osd's, kept as it was while it goes away.
    required property bool shown
    required property var content

    // Green while charging, the accent on battery, red for the alerts.
    function batteryColor() {
        if (content.label === "Charging")
            return Colors.green;

        return content.label === "On battery" ? Colors.primary : Colors.red;
    }

    // "64% · 1 h 05 until full" while charging, "64% · 3 h 10 left" on battery,
    // just the percentage until UPower has an estimate.
    function batteryDetail() {
        const seconds = Battery.onBattery ? Battery.timeLeft : Battery.timeToFull;
        if (!(seconds > 0))
            return Battery.percent + (Osd.estimating ? "% · Estimating…" : Battery.onBattery ? "%" : "% · Plugged in");

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const duration = hours > 0 ? hours + " h " + String(minutes).padStart(2, "0") : minutes + " min";
        return Battery.percent + "% · " + duration + (Battery.onBattery ? " left" : " until full");
    }

    spacing: Metrics.spacing.normal

    Text {
        visible: view.shown && view.content.kind === ""
        text: view.content.icon
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.heading
    }

    // Volume and screen brightness only show their icon and bar.
    Text {
        visible: view.shown && view.content.kind === "" && view.content.maxLevel <= 10
        Layout.leftMargin: Metrics.spacing.small
        Layout.rightMargin: Metrics.spacing.small
        text: view.content.label
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
        font.weight: Font.Bold
    }

    Rectangle {
        visible: view.shown && view.content.kind === "" && view.content.maxLevel <= 0
        implicitWidth: statusOsdStateText.implicitWidth + 16
        implicitHeight: 24
        radius: Metrics.radius.normal
        color: view.content.enabled ? Colors.primary : Colors.surface1

        Text {
            id: statusOsdStateText

            anchors.centerIn: parent
            text: view.content.enabled ? "On" : "Off"
            color: view.content.enabled ? Colors.base : Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.body
            font.weight: Font.Bold
        }

    }

    Row {
        readonly property int segments: view.content.maxLevel
        readonly property int filled: view.content.level

        visible: view.shown && view.content.kind === "" && view.content.maxLevel > 0 && view.content.maxLevel <= 10
        spacing: Metrics.spacing.small

        Repeater {
            model: parent.segments

            Rectangle {
                required property int index

                width: 18
                height: 8
                radius: 4
                color: index < parent.filled ? Colors.primary : Colors.surface1

                Behavior on color {
                    ColorAnim {
                        token: Motion.color.small
                    }

                }

            }

        }

    }

    // Screenshot: a thumbnail, then where it went.
    ClippingRectangle {
        visible: view.shown && view.content.kind === "screenshot"
        implicitWidth: Math.round(30 * Math.min(1.8, Math.max(0.6, screenshotThumbnail.implicitWidth / Math.max(1, screenshotThumbnail.implicitHeight))))
        implicitHeight: 30
        radius: 6
        color: Colors.surface1

        Image {
            id: screenshotThumbnail

            anchors.fill: parent
            source: view.content.kind === "screenshot" && view.content.image !== "" ? "file://" + view.content.image : ""
            sourceSize.height: 90
            fillMode: Image.PreserveAspectCrop
            cache: false
            smooth: true
            mipmap: true
        }

        // A recording's play sign.
        Text {
            anchors.centerIn: parent
            visible: view.content.title === "Recording"
            text: "󰐊"
            color: Colors.primary
            style: Text.Outline
            styleColor: Colors.alpha(Colors.crust, 0.6)
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
        }

    }

    Column {
        visible: view.shown && view.content.kind === "screenshot"
        Layout.leftMargin: Metrics.spacing.hairline
        spacing: 0

        Text {
            text: view.content.title
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.Bold
        }

        Text {
            text: view.content.label
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.small
        }

    }

    // Battery: green when plugged in, the accent when unplugged, red when low (pulsing when
    // it's critical), with the time left or until full.
    Text {
        id: batteryOsdIcon

        visible: view.shown && view.content.kind === "battery"
        text: Icons.battery(Battery.device.percentage, Battery.onBattery)
        color: view.batteryColor()
        font.family: Metrics.font
        font.pixelSize: 22

        SequentialAnimation on opacity {
            running: Battery.critical && batteryOsdIcon.visible
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    batteryOsdIcon.opacity = 1;

            }

            NumberAnimation {
                to: 0.35
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

    Column {
        visible: view.shown && view.content.kind === "battery"
        Layout.leftMargin: Metrics.spacing.hairline
        spacing: 0

        Text {
            text: view.content.label
            color: view.batteryColor()
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.Bold
        }

        Text {
            text: view.batteryDetail()
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.small
        }

    }

    // AirPods: the pods on the left, their battery ring on the right.
    Item {
        visible: view.shown && view.content.kind === "airpods"
        // As tall as the battery ring.
        implicitWidth: 40
        implicitHeight: 26

        Image {
            id: airPodsOsdImage

            anchors.fill: parent
            source: view.content.image !== "" ? "file://" + view.content.image : ""
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
        visible: view.shown && view.content.kind === "airpods"
        implicitWidth: 136
        implicitHeight: 1
    }

    Shape {
        id: airPodsOsdRing

        readonly property bool low: view.content.ringLevel !== null && view.content.ringLevel <= 20 && !view.content.ringCharging

        visible: view.shown && view.content.kind === "airpods"
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
                sweepAngle: view.content.ringLevel === null ? 0 : 3.6 * view.content.ringLevel
            }

        }

    }

    // Fine-grained levels (volume, screen brightness): continuous bar.
    Rectangle {
        visible: view.shown && view.content.kind === "" && view.content.maxLevel > 10
        implicitWidth: 160
        implicitHeight: 8
        radius: 4
        color: Colors.surface1

        Rectangle {
            width: parent.width * Math.min(1, view.content.level / Math.max(1, view.content.maxLevel))
            height: parent.height
            radius: parent.radius
            // The secondary color when muted, the bar still shows the level it'll come back to.
            color: view.content.enabled ? Colors.primary : Colors.secondary

            Behavior on color {
                ColorAnim {
                    token: Motion.color.small
                }

            }

            Behavior on width {
                Anim {
                    token: Motion.resize.small
                }

            }

        }

    }

}
