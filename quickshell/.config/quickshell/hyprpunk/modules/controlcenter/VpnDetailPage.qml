import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// A VPN from the VPN tab: how it's doing, where it goes, connect or disconnect, whether
// it comes up on its own, or delete it.
ControlPage {
    id: page

    property string uuid: ""
    readonly property var profile: Vpn.profile(uuid)
    readonly property bool up: profile !== null && (profile.state === "activated" || profile.state === "activating")
    // From the profile's full listing: {serviceType, server, address}.
    property var details: ({
    })

    function show(uuid) {
        page.uuid = uuid;
        stack.push(pageName);
    }

    // Read again on each change: the address only exists while it's up.
    function readDetails() {
        if (uuid === "")
            return ;

        const asked = uuid;
        Vpn.readDetails(uuid, (details) => {
            if (asked === uuid)
                page.details = details;

        });
    }

    pageName: "vpnDetail"
    spacing: Metrics.spacing.large
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
        onBackRequested: page.back()
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
        icon: page.up ? "vpn_key_off" : "vpn_key"
        label: page.up ? "Disconnect" : "Connect"
        onTriggered: Vpn.toggle(page.uuid)
    }

    // Comes up by itself with the network, like NetworkManager's "Connect automatically".
    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Metrics.radius.normal

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Metrics.spacing.large
            anchors.rightMargin: Metrics.spacing.large
            spacing: Metrics.spacing.large

            Icon {
                text: "autorenew"
                color: Colors.primary
                size: Metrics.text.title
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "Connect Automatically"
                color: Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
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
        color: Colors.red
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    ActionRow {
        Layout.fillWidth: true
        icon: "delete"
        label: "Delete This VPN"
        confirmLabel: "Click again to delete it"
        destructive: true
        onTriggered: {
            Vpn.remove(page.uuid);
            page.back();
        }
    }

}
