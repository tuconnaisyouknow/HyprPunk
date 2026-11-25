import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme
import qs.services

// Your AirPods on the sound page, a small version of their popup: the pods and the case
// with their batteries, and once connected, noise cancellation or transparency for the
// models that have it. Nearby but not connected, you still see the batteries.
ControlBlock {
    id: panel

    // One of AirPods.devices.
    required property var device
    readonly property var controls: device.controls || {}
    readonly property var images: device.images || null
    readonly property bool headphones: device.kind === "headphones"
    readonly property var podBatteries: AirPods.podBatteries(device)
    readonly property bool caseShown: !headphones && device["case"] !== undefined && device["case"].level !== null
    readonly property bool noiseControl: AirPods.hasNoiseControl(device)
    readonly property var listeningModes: [{
        "value": 2,
        "icon": "headphones",
        "label": "Noise Cancellation"
    }, {
        "value": 3,
        "icon": "hearing",
        "label": "Transparency"
    }]

    implicitHeight: column.implicitHeight + 28

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Metrics.spacing.large
        spacing: Metrics.spacing.large

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: panel.device.name
                color: Colors.primary
                elide: Text.ElideRight
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: panel.device.connected ? panel.device.model : panel.device.model + " · Nearby"
                color: Colors.secondary
                elide: Text.ElideRight
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

        }

        // The pods (or the headphones) and the case, a ring under each.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 26

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Metrics.spacing.normal

                AirPodsImage {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 86
                    source: panel.images !== null ? "file://" + panel.images.buds : ""
                    glyph: panel.headphones ? "headphones" : "earbuds"
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Metrics.spacing.huge

                    Repeater {
                        // One ring per place: each keeps living as its level changes,
                        // and eases to it.
                        model: ScriptModel {
                            values: Array.from(panel.podBatteries.keys())
                        }

                        BatteryRing {
                            required property int modelData

                            battery: panel.podBatteries[modelData] ?? null
                        }

                    }

                }

            }

            ColumnLayout {
                visible: panel.caseShown && panel.images !== null
                Layout.alignment: Qt.AlignTop
                spacing: Metrics.spacing.normal

                AirPodsImage {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 86
                    source: panel.images !== null ? "file://" + panel.images["case"] : ""
                }

                BatteryRing {
                    Layout.alignment: Qt.AlignHCenter
                    battery: panel.device["case"]
                }

            }

        }

        SegmentedControl {
            Layout.fillWidth: true
            visible: panel.noiseControl && panel.device.connected
            options: panel.listeningModes
            value: panel.controls.listeningMode !== undefined ? panel.controls.listeningMode : null
            onSelected: (mode) => {
                return AirPods.control(panel.device.address, "listeningMode", mode);
            }
        }

    }

}
