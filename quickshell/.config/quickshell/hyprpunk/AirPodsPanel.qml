import QtQuick
import QtQuick.Layouts

// Connected AirPods on the control center's sound page, like their popup in small: the
// pods and their case with a battery ring under each, then the choice between noise
// cancellation and transparency for the models that have them, once connected (only
// nearby, the AirPods still tell their batteries).
ControlBlock {
    id: panel

    required property var airPods
    // One of airPods.devices.
    required property var device
    readonly property var controls: device.controls || {}
    readonly property var images: device.images || null
    readonly property bool headphones: device.kind === "headphones"
    readonly property bool caseShown: !headphones && device["case"] !== undefined && device["case"].level !== null
    readonly property bool noiseControl: airPods.hasNoiseControl(device)
    readonly property var listeningModes: [{
        "value": 2,
        "icon": "󰋋",
        "label": "Noise Cancellation"
    }, {
        "value": 3,
        "icon": "󰟅",
        "label": "Transparency"
    }]

    implicitHeight: column.implicitHeight + 28

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 14

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: panel.device.name
                color: "#cba6f7"
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: panel.device.connected ? panel.device.model : panel.device.model + " · Nearby"
                color: "#b4befe"
                elide: Text.ElideRight
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
            }

        }

        // The pods (or the headphones) and the case, a ring under each.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 26

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 10

                AirPodsImage {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 86
                    source: panel.images !== null ? "file://" + panel.images.buds : ""
                    glyph: panel.headphones ? "󰋋" : "󱡏"
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    Repeater {
                        model: panel.airPods.podBatteries(panel.device)

                        BatteryRing {
                            required property var modelData

                            battery: modelData
                        }

                    }

                }

            }

            ColumnLayout {
                visible: panel.caseShown && panel.images !== null
                Layout.alignment: Qt.AlignTop
                spacing: 10

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
                return panel.airPods.control(panel.device.address, "listeningMode", mode);
            }
        }

    }

}
