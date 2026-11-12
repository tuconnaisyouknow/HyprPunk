import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// A saved Wi-Fi network: how it's doing, connect or disconnect, change its password
// (or its enterprise sign-in), or forget it.
ColumnLayout {
    id: page

    property var network: null
    property bool enterprise: false
    // The new password field is open.
    property bool editing: false
    readonly property bool saving: helper.busy
    property string error: ""
    // NetworkManager's key management for its password, from the control center, ""
    // when it has none to change.
    property string passwordKeyMgmt: ""

    signal backRequested()
    signal connectRequested()
    // The enterprise form, filled with the saved settings.
    signal modifyRequested()
    signal forgotten()

    function reset() {
        editing = false;
        error = "";
        newPassword.text = "";
        wepKeyType.reset();
    }

    function savePassword() {
        if (newPassword.text === "" || saving)
            return ;

        error = "";
        helper.send({
            "ssid": network.name,
            "keyMgmt": passwordKeyMgmt,
            "psk": newPassword.text,
            "wepKeyType": wepKeyType.value
        });
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

            WepKeySelect {
                id: wepKeyType

                Layout.fillWidth: true
                visible: page.passwordKeyMgmt === "none"
                enabled: !page.saving
            }

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
                    color: Theme.secondary
                    font.family: Theme.font
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
        color: Theme.red
        font.family: Theme.font
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
    WifiHelper {
        id: helper

        onFinished: (ok, error) => {
            page.error = error;
            if (ok)
                page.reset();

        }
    }

}
