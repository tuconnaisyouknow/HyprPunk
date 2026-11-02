import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// The control center's Wi-Fi page: the networks around, a click to connect, and the
// password prompt for a new one. Saved networks open their details.
ColumnLayout {
    id: page

    required property var center
    // The password prompt, which the control center focuses when a network asks for one.
    readonly property Item password: passwordField

    signal backRequested()
    // A password went out, so the prompt can hand the keyboard back to the panel.
    signal passwordSent()

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        checked: Networking.wifiEnabled
        onBackRequested: page.backRequested()
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    IconText {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: page.center.wifiNetworks.length === 0
        icon: Networking.wifiEnabled ? "󰤯" : "󰤭"
        text: Networking.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
        color: Theme.overlay1
        font.pixelSize: 14
        font.weight: Font.Normal


    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: wifiList.height
        visible: page.center.wifiNetworks.length > 0

        ListView {
            id: wifiList

            // Wider than the page by a few pixels, so the hovered row's zoom and
            // bounce (up to 4.5px a side) aren't cut; the rows stay aligned.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            height: Math.min(contentHeight, 340)
            clip: true
            spacing: 4
            // Keeps the rows that stay instead of rebuilding them all at each change,
            // which held up the animations.
            model: ScriptModel {
                values: page.center.wifiNetworks
            }

            // The row inside: the list sets its delegates' x.
            delegate: Item {
                required property var modelData

                width: ListView.view.width
                height: row.height

                ListRow {
                    id: row

                    x: 6
                    width: parent.width - 12
                    icon: Icons.wifi(modelData.signalStrength, false)
                    title: modelData.name
                    subtitle: modelData.stateChanging ? (modelData.connected ? "Disconnecting…" : "Connecting…") : modelData.connected ? "Connected" : modelData.known ? "Saved" : ""
                    trailing: modelData.security === WifiSecurityType.Open ? "" : "󰌾"
                    highlighted: modelData.connected
                    detailsAvailable: modelData.known
                    onClicked: page.center.selectWifi(modelData)
                    onDetailsRequested: page.center.showWifiDetails(modelData)

                    Connections {
                        function onConnectionFailed(reason) {
                            if (reason === ConnectionFailReason.NoSecrets && page.center.opened && page.center.requestedWifi === modelData)
                                page.center.askWifiSecrets(modelData);

                        }

                        target: modelData
                    }

                }

            }

        }

    }

    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: passwordColumn.implicitHeight + 24
        visible: page.center.passwordNetwork !== null

        ColumnLayout {
            id: passwordColumn

            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            IconText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                icon: "󰌾"
                text: (page.center.passwordNetwork !== null ? page.center.passwordNetwork.name : "")
                color: Theme.mauve
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            FormField {
                id: passwordField

                Layout.fillWidth: true
                secret: true
                escapable: true
                placeholder: "Password, then Enter"
                onEscaped: page.center.passwordNetwork = null
                onAccepted: {
                    if (page.center.passwordNetwork !== null && text !== "") {
                        page.center.passwordNetwork.connectWithPsk(text);
                        page.center.passwordNetwork = null;
                        page.passwordSent();
                    }
                }
            }

        }

    }

}
