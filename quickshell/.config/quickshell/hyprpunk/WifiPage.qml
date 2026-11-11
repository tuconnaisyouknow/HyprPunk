import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// The control center's network page, in tabs like the sound page. Wi-Fi: the networks
// around, a click to connect, and the password prompt for a new one. VPN: your VPNs, a
// click to bring one up or down, and the import of a new one. Saved networks and VPNs
// open their details.
ColumnLayout {
    id: page

    required property var center
    // The password prompt, which the control center focuses when a network asks for one.
    readonly property Item password: passwordField
    property string tab: "wifi"
    readonly property var tabs: [{
        "value": "wifi",
        "icon": "󰤨",
        "label": "Wi-Fi"
    }, {
        "value": "vpn",
        "icon": "󰖂",
        "label": "VPN"
    }]
    readonly property int tabIndex: tab === "vpn" ? 1 : 0
    // Between the tabs side by side, enough to hide the neighbours of the one shown.
    readonly property int tabGap: 24
    readonly property Item currentTab: tabIndex === 1 ? vpnTab : wifiTab
    readonly property var vpnAsking: Vpn.profile(Vpn.passwordUuid)

    signal backRequested()
    // A password went out, so the prompt can hand the keyboard back to the panel.
    signal passwordSent()
    signal vpnDetailsRequested(string uuid)

    spacing: 12

    // A VPN wants a password: its tab comes up with the prompt ready.
    Connections {
        function onPasswordUuidChanged() {
            if (Vpn.passwordUuid === "" || !page.center.opened)
                return ;

            page.tab = "vpn";
            vpnPasswordField.text = "";
            vpnPasswordField.input.forceActiveFocus();
        }

        target: Vpn
    }

    // One tab, side by side with the other: only the one shown is opaque and clickable,
    // the other fades as it slides away.
    component TabColumn: ColumnLayout {
        required property int index
        readonly property bool current: index === page.tabIndex

        x: index * (page.width + page.tabGap)
        width: page.width
        spacing: 12
        enabled: current
        opacity: current ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }

        }

    }

    component ErrorText: Text {
        Layout.fillWidth: true
        visible: text !== ""
        wrapMode: Text.WordWrap
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: 12
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Network"
        // Wi-Fi's own switch: the VPNs each have theirs in the list.
        toggleVisible: page.tab === "wifi"
        checked: Networking.wifiEnabled
        onBackRequested: page.backRequested()
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    SegmentedControl {
        Layout.fillWidth: true
        compact: true
        options: page.tabs
        value: page.tab
        onSelected: (value) => {
            return page.tab = value;
        }
    }

    // As tall as the tab shown. It spills a few pixels over the margins on every side so
    // a hovered row's zoom and bounce aren't clipped by the slide's clip.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: page.currentTab.implicitHeight

        Item {
            anchors.fill: parent
            anchors.margins: -6
            clip: true

            Item {
                x: 6 - page.tabIndex * (page.width + page.tabGap)
                y: 6
                width: page.width

                Behavior on x {
                    NumberAnimation {
                        duration: 340
                        easing.type: Easing.OutCubic
                    }

                }

                TabColumn {
                    id: wifiTab

                    index: 0

                    IconText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: page.center.wifiNetworks.length === 0
                        icon: Networking.wifiEnabled ? "󰤯" : "󰤭"
                        text: Networking.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
                        color: Theme.secondary
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
                                color: Theme.primary
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

                TabColumn {
                    id: vpnTab

                    index: 1

                    IconText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        visible: Vpn.profiles.length === 0
                        icon: "󰖂"
                        text: "No VPN yet"
                        color: Theme.secondary
                        font.pixelSize: 14
                        font.weight: Font.Normal
                    }

                    // As close together as the Wi-Fi rows.
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Vpn.profiles.length > 0
                        spacing: 4

                        Repeater {
                            model: Vpn.profiles

                            ListRow {
                                required property var modelData

                                Layout.fillWidth: true
                                icon: "󰖂"
                                title: modelData.name
                                subtitle: Vpn.status(modelData)
                                trailing: modelData.state === "activated" ? "󰄬" : ""
                                highlighted: modelData.state === "activated"
                                detailsAvailable: true
                                onClicked: Vpn.toggle(modelData.uuid)
                                onDetailsRequested: page.vpnDetailsRequested(modelData.uuid)
                            }

                        }

                    }

                    // What NetworkManager said when a VPN didn't come up.
                    ErrorText {
                        text: Vpn.profiles.filter((profile) => {
                            return Vpn.errors[profile.uuid] !== undefined;
                        }).map((profile) => {
                            return profile.name + ": " + Vpn.errors[profile.uuid];
                        }).join("\n")
                    }

                    ControlBlock {
                        Layout.fillWidth: true
                        implicitHeight: vpnPasswordColumn.implicitHeight + 24
                        visible: page.vpnAsking !== null

                        ColumnLayout {
                            id: vpnPasswordColumn

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            IconText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                icon: "󰌾"
                                text: page.vpnAsking !== null ? page.vpnAsking.name : ""
                                color: Theme.primary
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            FormField {
                                id: vpnPasswordField

                                Layout.fillWidth: true
                                secret: true
                                escapable: true
                                placeholder: "Password, then Enter"
                                onEscaped: Vpn.passwordUuid = ""
                                onAccepted: {
                                    if (Vpn.passwordUuid !== "" && text !== "") {
                                        Vpn.connect(Vpn.passwordUuid, text);
                                        text = "";
                                        page.passwordSent();
                                    }
                                }
                            }

                        }

                    }

                    ActionRow {
                        Layout.fillWidth: true
                        icon: Vpn.importing ? "󰔟" : "󰈔"
                        label: Vpn.importing ? "Choosing a File…" : "Import a Configuration"
                        onTriggered: Vpn.importFile()
                    }

                    ErrorText {
                        text: Vpn.importError
                    }

                }

            }

        }

    }

}
