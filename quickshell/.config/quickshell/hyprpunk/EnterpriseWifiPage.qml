import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Signing in to an enterprise Wi-Fi network (eduroam and the like: WPA Enterprise,
// dynamic WEP, LEAP), with the same fields as NetworkManager's own dialog: the method,
// then its identity, certificates and inner authentication.
// ~/Scripts/wifi-connection.py saves it and connects. Through edit(), the form opens
// on the saved settings and replaces them.
ColumnLayout {
    id: page

    property var network: null
    // Modifying the saved profile (edit()) rather than a first connection.
    property bool editing: false
    property bool loading: false
    property bool connecting: false
    property string error: ""
    readonly property var securityOptions: {
        if (network === null)
            return [];

        if (network.security === WifiSecurityType.Wpa3SuiteB192)
            return [{
                "label": "WPA3 Enterprise",
                "keyMgmt": "wpa-eap-suite-b-192"
            }];

        if (network.security === WifiSecurityType.DynamicWep)
            return [{
                "label": "Dynamic WEP (802.1X)",
                "keyMgmt": "ieee8021x"
            }];

        if (network.security === WifiSecurityType.Leap)
            return [{
                "label": "LEAP",
                "keyMgmt": "ieee8021x",
                "leap": true
            }];

        return [{
            "label": "WPA & WPA2 Enterprise",
            "keyMgmt": "wpa-eap"
        }];
    }
    readonly property var security: securityOptions[0] || null
    readonly property bool leapSecurity: security !== null && security.leap === true
    // NetworkManager's order; WPA3 192-bit only allows TLS.
    readonly property var methods: {
        if (security !== null && security.keyMgmt === "wpa-eap-suite-b-192")
            return [{
                "label": "TLS",
                "eap": "tls"
            }];

        return [{
            "label": "TLS",
            "eap": "tls"
        }, {
            "label": "LEAP",
            "eap": "leap"
        }, {
            "label": "PWD",
            "eap": "pwd"
        }, {
            "label": "FAST",
            "eap": "fast"
        }, {
            "label": "Tunneled TLS",
            "eap": "ttls"
        }, {
            "label": "Protected EAP (PEAP)",
            "eap": "peap"
        }];
    }
    readonly property string eap: leapSecurity ? "leap" : (authSelect.current ? authSelect.current.eap : "tls")
    // Methods with a CA certificate and a domain.
    readonly property bool tunneled: eap === "peap" || eap === "ttls" || eap === "tls"
    readonly property bool userPass: eap !== "tls"
    readonly property string caFilter: "DER, PEM, or PKCS#12 certificates (*.der *.pem *.crt *.cer *.p12) | *.der *.pem *.crt *.cer *.p12"
    readonly property bool userCertIsPkcs12: /\.(p12|pfx)$/i.test(userCert.path)
    // Why Connect is not available yet, like the dialog's disabled button.
    readonly property string missing: {
        if (eap === "tls") {
            if (identity.text === "")
                return "missing EAP-TLS identity";

            if (userCert.path === "")
                return "no user certificate selected";

            if (!userCertIsPkcs12 && privateKey.path === "")
                return "no key selected";

        }
        if (tunneled && !noCaRequired.checked && caCert.path === "")
            return "no CA certificate selected";

        if (eap === "fast" && !pacProvisioning.checked && pacFile.path === "")
            return "missing EAP-FAST PAC file";

        if (userPass && username.text === "")
            return "missing username";

        if (userPass && password.text === "")
            return "missing password";

        return "";
    }

    signal backRequested()
    signal finished()

    function reset() {
        error = "";
        editing = false;
        loading = false;
        for (const field of [identity, anonymousIdentity, domain, caCertPassword, userCertPassword, privateKeyPassword, username, password])
            field.text = "";
        for (const chooser of [caCert, userCert, privateKey, pacFile])
            chooser.path = "";
        authSelect.currentIndex = Math.max(0, methods.findIndex((method) => {
            return method.eap === "peap";
        }));
        peapVersion.currentIndex = 0;
        peapInner.currentIndex = 0;
        ttlsInner.currentIndex = 0;
        fastInner.currentIndex = 0;
        fastProvisioning.currentIndex = 0;
        noCaRequired.checked = false;
        pacProvisioning.checked = true;
        showPassword.checked = false;
        for (const select of [authSelect, peapVersion, peapInner, ttlsInner, fastInner, fastProvisioning])
            select.expanded = false;
    }

    // Starts from the saved profile of the network (wifi-connection.py --read).
    function edit() {
        reset();
        editing = true;
        loading = true;
        reader.command = ["python3", Quickshell.env("HOME") + "/Scripts/wifi-connection.py", "--read", network.name];
        reader.running = true;
    }

    // Selects the first option of a FormSelect matching key: value.
    function choose(target, key, value, eap) {
        const index = target.options.findIndex((option) => {
            return option[key] === value && (eap === undefined || (option.eap === true) === eap);
        });
        if (index >= 0)
            target.currentIndex = index;

    }

    function prefill(values) {
        choose(authSelect, "eap", values.eap);
        identity.text = values.eap === "tls" ? values.identity || "" : "";
        username.text = values.eap !== "tls" ? values.identity || "" : "";
        password.text = values.password || "";
        anonymousIdentity.text = values.anonymousIdentity || "";
        domain.text = values.domain || "";
        caCert.path = values.caCert || "";
        caCertPassword.text = values.caCertPassword || "";
        // Saved without a CA certificate: the box was checked.
        noCaRequired.checked = (values.eap === "peap" || values.eap === "ttls" || values.eap === "tls") && !values.caCert;
        userCert.path = values.clientCert || "";
        userCertPassword.text = values.clientCertPassword || "";
        privateKey.path = values.privateKey && values.privateKey !== values.clientCert ? values.privateKey : "";
        privateKeyPassword.text = values.privateKeyPassword || "";
        pacFile.path = values.pacFile || "";
        choose(peapVersion, "value", values.peapVersion || "");
        choose(peapInner, "value", values.phase2Auth);
        choose(fastInner, "value", values.phase2Auth);
        if (values.phase2AuthEap)
            choose(ttlsInner, "value", values.phase2AuthEap, true);
        else if (values.phase2Auth)
            choose(ttlsInner, "value", values.phase2Auth, false);
        if (values.fastProvisioning !== undefined) {
            pacProvisioning.checked = values.fastProvisioning !== "0";
            choose(fastProvisioning, "value", values.fastProvisioning);
        }
    }

    function request() {
        const values = {
            "ssid": network.name,
            "keyMgmt": security.keyMgmt,
            "eap": eap
        };
        if (eap === "tls") {
            values.identity = identity.text;
            values.clientCert = userCert.path;
            values.clientCertPassword = userCertPassword.text;
            values.privateKey = userCertIsPkcs12 && privateKey.path === "" ? userCert.path : privateKey.path;
            values.privateKeyPassword = privateKeyPassword.text;
        } else {
            values.identity = username.text;
            values.password = password.text;
        }
        if (tunneled) {
            values.domain = domain.text;
            if (!noCaRequired.checked) {
                values.caCert = caCert.path;
                values.caCertPassword = caCertPassword.text;
            }
        }
        if (eap === "peap" || eap === "ttls" || eap === "fast")
            values.anonymousIdentity = anonymousIdentity.text;

        if (eap === "peap") {
            values.peapVersion = peapVersion.current.value;
            values.phase2Auth = peapInner.current.value;
        } else if (eap === "ttls") {
            values[ttlsInner.current.eap ? "phase2AuthEap" : "phase2Auth"] = ttlsInner.current.value;
        } else if (eap === "fast") {
            values.phase2Auth = fastInner.current.value;
            values.pacFile = pacFile.path;
            values.fastProvisioning = pacProvisioning.checked ? fastProvisioning.current.value : "0";
        }
        return values;
    }

    function connect() {
        if (missing !== "" || connecting)
            return ;

        error = "";
        connecting = true;
        helper.pending = JSON.stringify(request());
        helper.running = true;
    }

    spacing: 12

    PageHeader {
        Layout.fillWidth: true
        title: page.network !== null ? page.network.name : ""
        toggleVisible: false
        onBackRequested: page.backRequested()
    }

    // Scrolls past 470px, the control center being 680px tall.
    ControlBlock {
        Layout.fillWidth: true
        implicitHeight: Math.min(form.implicitHeight, 470) + 24

        // Into the block's padding by 6px a side, so the fields' bounce isn't cut.
        Flickable {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            contentHeight: form.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: form

                x: 6
                width: parent.width - 12
                spacing: 10
                enabled: !page.connecting && !page.loading

                FormSelect {
                    Layout.fillWidth: true
                    label: "Wi-Fi security"
                    options: page.securityOptions
                }

                FormSelect {
                    id: authSelect

                    Layout.fillWidth: true
                    visible: !page.leapSecurity
                    label: "Authentication"
                    options: page.methods
                }

                // TLS
                FormField {
                    id: identity

                    Layout.fillWidth: true
                    visible: page.eap === "tls"
                    label: "Identity"
                }

                FormField {
                    id: anonymousIdentity

                    Layout.fillWidth: true
                    visible: page.eap === "peap" || page.eap === "ttls" || page.eap === "fast"
                    label: "Anonymous identity"
                }

                FormFile {
                    id: pacFile

                    Layout.fillWidth: true
                    visible: page.eap === "fast"
                    label: "PAC file"
                    dialogTitle: "Choose a PAC file"
                    filters: ["PAC files (*.pac) | *.pac"]
                }

                FormCheck {
                    id: pacProvisioning

                    visible: page.eap === "fast"
                    label: "Allow automatic PAC provisioning"
                    checked: true
                }

                FormSelect {
                    id: fastProvisioning

                    Layout.fillWidth: true
                    visible: page.eap === "fast"
                    enabled: pacProvisioning.checked
                    label: "PAC provisioning"
                    options: [{
                        "label": "Anonymous",
                        "value": "1"
                    }, {
                        "label": "Authenticated",
                        "value": "2"
                    }, {
                        "label": "Both",
                        "value": "3"
                    }]
                }

                FormField {
                    id: domain

                    Layout.fillWidth: true
                    visible: page.tunneled
                    label: "Domain"
                    tooltip: "Suffix of the server certificate name."
                }

                FormFile {
                    id: caCert

                    Layout.fillWidth: true
                    visible: page.tunneled
                    enabled: !noCaRequired.checked
                    label: "CA certificate"
                    dialogTitle: "Choose a CA Certificate"
                    filters: [page.caFilter]
                }

                FormField {
                    id: caCertPassword

                    Layout.fillWidth: true
                    visible: page.tunneled && caCert.path !== "" && !noCaRequired.checked
                    label: "CA certificate password"
                    secret: true
                }

                FormCheck {
                    id: noCaRequired

                    visible: page.tunneled
                    label: "No CA certificate is required"
                }

                FormFile {
                    id: userCert

                    Layout.fillWidth: true
                    visible: page.eap === "tls"
                    label: "User certificate"
                    dialogTitle: "Choose a User Certificate"
                    filters: [page.caFilter]
                }

                FormField {
                    id: userCertPassword

                    Layout.fillWidth: true
                    visible: page.eap === "tls" && userCert.path !== ""
                    label: "User certificate password"
                    secret: true
                }

                // A PKCS#12 certificate holds its key: the key fields are optional then.
                FormFile {
                    id: privateKey

                    Layout.fillWidth: true
                    visible: page.eap === "tls"
                    label: "User private key"
                    dialogTitle: "Choose a key for User Certificate"
                    filters: ["DER, PEM, or PKCS#12 private keys (*.der *.pem *.p12 *.key) | *.der *.pem *.p12 *.key"]
                }

                FormField {
                    id: privateKeyPassword

                    Layout.fillWidth: true
                    visible: page.eap === "tls" && (privateKey.path !== "" || page.userCertIsPkcs12)
                    label: "User key password"
                    secret: true
                }

                FormSelect {
                    id: peapVersion

                    Layout.fillWidth: true
                    visible: page.eap === "peap"
                    label: "PEAP version"
                    options: [{
                        "label": "Automatic",
                        "value": ""
                    }, {
                        "label": "Version 0",
                        "value": "0"
                    }, {
                        "label": "Version 1",
                        "value": "1"
                    }]
                }

                FormSelect {
                    id: peapInner

                    Layout.fillWidth: true
                    visible: page.eap === "peap"
                    label: "Inner authentication"
                    options: [{
                        "label": "MSCHAPv2",
                        "value": "mschapv2"
                    }, {
                        "label": "MD5",
                        "value": "md5"
                    }, {
                        "label": "GTC",
                        "value": "gtc"
                    }]
                }

                // The EAP ones go in phase2-autheap, the others in phase2-auth.
                FormSelect {
                    id: ttlsInner

                    Layout.fillWidth: true
                    visible: page.eap === "ttls"
                    label: "Inner authentication"
                    options: [{
                        "label": "PAP",
                        "value": "pap"
                    }, {
                        "label": "MSCHAP",
                        "value": "mschap"
                    }, {
                        "label": "MSCHAPv2",
                        "value": "mschapv2",
                        "eap": true
                    }, {
                        "label": "MSCHAPv2 (no EAP)",
                        "value": "mschapv2"
                    }, {
                        "label": "CHAP",
                        "value": "chap"
                    }, {
                        "label": "MD5",
                        "value": "md5",
                        "eap": true
                    }, {
                        "label": "GTC",
                        "value": "gtc",
                        "eap": true
                    }]
                }

                FormSelect {
                    id: fastInner

                    Layout.fillWidth: true
                    visible: page.eap === "fast"
                    label: "Inner authentication"
                    options: [{
                        "label": "GTC",
                        "value": "gtc"
                    }, {
                        "label": "MSCHAPv2",
                        "value": "mschapv2"
                    }]
                }

                FormField {
                    id: username

                    Layout.fillWidth: true
                    visible: page.userPass
                    label: "Username"
                    onAccepted: password.input.forceActiveFocus()
                }

                FormField {
                    id: password

                    Layout.fillWidth: true
                    visible: page.userPass
                    label: "Password"
                    secret: true
                    revealed: showPassword.checked
                    onAccepted: page.connect()
                }

                FormCheck {
                    id: showPassword

                    visible: page.userPass
                    label: "Show password"
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: page.loading ? "Loading the saved settings…" : page.connecting ? "Connecting…" : page.missing !== "" ? page.missing.charAt(0).toUpperCase() + page.missing.slice(1) : ""
            color: Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 12
        }

        Rectangle {
            id: connectButton

            readonly property bool available: page.missing === "" && !page.connecting && !page.loading

            implicitWidth: connectLabel.implicitWidth + 32
            implicitHeight: 34
            radius: 17
            color: "transparent"
            opacity: available ? 1 : 0.45

            GlassSurface {
                radius: parent.radius
                hovered: connectHover.hovered
                backgroundColor: Theme.alpha(Theme.mauve, connectHover.hovered && connectButton.available ? 0.95 : 0.8)
            }

            Text {
                id: connectLabel

                anchors.centerIn: parent
                text: (page.connecting ? "󰔟  " : "") + (page.editing ? "Save" : "Connect")
                color: Theme.base
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            HoverHandler {
                id: connectHover

                cursorShape: connectButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: connectButton.available
                onTapped: {
                    connectBounce.restart();
                    page.connect();
                }
            }

            BounceAnimation {
                id: connectBounce

                target: connectButton
            }

        }

    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: {
                page.loading = false;
                try {
                    page.prefill(JSON.parse(text));
                } catch (error) {
                    page.error = "Could not read the saved settings";
                }
            }
        }

    }

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
            if (page.connecting) {
                page.connecting = false;
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
                page.connecting = false;
                if (result.ok) {
                    page.error = "";
                    page.finished();
                } else {
                    page.error = result.error;
                }
            }
        }

    }

}
