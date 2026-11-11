import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// A VPN from the VPN tab: how it's doing, where it goes, connect or disconnect, whether
// it comes up on its own, or delete it.
ColumnLayout {
    id: page

    property string uuid: ""
    readonly property var profile: Vpn.profile(uuid)
    readonly property bool up: profile !== null && (profile.state === "activated" || profile.state === "activating")
    // From the profile's full listing: {serviceType, server, address}.
    property var details: ({
    })

    signal backRequested()
    signal deleted()

    // Read again on each change: the address only exists while it's up.
    function readDetails() {
        if (uuid !== "")
            detailsProcess.running = true;

    }

    spacing: 12
    onUuidChanged: {
        details = {
        };
        readDetails();
    }
    onProfileChanged: readDetails()

    PageHeader {
        Layout.fillWidth: true
        title: page.profile !== null ? page.profile.name : ""
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    InfoBlock {
        Layout.fillWidth: true
        rows: page.profile === null ? [] : [{
            "label": "Status",
            "value": Vpn.status(page.profile)
        }, {
            "label": "Type",
            "value": page.profile.type === "wireguard" ? "WireGuard" : (page.details.serviceType || "VPN")
        }, {
            "label": "Server",
            "value": page.details.server || ""
        }, {
            "label": "Address",
            "value": page.profile.state === "activated" ? (page.details.address || "") : ""
        }]
    }

    ActionRow {
        Layout.fillWidth: true
        icon: page.up ? "󰌙" : "󰖂"
        label: page.up ? "Disconnect" : "Connect"
        onTriggered: Vpn.toggle(page.uuid)
    }

    // Comes up by itself with the network, like NetworkManager's "Connect automatically".
    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: 14

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 12

            Text {
                text: "󰁪"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 17
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "Connect Automatically"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            ToggleSwitch {
                checked: page.profile !== null && page.profile.autoconnect
                onToggled: Vpn.setAutoconnect(page.uuid, !checked)
            }

        }

    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        wrapMode: Text.WordWrap
        text: Vpn.errors[page.uuid] || ""
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: 12
    }

    ActionRow {
        Layout.fillWidth: true
        icon: "󰆴"
        label: "Delete This VPN"
        confirmLabel: "Click again to delete it"
        destructive: true
        onTriggered: {
            Vpn.remove(page.uuid);
            page.deleted();
        }
    }

    Process {
        id: detailsProcess

        // One "key:value" a line; the values keep their colons (an endpoint's port).
        command: ["nmcli", "-t", "connection", "show", "uuid", page.uuid]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = {
                };
                for (const line of text.split("\n")) {
                    const colon = line.indexOf(":");
                    if (colon > 0)
                        values[line.slice(0, colon)] = line.slice(colon + 1);

                }
                // "org.freedesktop.NetworkManager.openvpn" reads OpenVPN.
                const service = (values["vpn.service-type"] || "").split(".").pop();
                const names = {
                    "openvpn": "OpenVPN",
                    "openconnect": "OpenConnect",
                    "vpnc": "Cisco VPNC",
                    "l2tp": "L2TP",
                    "pptp": "PPTP",
                    "strongswan": "IPsec (strongSwan)",
                    "libreswan": "IPsec (Libreswan)",
                    "fortisslvpn": "Fortinet SSL VPN",
                    "sstp": "SSTP"
                };
                // WireGuard's first peer, or the plugin's own setting for its server.
                const endpoint = /endpoint=(\S+)/.exec(values["wireguard.peers"] || "");
                const remote = /\b(?:remote|gateway)\s*=\s*([^,]+)/.exec(values["vpn.data"] || "");
                page.details = {
                    "serviceType": names[service] || service,
                    "server": endpoint !== null ? endpoint[1] : remote !== null ? remote[1].trim() : "",
                    "address": (values["IP4.ADDRESS[1]"] || values["IP6.ADDRESS[1]"] || "").split("/")[0]
                };
            }
        }

    }

}
