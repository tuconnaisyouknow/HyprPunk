import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

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
        if (uuid === "")
            return ;

        const asked = uuid;
        Vpn.readDetails(uuid, (details) => {
            if (asked === uuid)
                page.details = details;

        });
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
                color: Colors.primary
                font.family: Metrics.font
                font.pixelSize: 17
            }

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "Connect Automatically"
                color: Colors.primary
                font.family: Metrics.font
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
        color: Colors.red
        font.family: Metrics.font
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

}
