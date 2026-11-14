import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.services
import qs.theme

// The control center's network page, in tabs like the sound page. Wi-Fi: the networks
// around, a click to connect, the password prompt for a new one, and a way to a hidden
// one. VPN: your VPNs, a click to bring one up or down, and the import of a new one.
// Saved networks and VPNs open their details.
ControlPage {
    id: page

    // The network asking for its password, null when none is.
    property var passwordNetwork: null
    // The network you just connected to from here: only its failures ask for secrets,
    // not NetworkManager's own reconnections in the background.
    property var requestedWifi: null
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
    // Why the last password didn't connect, until another network asks.
    property string wifiError: ""

    // A password went out, so the prompt can hand the keyboard back to the panel.
    signal passwordSent()
    signal detailsRequested(var network)
    // An enterprise network: its sign-in has a page of its own.
    signal enterpriseRequested(var network)
    signal vpnDetailsRequested(string uuid)
    signal hiddenRequested()

    // Disconnects, or connects a saved network or one that needs no secret (open,
    // Enhanced Open, or a kind NetworkManager works out alone). The others ask first.
    function select(network) {
        if (network.connected) {
            network.disconnect();
        } else if (network.known || !WifiProfiles.needsSecrets(network)) {
            passwordNetwork = null;
            requestedWifi = network;
            network.connect();
        } else {
            askSecrets(network);
        }
    }

    // Asks for what NetworkManager lacks. A network with no secret to ask for (a kind
    // it doesn't know) is left to fail.
    function askSecrets(network) {
        if (WifiProfiles.enterprise(network.security)) {
            passwordNetwork = null;
            enterpriseRequested(network);
        } else if (WifiProfiles.keyMgmt(network.security) !== "") {
            passwordNetwork = network;
            passwordField.text = "";
            passwordField.input.forceActiveFocus();
        }
    }

    pageName: "wifi"
    spacing: 12

    onPasswordNetworkChanged: {
        wifiError = "";
        wepKeyType.reset();
    }
    // Leaving the page drops its password prompts: coming back shows the networks, not
    // a password half typed.
    onCurrentChanged: {
        if (current)
            return ;

        passwordNetwork = null;
        Vpn.passwordUuid = "";
    }

    // The panel closed: what you asked for is behind you.
    Connections {
        function onOpenedChanged() {
            if (!page.stack.opened)
                page.requestedWifi = null;

        }

        target: page.stack
    }

    // Looks for networks while you're on the page.
    Binding {
        target: NetworkStatus.wifiDevice
        property: "scannerEnabled"
        value: true
        when: NetworkStatus.wifiDevice !== null && page.active
    }

    // A VPN wants a password: its tab comes up with the prompt ready.
    Connections {
        function onPasswordUuidChanged() {
            if (Vpn.passwordUuid === "" || !page.stack.opened)
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
        color: Colors.red
        font.family: Metrics.font
        font.pixelSize: 12
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Network"
        // Wi-Fi's own switch: the VPNs each have theirs in the list.
        toggleVisible: page.tab === "wifi"
        checked: Networking.wifiEnabled
        onBackRequested: page.back()
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
                        visible: NetworkStatus.wifiNetworks.length === 0
                        icon: Networking.wifiEnabled ? "󰤯" : "󰤭"
                        text: Networking.wifiEnabled ? "Searching for networks…" : "Wi-Fi is off"
                        color: Colors.secondary
                        font.pixelSize: 14
                        font.weight: Font.Normal
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: wifiList.height
                        visible: NetworkStatus.wifiNetworks.length > 0

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
                            // The control center moves through the rows itself.
                            keyNavigationEnabled: false
                            spacing: 4
                            // Keeps the rows that stay instead of rebuilding them all at each change,
                            // which held up the animations.
                            model: ScriptModel {
                                values: NetworkStatus.wifiNetworks
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
                                    trailing: WifiProfiles.needsSecrets(modelData) ? "󰌾" : ""
                                    highlighted: modelData.connected
                                    detailsAvailable: modelData.known
                                    onClicked: page.select(modelData)
                                    onDetailsRequested: page.detailsRequested(modelData)

                                    Connections {
                                        function onConnectionFailed(reason) {
                                            if (reason === ConnectionFailReason.NoSecrets && page.stack.opened && page.requestedWifi === modelData)
                                                page.askSecrets(modelData);

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
                        visible: page.passwordNetwork !== null

                        ColumnLayout {
                            id: passwordColumn

                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            IconText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                icon: "󰌾"
                                text: (page.passwordNetwork !== null ? page.passwordNetwork.name : "")
                                color: Colors.primary
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            WepKeySelect {
                                id: wepKeyType

                                Layout.fillWidth: true
                                visible: page.passwordNetwork !== null && WifiProfiles.keyMgmt(page.passwordNetwork.security) === "none"
                                enabled: !WifiProfiles.busy
                            }

                            FormField {
                                id: passwordField

                                Layout.fillWidth: true
                                enabled: !WifiProfiles.busy
                                secret: true
                                escapable: true
                                placeholder: "Password, then Enter"
                                onEscaped: page.passwordNetwork = null
                                onAccepted: {
                                    const network = page.passwordNetwork;
                                    // Saves the network only once the password works, and says why not.
                                    if (network !== null && text !== "")
                                        WifiProfiles.connect({
                                        "ssid": network.name,
                                        "keyMgmt": WifiProfiles.keyMgmt(network.security),
                                        "psk": text,
                                        "wepKeyType": wepKeyType.value
                                    }, (ok, error) => {
                                        page.wifiError = error;
                                        if (ok) {
                                            page.passwordNetwork = null;
                                            page.passwordSent();
                                        } else {
                                            passwordField.input.forceActiveFocus();
                                        }
                                    });

                                }
                            }

                            ErrorText {
                                text: WifiProfiles.busy ? "Connecting…" : page.wifiError
                                color: WifiProfiles.busy ? Colors.secondary : Colors.red
                            }

                        }

                    }

                    ListRow {
                        Layout.fillWidth: true
                        visible: Networking.wifiEnabled
                        icon: "󰤫"
                        title: "Hidden network"
                        onClicked: page.hiddenRequested()
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
                        color: Colors.secondary
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
                                color: Colors.primary
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
                        label: Vpn.importing ? "Importing…" : "Import a Configuration"
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
