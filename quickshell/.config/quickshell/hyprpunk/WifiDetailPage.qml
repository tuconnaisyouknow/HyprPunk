import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// A saved Wi-Fi network: its state, then connect or disconnect, modify its credentials
// (a new password here, NetworkManager's enterprise form for 802.1X) and forget it.
ColumnLayout {
    id: page

    property var network: null
    property bool enterprise: false
    // The new password field is open.
    property bool editing: false
    property bool saving: false
    property string error: ""
    // NetworkManager's key management for a password, "" when there is nothing to modify.
    readonly property string passwordKeyMgmt: {
        if (network === null)
            return "";

        if (network.security === WifiSecurityType.Sae)
            return "sae";

        if (network.security === WifiSecurityType.WpaPsk || network.security === WifiSecurityType.Wpa2Psk)
            return "wpa-psk";

        return "";
    }

    signal backRequested()
    signal connectRequested()
    // The enterprise form, filled with the saved settings.
    signal modifyRequested()
    signal forgotten()

    function reset() {
        editing = false;
        saving = false;
        error = "";
        newPassword.text = "";
    }

    function savePassword() {
        if (newPassword.text === "" || saving)
            return ;

        error = "";
        saving = true;
        helper.pending = JSON.stringify({
            "ssid": network.name,
            "keyMgmt": passwordKeyMgmt,
            "psk": newPassword.text
        });
        helper.running = true;
    }

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: page.network !== null ? page.network.name : ""
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    InfoBlock {
        Layout.fillWidth: true
        rows: page.network === null ? [] : [{
            "label": "Status",
            "value": page.network.stateChanging ? (page.network.connected ? "Disconnecting…" : "Connecting…") : page.network.connected ? "Connected" : "Saved"
        }, {
            "label": "Security",
            "value": WifiSecurityType.toString(page.network.security)
        }, {
            "label": "Signal",
            "value": Math.round(page.network.signalStrength * 100) + "%"
        }]
    }

    ActionRow {
        Layout.fillWidth: true
        icon: page.network !== null && page.network.connected ? "󰤭" : "󰤨"
        label: page.network !== null && page.network.connected ? "Disconnect" : "Connect"
        onTriggered: {
            if (page.network.connected)
                page.network.disconnect();
            else
                page.connectRequested();
        }
    }

    ActionRow {
        Layout.fillWidth: true
        visible: page.enterprise || page.passwordKeyMgmt !== ""
        icon: "󰏫"
        label: page.enterprise ? "Modify Settings" : "Change Password"
        onTriggered: {
            if (page.enterprise) {
                page.modifyRequested();
            } else {
                page.editing = !page.editing;
                if (page.editing)
                    newPassword.input.forceActiveFocus();

            }
        }
    }

    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: passwordColumn.implicitHeight + 24
        visible: page.editing

        ColumnLayout {
            id: passwordColumn

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            FormField {
                id: newPassword

                Layout.fillWidth: true
                enabled: !page.saving
                label: "New password"
                placeholder: "Password, then Enter"
                secret: true
                revealed: showPassword.checked
                onAccepted: page.savePassword()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FormCheck {
                    id: showPassword

                    Layout.fillWidth: true
                    label: "Show password"
                }

                Text {
                    visible: page.saving
                    text: "Connecting…"
                    color: "#7f849c"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

        }

    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        wrapMode: Text.WordWrap
        text: page.error
        color: "#f38ba8"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
    }

    ActionRow {
        Layout.fillWidth: true
        icon: "󰆴"
        label: "Forget This Network"
        confirmLabel: "Click again to forget it"
        destructive: true
        onTriggered: {
            page.network.forget();
            page.forgotten();
        }
    }

    // Replaces the profile with the new password, kept only if it connects.
    Process {
        id: helper

        property string pending: ""

        command: ["python3", Quickshell.env("HOME") + "/Scripts/wifi-connection.py"]
        stdinEnabled: true
        onStarted: {
            write(pending + "\n");
            pending = "";
        }
        onExited: {
            if (page.saving) {
                page.saving = false;
                page.error = "Connection failed";
            }
        }

        stdout: SplitParser {
            onRead: (line) => {
                let result;
                try {
                    result = JSON.parse(line);
                } catch (error) {
                    return ;
                }
                page.saving = false;
                if (result.ok) {
                    page.error = "";
                    page.reset();
                } else {
                    page.error = result.error;
                }
            }
        }

    }

}
