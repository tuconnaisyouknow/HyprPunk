import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.components
import qs.services
import qs.theme

// A saved Wi-Fi network: how it's doing, connect or disconnect, change its password
// (or its enterprise sign-in), or forget it.
ControlPage {
    id: page

    property var network: null
    readonly property bool enterprise: network !== null && WifiProfiles.enterprise(network.security)
    // The new password field is open.
    property bool editing: false
    readonly property bool saving: WifiProfiles.busy
    property string error: ""
    // NetworkManager's key management for its password, "" when it has none to change.
    readonly property string passwordKeyMgmt: network !== null ? WifiProfiles.keyMgmt(network.security) : ""

    signal connectRequested()
    // The enterprise form, filled with the saved settings.
    signal modifyRequested()

    function show(network) {
        page.network = network;
        reset();
        stack.push(pageName);
    }

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
        // The profile takes the new password only if it connects.
        WifiProfiles.connect({
            "ssid": network.name,
            "keyMgmt": passwordKeyMgmt,
            "psk": newPassword.text,
            "wepKeyType": wepKeyType.value
        }, (ok, error) => {
            page.error = error;
            if (ok)
                page.reset();

        });
    }

    pageName: "wifiDetail"
    spacing: Metrics.spacing.large

    PageHeader {
        Layout.fillWidth: true
        title: page.network !== null ? page.network.name : ""
        toggleVisible: false
        onBackRequested: page.back()
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
        icon: page.network !== null && page.network.connected ? "signal_wifi_off" : "signal_wifi_4_bar"
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
        icon: "edit"
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
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal

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
                spacing: Metrics.spacing.normal

                FormCheck {
                    id: showPassword

                    Layout.fillWidth: true
                    label: "Show password"
                }

                Text {
                    visible: page.saving
                    text: "Connecting…"
                    color: Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.body
                }

            }

        }

    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        wrapMode: Text.WordWrap
        text: page.error
        color: Colors.red
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    ActionRow {
        Layout.fillWidth: true
        icon: "delete"
        label: "Forget This Network"
        confirmLabel: "Click again to forget it"
        destructive: true
        onTriggered: {
            page.network.forget();
            page.back();
        }
    }

}
