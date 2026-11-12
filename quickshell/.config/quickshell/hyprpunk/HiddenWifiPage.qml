import QtQuick
import QtQuick.Layouts
import Quickshell.Networking

// A network that doesn't announce its name, so it's never in the list: you type its
// name and pick its security. A password or none connects from here, through
// wifi-connection.py; an enterprise network goes on to the enterprise form.
ColumnLayout {
    id: page

    required property var center
    property string error: ""
    // The common ones first. keyMgmt is NetworkManager's, for those sent from here.
    readonly property var securityOptions: [{
        "label": "WPA & WPA2 Personal",
        "keyMgmt": "wpa-psk"
    }, {
        "label": "WPA3 Personal",
        "keyMgmt": "sae"
    }, {
        "label": "WPA & WPA2 Enterprise",
        "security": WifiSecurityType.Wpa2Eap
    }, {
        "label": "WPA3 Enterprise",
        "security": WifiSecurityType.Wpa3SuiteB192
    }, {
        "label": "None",
        "keyMgmt": ""
    }, {
        "label": "Enhanced Open",
        "keyMgmt": "owe"
    }, {
        "label": "WEP",
        "keyMgmt": "none"
    }, {
        "label": "Dynamic WEP (802.1X)",
        "security": WifiSecurityType.DynamicWep
    }, {
        "label": "LEAP",
        "security": WifiSecurityType.Leap
    }]
    readonly property var security: securitySelect.current
    readonly property bool enterprise: security !== null && security.security !== undefined
    readonly property bool needsPassword: security !== null && ["wpa-psk", "sae", "none"].includes(security.keyMgmt)
    // What's left to fill in, said next to the button until there's nothing.
    readonly property string missing: ssid.text === "" ? "Missing network name" : needsPassword && password.text === "" ? "Missing password" : ""
    readonly property bool ready: missing === "" && !helper.busy

    signal backRequested()

    function reset() {
        error = "";
        ssid.text = "";
        password.text = "";
        showPassword.checked = false;
        wepKeyType.reset();
        securitySelect.currentIndex = 0;
        securitySelect.expanded = false;
        ssid.input.forceActiveFocus();
    }

    function submit() {
        if (!ready)
            return ;

        error = "";
        if (enterprise) {
            center.askEnterprise({
                "name": ssid.text,
                "security": security.security,
                "hidden": true
            }, "hidden");
            return ;
        }
        const request = {
            "ssid": ssid.text,
            "keyMgmt": security.keyMgmt,
            "hidden": true
        };
        if (needsPassword) {
            request.psk = password.text;
            request.wepKeyType = wepKeyType.value;
        }

        helper.send(request);
    }

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: "Hidden Network"
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: form.implicitHeight + 24

        ColumnLayout {
            id: form

            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            enabled: !helper.busy

            FormField {
                id: ssid

                Layout.fillWidth: true
                label: "Network name"
                onAccepted: page.needsPassword ? password.input.forceActiveFocus() : page.submit()
            }

            FormSelect {
                id: securitySelect

                Layout.fillWidth: true
                label: "Wi-Fi security"
                options: page.securityOptions
            }

            WepKeySelect {
                id: wepKeyType

                Layout.fillWidth: true
                visible: page.security !== null && page.security.keyMgmt === "none"
            }

            FormField {
                id: password

                Layout.fillWidth: true
                visible: page.needsPassword
                label: "Password"
                secret: true
                revealed: showPassword.checked
                onAccepted: page.submit()
            }

            FormCheck {
                id: showPassword

                Layout.fillWidth: true
                visible: page.needsPassword
                label: "Show password"
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: helper.busy ? "Connecting…" : page.missing
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: 12
        }

        ConnectButton {
            label: page.enterprise ? "Next" : "Connect"
            busy: helper.busy
            available: page.ready
            onClicked: page.submit()
        }

    }

    WifiHelper {
        id: helper

        onFinished: (ok, error) => {
            page.error = error;
            if (ok)
                page.backRequested();

        }
    }

}
