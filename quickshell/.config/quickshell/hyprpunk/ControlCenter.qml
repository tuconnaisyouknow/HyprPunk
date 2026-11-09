import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Widgets

// The control center, growing out of the bar's right-most pill. Click the pill or
// press Super+C; Escape, a click outside or the pill again closes it.
Card {
    id: controlCenter

    required property var screen
    required property var shellState
    // Its screen's bar, whose control pill it grows out of.
    required property var bar
    required property var airPods
    property real progress: opened ? 1 : 0
    // The pages are built once the bar has its first values, or right away if you open
    // the panel before. Kept from then on.
    property bool pagesWanted: false
    readonly property int panelWidth: 452
    // The panel's tallest: a page taller than that scrolls.
    readonly property int panelMaxHeight: 680
    // Where that pill is.
    readonly property var pill: bar.controlPill
    property string page: "main"
    // Pages move like on iOS: a sub-page slides in from the right while the main page
    // backs off to the left, and the other way round going back.
    property string shownPage: "main"
    property string previousPage: "main"
    property real pageProgress: 1
    property var passwordNetwork: null
    // Enterprise network whose credentials are asked on the "enterprise" page.
    property var enterpriseNetwork: null
    // The network you just connected to from here: only its failures ask for credentials,
    // not NetworkManager's own reconnections in the background.
    property var requestedWifi: null
    // Saved network and paired device of the detail pages.
    property var detailNetwork: null
    property var detailDevice: null
    // The VPN of its detail page, by uuid.
    property string detailVpn: ""
    // The background app whose menu is unfolded on its page.
    property var trayExpanded: null
    // Where the enterprise form goes back to: the list, or the network's details.
    property string enterpriseReturnPage: "wifi"
    // The Bluetooth page, or the sound page for an audio device opened from it.
    property string bluetoothDetailReturnPage: "bluetooth"
    property string powerProfile: "balanced"
    property var powerProfiles: []
    property bool bluetoothPowerPending: false
    // Laptops and desktops alike: power-profiles-daemon always has at least saver and balanced.
    readonly property bool powerProfilesAvailable: powerProfiles.length > 1
    // Keyboard layout and language settings ("fr" or "us"), saved by the scripts.
    readonly property string keyboardLayout: Session.keyboardLayout
    readonly property string localeLanguage: Session.languageProfile
    readonly property string localeRegional: Session.regionalProfile
    readonly property var localeProfiles: [{
        "id": "fr",
        "name": "French",
        "locale": "fr_FR.UTF-8"
    }, {
        "id": "us",
        "name": "English",
        "locale": "en_US.UTF-8"
    }]
    // The time caffeine's countdown is shown at, ticking while the panel is open.
    property real now: Date.now()
    readonly property var caffeineDurations: [{
        "minutes": 0,
        "label": "Until turned off"
    }, {
        "minutes": 30,
        "label": "30 minutes"
    }, {
        "minutes": 60,
        "label": "1 hour"
    }, {
        "minutes": 120,
        "label": "2 hours"
    }, {
        "minutes": 240,
        "label": "4 hours"
    }]
    // The battery charge limit in % (100 for none), 0 when the battery has no such thing.
    // Changed through battery-limit (see battery/), which install.sh sets up.
    property int chargeLimit: 0
    property bool chargeLimitWritable: false
    // Why the last limit didn't stick (the battery refused it), empty otherwise.
    property string chargeLimitError: ""
    // What switching the limit back on restores: the last one under 100.
    property int chargeLimitOn: 80
    readonly property var chargeLimits: [60, 70, 80, 90]
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: audioSink !== null ? audioSink.audio : null
    readonly property int volume: audio !== null ? Math.round(audio.volume * 100) : 0
    readonly property bool muted: audio !== null && audio.muted
    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;

        }
        return null;
    }
    readonly property bool wiredConnected: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wired && device.connected)
                return true;

        }
        return false;
    }
    readonly property var wifiNetworks: {
        if (wifiDevice === null || !Networking.wifiEnabled)
            return [];

        return wifiDevice.networks.values.slice().sort((a, b) => {
            return (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength);
        });
    }
    readonly property var activeWifi: wifiNetworks.length > 0 && wifiNetworks[0].connected ? wifiNetworks[0] : null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothEnabled: adapter !== null && adapter.enabled
    readonly property var bluetoothDevices: {
        if (adapter === null || !adapter.enabled)
            return [];

        return adapter.devices.values.filter((device) => {
            return device.paired || (device.deviceName !== "" && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(device.deviceName));
        }).sort((a, b) => {
            return (b.connected - a.connected) || (b.paired - a.paired) || a.deviceName.localeCompare(b.deviceName);
        });
    }
    readonly property var connectedBluetooth: bluetoothDevices.filter((device) => {
        return device.connected;
    })

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function pageVisible(name) {
        return page === name || (pageProgress < 1 && previousPage === name);
    }

    function pageDepth(name) {
        if (name === "main")
            return 0;

        if (name === "wifiDetail" || name === "vpnDetail" || name === "bluetoothDetail")
            return 2;

        return name === "enterprise" ? 3 : 1;
    }

    // The page a page goes back to (Escape and the back buttons).
    function parentPage(name) {
        if (name === "enterprise")
            return enterpriseReturnPage;

        if (name === "wifiDetail" || name === "vpnDetail")
            return "wifi";

        if (name === "bluetoothDetail")
            return bluetoothDetailReturnPage;

        return "main";
    }

    function showWifiDetails(network) {
        detailNetwork = network;
        pagesLoader.item.wifiDetail.reset();
        page = "wifiDetail";
    }

    function showVpnDetails(uuid) {
        detailVpn = uuid;
        page = "vpnDetail";
    }

    function showBluetoothDetails(device) {
        bluetoothDetailReturnPage = page === "sound" ? "sound" : "bluetooth";
        detailDevice = device;
        page = "bluetoothDetail";
    }

    // The background apps page, with this app's menu already unfolded (or none).
    function showTray(item) {
        trayExpanded = item;
        page = "tray";
    }

    function pageX(name) {
        // Back towards the main page: the other way round.
        const direction = pageDepth(page) < pageDepth(previousPage) ? -1 : 1;
        const width = panelWidth - 28;
        // pageProgress runs linearly: the slide eases out, the fades below don't.
        const slide = 1 - Math.pow(1 - pageProgress, 3);
        if (name === page)
            return (1 - slide) * direction * width * 0.3;

        return -slide * direction * width * 0.15;
    }

    function pageOpacity(name) {
        // The old page is nearly gone before the new one shows, so they never mush together.
        if (name === page)
            return Math.max(0, Math.min(1, (pageProgress - 0.2) / 0.6));

        return Math.max(0, 1 - pageProgress / 0.35);
    }

    function close() {
        opened = false;
    }

    function wifiSubtitle() {
        if (!Networking.wifiEnabled)
            return "Off";

        if (activeWifi !== null)
            return activeWifi.name;

        return wiredConnected ? "Ethernet" : "Not connected";
    }

    function toggleBluetooth() {
        if (adapter === null)
            return ;

        // BlueZ won't power an rfkill-blocked adapter: lift the block first, and power it
        // once it's reported unblocked.
        if (!adapter.enabled && adapter.state === BluetoothAdapterState.Blocked)
            rfkillUnblockProcess.running = true;
        else
            adapter.enabled = !adapter.enabled;
    }

    function bluetoothSubtitle() {
        if (adapter === null)
            return "Unavailable";

        if (!adapter.enabled)
            return "Off";

        if (connectedBluetooth.length === 1)
            return connectedBluetooth[0].deviceName;

        if (connectedBluetooth.length > 1)
            return connectedBluetooth.length + " devices";

        return "On";
    }

    function bluetoothDeviceIcon(icon) {
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones"))
            return "󰋋";

        if (icon.startsWith("audio"))
            return "󰓃";

        if (icon.startsWith("input-mouse"))
            return "󰍽";

        if (icon.startsWith("input-keyboard"))
            return "󰌌";

        if (icon.startsWith("input-gaming"))
            return "󰊴";

        if (icon.startsWith("phone"))
            return "󰏲";

        return "󰂯";
    }

    function selectWifi(network) {
        if (network.connected) {
            network.disconnect();
        } else if (network.known || network.security === WifiSecurityType.Open) {
            passwordNetwork = null;
            requestedWifi = network;
            network.connect();
        } else {
            askWifiSecrets(network);
        }
    }

    // Enterprise networks get the full form, the others just a password.
    function isEnterprise(network) {
        return [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(network.security);
    }

    function askWifiSecrets(network) {
        if (isEnterprise(network)) {
            passwordNetwork = null;
            enterpriseNetwork = network;
            enterpriseReturnPage = "wifi";
            pagesLoader.item.enterprise.reset();
            page = "enterprise";
        } else {
            passwordNetwork = network;
            pagesLoader.item.password.text = "";
            pagesLoader.item.password.input.forceActiveFocus();
        }
    }

    function selectBluetooth(device) {
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            device.connect();
        } else {
            device.trusted = true;
            device.pair();
        }
    }

    function toggleCaffeine() {
        if (shellState.caffeine)
            shellState.caffeine = false;
        else
            shellState.setCaffeine(0);
        now = Date.now();
    }

    function chooseCaffeine(minutes) {
        shellState.setCaffeine(minutes);
        now = Date.now();
    }

    // "Off", "On" until turned off, or the time left: "45 min left", "1 h 30 left".
    function caffeineSubtitle() {
        if (!shellState.caffeine)
            return "Off";

        if (shellState.caffeineUntil <= 0)
            return "On";

        const minutes = Math.max(1, Math.ceil((shellState.caffeineUntil - now) / 60000));
        if (minutes < 60)
            return minutes + " min left";

        return Math.floor(minutes / 60) + " h " + String(minutes % 60).padStart(2, "0") + " left";
    }

    function setChargeLimit(limit) {
        if (!chargeLimitWritable)
            return ;

        chargeLimit = limit;
        if (limit < 100)
            chargeLimitOn = limit;

        chargeLimitError = "";
        chargeLimitSetProcess.command = ["battery-limit", "set", String(limit)];
        chargeLimitSetProcess.running = true;
    }

    // A battery filled up to the limit, full without one.
    function chargeLimitIcon(limit) {
        return limit >= 100 ? "󰁹" : String.fromCodePoint(0xf007a + Math.max(0, Math.min(8, Math.round(limit / 10) - 1)));
    }

    function toggleChargeLimit() {
        setChargeLimit(chargeLimit < 100 ? 100 : chargeLimitOn);
    }

    function powerProfileIcon() {
        if (powerProfile === "performance")
            return "󰓅";

        if (powerProfile === "power-saver")
            return "󰌪";

        return "󰾅";
    }

    function cyclePowerProfile() {
        if (powerProfileSetProcess.running || powerProfiles.length < 2)
            return ;

        const next = powerProfiles[(powerProfiles.indexOf(powerProfile) + 1) % powerProfiles.length];
        powerProfile = next;
        powerProfileSetProcess.command = ["powerprofilesctl", "set", next];
        powerProfileSetProcess.running = true;
    }

    // category is "language" or "regional".
    function setLocale(category, profile) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/locale-profilectl.sh", "set-" + category, profile]);
    }

    onOpenedChanged: {
        shellState.controlCenterOpen = opened;
        if (opened) {
            pagesWanted = true;
            powerProfileProcess.running = true;
            chargeLimitError = "";
            chargeLimitProcess.running = true;
            panel.forceActiveFocus();
        } else {
            page = "main";
            // Folds back without the page transition.
            pageAnimation.complete();
            passwordNetwork = null;
            enterpriseNetwork = null;
            requestedWifi = null;
            detailNetwork = null;
            detailDevice = null;
            detailVpn = "";
            Vpn.passwordUuid = "";
            trayExpanded = null;
        }
    }
    onPageChanged: {
        previousPage = shownPage;
        shownPage = page;
        pageAnimation.restart();
        // Leaving the network page drops its password prompts: coming back shows the
        // networks, not a password half typed.
        if (page !== "wifi") {
            passwordNetwork = null;
            Vpn.passwordUuid = "";
        }
    }
    anchors.fill: parent
    pillName: "control"
    covering: progress > 0
    cardRect: Qt.rect(panelSpot.x + panel.x, panelSpot.y + panel.y, panel.width, panel.height)
    cardRadius: panel.radius
    takesKeyboard: opened
    dismissable: opened

    function clickedOutside() {
        close();
    }

    Connections {
        function onPanelRequestsChanged() {
            const action = controlCenter.shellState.requestedAction("controlcenter", controlCenter.screen);
            if (action === "")
                return ;

            if (action === "open" || action === "toggle" && !controlCenter.opened)
                controlCenter.opened = true;
            else
                controlCenter.close();
        }

        target: controlCenter.shellState
    }

    // Pinned to the pill's top right corner, where the panel grows from.
    Item {
        id: panelSpot

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: controlCenter.pill.top
        anchors.rightMargin: controlCenter.pill.right
        width: panel.width
        height: panel.height

        // Grows out of the pill like the calendar and the player do.
        ClippingRectangle {
            id: panel

            property real fullHeight: (pagesLoader.item !== null ? pagesLoader.item.implicitHeight : 0) + 28
            // Off until the pages are built, so the panel starts at its real height instead
            // of growing from an empty one.
            property bool heightAnimated: false

            anchors.top: parent.top
            anchors.right: parent.right
            visible: controlCenter.progress > 0
            width: controlCenter.lerp(controlCenter.pill.width, controlCenter.panelWidth)
            height: controlCenter.lerp(controlCenter.pill.height, fullHeight)
            // The pill's corners: rounder ones would let the pill's show under the panel.
            radius: controlCenter.pill.height / 2
            color: "transparent"
            focus: true
            Keys.onEscapePressed: {
                if (controlCenter.page !== "main")
                    controlCenter.page = controlCenter.parentPage(controlCenter.page);
                else
                    controlCenter.close();
            }

            // A click on the panel stays in it, away from the bar and the pill under it.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
            }

            // Where the pill sits under the panel: a click there closes it, like on the
            // pill. Under the pages, so it only gets the clicks no control keeps (their
            // TapHandlers take the click on press).
            Item {
                anchors.right: parent.right
                width: controlCenter.pill.width
                height: controlCenter.pill.height
                visible: controlCenter.opened

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: controlCenter.close()
                }

            }

            // Same look as the pill it grows from, so it feels like the pill itself is growing.
            GlassSurface {
                radius: panel.radius
                tinted: false
                backgroundColor: Theme.panel
            }

            // Built bit by bit soon after the shell starts and kept, so the panel opens as
            // fast as the bar's cards, with Super+C too. Finished at once if opened before.
            Loader {
                id: pagesLoader

                active: controlCenter.pagesWanted
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 14
                anchors.topMargin: 14
                // The pages take this width, and give the Loader their height.
                width: controlCenter.panelWidth - 28
                asynchronous: !controlCenter.opened
                onStatusChanged: panel.heightAnimated = status === Loader.Ready

                // Laid out at full size, only uncovered while the panel grows.
                sourceComponent: Item {
                    id: pages

                    // For the functions up top, which can't see inside the Loader.
                    readonly property Item wifiDetail: wifiDetailPage
                    readonly property Item enterprise: enterprisePage
                    readonly property Item password: wifiPage.password
                    // Starts hidden even when built with the panel already opening (Super+C),
                    // so the pages still fade in.
                    property bool built: false

                    opacity: built && controlCenter.opened ? 1 : 0
                    Component.onCompleted: built = true
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }

                    }

                    implicitHeight: controlCenter.page === "wifi" ? wifiPage.implicitHeight : controlCenter.page === "enterprise" ? enterprisePage.implicitHeight : controlCenter.page === "wifiDetail" ? wifiDetailPage.implicitHeight : controlCenter.page === "vpnDetail" ? vpnDetailPage.implicitHeight : controlCenter.page === "bluetoothDetail" ? bluetoothDetailPage.implicitHeight : controlCenter.page === "bluetooth" ? bluetoothPage.implicitHeight : controlCenter.page === "locale" ? localePage.implicitHeight : controlCenter.page === "sound" ? soundPage.implicitHeight : controlCenter.page === "caffeine" ? caffeinePage.implicitHeight : controlCenter.page === "chargeLimit" ? chargeLimitPage.implicitHeight : controlCenter.page === "tray" ? trayPage.implicitHeight : mainPage.implicitHeight

                    ColumnLayout {
                        id: mainPage

                        width: parent.width
                        x: controlCenter.pageX("main")
                        visible: controlCenter.pageVisible("main")
                        enabled: controlCenter.page === "main"
                        opacity: controlCenter.pageOpacity("main")
                        spacing: 12

                        // Two columns of tiles, of the same width.
                        RowLayout {
                            id: tileColumns

                            readonly property real columnWidth: (width - spacing) / 2

                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.preferredWidth: tileColumns.columnWidth
                                Layout.alignment: Qt.AlignTop
                                spacing: 12

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: Networking.wifiEnabled ? (controlCenter.activeWifi !== null ? Icons.wifi(controlCenter.activeWifi.signalStrength, Vpn.connection !== null) : "󰤯") : "󰤭"
                                    title: "Wi-Fi"
                                    subtitle: controlCenter.wifiSubtitle()
                                    active: Networking.wifiEnabled
                                    // Its page also holds the VPNs, Wi-Fi or not.
                                    expandable: true
                                    onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                                    onExpandRequested: controlCenter.page = "wifi"
                                }

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: controlCenter.bluetoothEnabled ? (controlCenter.connectedBluetooth.length > 0 ? "󰂱" : "󰂯") : "󰂲"
                                    title: "Bluetooth"
                                    subtitle: controlCenter.bluetoothSubtitle()
                                    active: controlCenter.bluetoothEnabled
                                    expandable: controlCenter.adapter !== null
                                    onToggled: controlCenter.toggleBluetooth()
                                    onExpandRequested: controlCenter.page = "bluetooth"
                                }

                                ControlTile {
                                    Layout.fillWidth: true
                                    icon: "󰗊"
                                    title: "Locale"
                                    subtitle: controlCenter.localeLanguage.toUpperCase() + " · " + controlCenter.localeRegional.toUpperCase() + " formats"
                                    expandable: true
                                    onToggled: controlCenter.page = "locale"
                                    onExpandRequested: controlCenter.page = "locale"
                                }

                            }

                            ColumnLayout {
                                Layout.preferredWidth: tileColumns.columnWidth
                                Layout.fillHeight: true
                                spacing: 12

                                ControlTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    icon: "󰂛"
                                    title: "Focus"
                                    subtitle: controlCenter.shellState.doNotDisturb ? "On" : "Off"
                                    active: controlCenter.shellState.doNotDisturb
                                    onToggled: controlCenter.shellState.doNotDisturb = !controlCenter.shellState.doNotDisturb
                                }

                                ControlTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: controlCenter.powerProfilesAvailable
                                    icon: controlCenter.powerProfileIcon()
                                    title: "Power"
                                    subtitle: controlCenter.powerProfile === "power-saver" ? "Saver" : controlCenter.powerProfile === "performance" ? "Performance" : "Balanced"
                                    active: controlCenter.powerProfile !== "balanced"
                                    onToggled: controlCenter.cyclePowerProfile()
                                }

                                // A click switches between the AZERTY and QWERTY profiles.
                                ControlTile {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    icon: "󰌌"
                                    title: "Keyboard"
                                    subtitle: controlCenter.keyboardLayout === "fr" ? "FR AZERTY" : "US QWERTY"
                                    onToggled: Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/keyboard-layoutctl.sh", "set", controlCenter.keyboardLayout === "fr" ? "us" : "fr"])
                                }

                            }

                        }

                        // Below the two columns. Without a charge limit, caffeine spans both
                        // so the grid stays even.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: tileColumns.spacing

                            ControlTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: tileColumns.columnWidth
                                icon: controlCenter.shellState.caffeine ? "󰅶" : "󰾪"
                                title: "Caffeine"
                                subtitle: controlCenter.caffeineSubtitle()
                                active: controlCenter.shellState.caffeine
                                expandable: true
                                onToggled: controlCenter.toggleCaffeine()
                                onExpandRequested: controlCenter.page = "caffeine"
                            }

                            ControlTile {
                                Layout.fillWidth: true
                                Layout.preferredWidth: tileColumns.columnWidth
                                visible: controlCenter.chargeLimit > 0
                                icon: controlCenter.chargeLimitIcon(controlCenter.chargeLimit)
                                title: "Charge limit"
                                subtitle: controlCenter.chargeLimit < 100 ? controlCenter.chargeLimit + " %" : "Off"
                                active: controlCenter.chargeLimit < 100
                                expandable: true
                                onToggled: {
                                    if (controlCenter.chargeLimitWritable)
                                        controlCenter.toggleChargeLimit();
                                    else
                                        controlCenter.page = "chargeLimit";
                                }
                                onExpandRequested: controlCenter.page = "chargeLimit"
                            }

                        }

                        // The brightness when the screen has a backlight, and the glass style.
                        ControlBlock {
                            Layout.fillWidth: true
                            implicitHeight: brightnessColumn.implicitHeight + 24

                            ColumnLayout {
                                id: brightnessColumn

                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Text {
                                    text: "Display"
                                    color: Theme.mauve
                                    font.family: Theme.font
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }

                                HorizontalSlider {
                                    Layout.fillWidth: true
                                    visible: Devices.hasBacklight
                                    value: Devices.brightness / 100
                                    icon: Icons.brightness(Devices.brightness)
                                    onValueRequested: (value) => {
                                        return Devices.setBrightness(Math.max(1, Math.round(value * 100)));
                                    }
                                }

                                SegmentedControl {
                                    Layout.fillWidth: true
                                    compact: true
                                    value: Session.glassStyle
                                    options: [{
                                        "value": "classic",
                                        "icon": "󰆧",
                                        "label": "Classic"
                                    }, {
                                        "value": "liquid",
                                        "icon": "󰖌",
                                        "label": "Liquid"
                                    }]
                                    onSelected: (value) => {
                                        return Quickshell.execDetached([Quickshell.env("HOME") + "/Scripts/glassctl.sh", "set", value]);
                                    }
                                }

                            }

                        }

                        ControlBlock {
                            id: soundBlock

                            Layout.fillWidth: true
                            implicitHeight: soundColumn.implicitHeight + 24

                            // Under the content: the slider keeps its own clicks.
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    soundBlock.bounce();
                                    controlCenter.page = "sound";
                                }
                            }

                            ColumnLayout {
                                id: soundColumn

                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Sound"
                                        color: Theme.mauve
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        text: controlCenter.audioSink !== null ? (controlCenter.audioSink.description || controlCenter.audioSink.name) : "No output"
                                        color: Theme.lavender
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: "󰅂"
                                        color: soundBlock.hovered ? Theme.mauve : Theme.lavender
                                        font.family: Theme.font
                                        font.pixelSize: 14

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 160
                                            }

                                        }

                                    }

                                }

                                HorizontalSlider {
                                    Layout.fillWidth: true
                                    // Muted, the fill keeps its level and turns lavender.
                                    value: controlCenter.volume / 100
                                    accent: controlCenter.muted ? Theme.lavender : Theme.mauve
                                    iconButton: true
                                    icon: Icons.volume(controlCenter.volume, controlCenter.muted)
                                    onValueRequested: (value) => {
                                        if (controlCenter.audio !== null) {
                                            controlCenter.audio.muted = false;
                                            controlCenter.audio.volume = value;
                                        }
                                    }
                                    onIconClicked: {
                                        if (controlCenter.audio !== null)
                                            controlCenter.audio.muted = !controlCenter.audio.muted;

                                    }
                                }

                            }

                        }

                        // Last, since it changes size with the apps running: an icon brings
                        // its app back, the rest of the block opens their page.
                        ControlBlock {
                            id: trayBlock

                            // Named in the header while hovered, in place of a tooltip.
                            property var hoveredItem: null

                            Layout.fillWidth: true
                            visible: Tray.items.length > 0
                            implicitHeight: trayColumn.implicitHeight + 24

                            // Under the content: the icons keep their own clicks.
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    trayBlock.bounce();
                                    controlCenter.showTray(null);
                                }
                            }

                            ColumnLayout {
                                id: trayColumn

                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Background apps"
                                        color: Theme.mauve
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        text: trayBlock.hoveredItem !== null ? Tray.name(trayBlock.hoveredItem) : Tray.items.length + (Tray.items.length === 1 ? " app" : " apps")
                                        color: Theme.lavender
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: "󰅂"
                                        color: trayBlock.hovered ? Theme.mauve : Theme.lavender
                                        font.family: Theme.font
                                        font.pixelSize: 14

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 160
                                            }

                                        }

                                    }

                                }

                                // The icons' halo is wider than the icon: pulled left so the
                                // first icon lines up with the title.
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: -6
                                    spacing: 4

                                    Repeater {
                                        model: Tray.items

                                        TrayItem {
                                            required property var modelData

                                            item: modelData
                                            onHoveredChanged: {
                                                if (hovered)
                                                    trayBlock.hoveredItem = modelData;
                                                else if (trayBlock.hoveredItem === modelData)
                                                    trayBlock.hoveredItem = null;
                                            }
                                            onMenuRequested: controlCenter.showTray(modelData)
                                        }

                                    }

                                }

                            }

                        }
                    }

                    WifiPage {
                        id: wifiPage

                        width: parent.width
                        x: controlCenter.pageX("wifi")
                        visible: controlCenter.pageVisible("wifi")
                        enabled: controlCenter.page === "wifi"
                        opacity: controlCenter.pageOpacity("wifi")
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                        onPasswordSent: panel.forceActiveFocus()
                        onVpnDetailsRequested: (uuid) => {
                            return controlCenter.showVpnDetails(uuid);
                        }
                    }

                    VpnDetailPage {
                        id: vpnDetailPage

                        width: parent.width
                        x: controlCenter.pageX("vpnDetail")
                        visible: controlCenter.pageVisible("vpnDetail")
                        enabled: controlCenter.page === "vpnDetail"
                        opacity: controlCenter.pageOpacity("vpnDetail")
                        uuid: controlCenter.detailVpn
                        onBackRequested: controlCenter.page = "wifi"
                        onDeleted: controlCenter.page = "wifi"
                    }

                    BluetoothPage {
                        id: bluetoothPage

                        width: parent.width
                        x: controlCenter.pageX("bluetooth")
                        visible: controlCenter.pageVisible("bluetooth")
                        enabled: controlCenter.page === "bluetooth"
                        opacity: controlCenter.pageOpacity("bluetooth")
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                    }


                    EnterpriseWifiPage {
                        id: enterprisePage

                        width: parent.width
                        x: controlCenter.pageX("enterprise")
                        visible: controlCenter.pageVisible("enterprise")
                        enabled: controlCenter.page === "enterprise"
                        opacity: controlCenter.pageOpacity("enterprise")
                        network: controlCenter.enterpriseNetwork
                        onBackRequested: controlCenter.page = controlCenter.enterpriseReturnPage
                        onFinished: controlCenter.page = controlCenter.enterpriseReturnPage
                    }

                    WifiDetailPage {
                        id: wifiDetailPage

                        width: parent.width
                        x: controlCenter.pageX("wifiDetail")
                        visible: controlCenter.pageVisible("wifiDetail")
                        enabled: controlCenter.page === "wifiDetail"
                        opacity: controlCenter.pageOpacity("wifiDetail")
                        network: controlCenter.detailNetwork
                        enterprise: controlCenter.detailNetwork !== null && controlCenter.isEnterprise(controlCenter.detailNetwork)
                        onBackRequested: controlCenter.page = "wifi"
                        onConnectRequested: controlCenter.selectWifi(controlCenter.detailNetwork)
                        onModifyRequested: {
                            controlCenter.enterpriseNetwork = controlCenter.detailNetwork;
                            controlCenter.enterpriseReturnPage = "wifiDetail";
                            enterprisePage.edit();
                            controlCenter.page = "enterprise";
                        }
                        onForgotten: controlCenter.page = "wifi"
                    }

                    BluetoothDetailPage {
                        id: bluetoothDetailPage

                        width: parent.width
                        x: controlCenter.pageX("bluetoothDetail")
                        visible: controlCenter.pageVisible("bluetoothDetail")
                        enabled: controlCenter.page === "bluetoothDetail"
                        opacity: controlCenter.pageOpacity("bluetoothDetail")
                        device: controlCenter.detailDevice
                        onBackRequested: controlCenter.page = controlCenter.bluetoothDetailReturnPage
                        onForgotten: controlCenter.page = controlCenter.bluetoothDetailReturnPage
                    }

                    SoundPage {
                        id: soundPage

                        width: parent.width
                        x: controlCenter.pageX("sound")
                        visible: controlCenter.pageVisible("sound")
                        enabled: controlCenter.page === "sound"
                        opacity: controlCenter.pageOpacity("sound")
                        active: controlCenter.opened && controlCenter.page === "sound"
                        maxHeight: controlCenter.panelMaxHeight - 28
                        airPods: controlCenter.airPods
                        onBackRequested: controlCenter.page = "main"
                        onBluetoothDetailsRequested: (device) => {
                            return controlCenter.showBluetoothDetails(device);
                        }
                    }

                    CaffeinePage {
                        id: caffeinePage

                        width: parent.width
                        x: controlCenter.pageX("caffeine")
                        visible: controlCenter.pageVisible("caffeine")
                        enabled: controlCenter.page === "caffeine"
                        opacity: controlCenter.pageOpacity("caffeine")
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                    }

                    ChargeLimitPage {
                        id: chargeLimitPage

                        width: parent.width
                        x: controlCenter.pageX("chargeLimit")
                        visible: controlCenter.pageVisible("chargeLimit")
                        enabled: controlCenter.page === "chargeLimit"
                        opacity: controlCenter.pageOpacity("chargeLimit")
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                    }

                    LocalePage {
                        id: localePage

                        width: parent.width
                        x: controlCenter.pageX("locale")
                        visible: controlCenter.pageVisible("locale")
                        enabled: controlCenter.page === "locale"
                        opacity: controlCenter.pageOpacity("locale")
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                    }

                    TrayPage {
                        id: trayPage

                        width: parent.width
                        x: controlCenter.pageX("tray")
                        visible: controlCenter.pageVisible("tray")
                        enabled: controlCenter.page === "tray"
                        opacity: controlCenter.pageOpacity("tray")
                        maxHeight: controlCenter.panelMaxHeight - 28
                        center: controlCenter
                        onBackRequested: controlCenter.page = "main"
                    }

                }

            }

            Behavior on fullHeight {
                enabled: panel.heightAnimated

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

        }

    }

    // Building them takes the shell's time bit by bit, which delayed the bar's values
    // when it began at startup.
    Timer {
        interval: 1500
        running: true
        onTriggered: controlCenter.pagesWanted = true
    }

    Behavior on progress {
        NumberAnimation {
            duration: Theme.cardFold
            easing.type: Easing.OutCubic
        }

    }

    NumberAnimation {
        id: pageAnimation

        target: controlCenter
        property: "pageProgress"
        from: 0
        to: 1
        duration: 320
    }

    Binding {
        target: controlCenter.wifiDevice
        property: "scannerEnabled"
        value: true
        when: controlCenter.wifiDevice !== null && controlCenter.opened && controlCenter.page === "wifi"
    }

    // The last background app quit from its own menu: nothing left on its page.
    Connections {
        function onItemsChanged() {
            if (controlCenter.page === "tray" && Tray.items.length === 0)
                controlCenter.page = "main";

        }

        target: Tray
    }

    Binding {
        target: controlCenter.adapter
        property: "discovering"
        value: true
        when: controlCenter.bluetoothEnabled && controlCenter.opened && controlCenter.page === "bluetooth"
    }

    Timer {
        running: controlCenter.opened && controlCenter.shellState.caffeine && controlCenter.shellState.caffeineUntil > 0
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: controlCenter.now = Date.now()
    }

    PwObjectTracker {
        objects: controlCenter.audioSink !== null ? [controlCenter.audioSink] : []
    }

    Process {
        id: powerProfileProcess

        // Profile lines look like "* balanced:" (active) or "  performance:".
        command: ["powerprofilesctl", "list"]
        running: true
        onExited: (exitCode) => {
            if (exitCode !== 0)
                controlCenter.powerProfiles = [];

        }

        stdout: StdioCollector {
            onStreamFinished: {
                const order = ["power-saver", "balanced", "performance"];
                const profiles = [];
                const pattern = /^([* ]) ([a-z-]+):$/gm;
                let match;
                while ((match = pattern.exec(text)) !== null) {
                    profiles.push(match[2]);
                    if (match[1] === "*")
                        controlCenter.powerProfile = match[2];

                }
                controlCenter.powerProfiles = profiles.sort((a, b) => {
                    return order.indexOf(a) - order.indexOf(b);
                });
            }
        }

    }

    Process {
        id: rfkillUnblockProcess

        command: ["rfkill", "unblock", "bluetooth"]
        onExited: (exitCode) => {
            if (exitCode !== 0)
                return ;

            controlCenter.bluetoothPowerPending = true;
            bluetoothPowerTimeout.restart();
            bluetoothPowerConnection.powerIfReady();
        }
    }

    Connections {
        id: bluetoothPowerConnection

        function powerIfReady() {
            const adapter = controlCenter.adapter;
            // Still blocked, or BlueZ is restoring power on its own after the unblock.
            if (!controlCenter.bluetoothPowerPending || adapter === null || adapter.state === BluetoothAdapterState.Blocked || adapter.state === BluetoothAdapterState.Enabling)
                return ;

            controlCenter.bluetoothPowerPending = false;
            if (adapter.state === BluetoothAdapterState.Disabled)
                adapter.enabled = true;

        }

        function onStateChanged() {
            powerIfReady();
        }

        target: controlCenter.adapter
    }

    Timer {
        id: bluetoothPowerTimeout

        interval: 3000
        onTriggered: controlCenter.bluetoothPowerPending = false
    }

    // "<limit> <writable 1|0> <saved limit>", or nothing when the battery has no limit.
    // Read-only until battery-limit is installed.
    Process {
        id: chargeLimitProcess

        command: ["sh", "-c", "command -v battery-limit >/dev/null && exec battery-limit get; for file in /sys/class/power_supply/*/charge_control_end_threshold; do [ -e \"$file\" ] && echo \"$(cat \"$file\") 0\"; break; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(/\s+/);
                const limit = parseInt(fields[0]);
                controlCenter.chargeLimit = isNaN(limit) ? 0 : limit;
                controlCenter.chargeLimitWritable = fields[1] === "1";
                const kept = parseInt(fields[2]);
                if (limit > 0 && limit < 100)
                    controlCenter.chargeLimitOn = limit;
                else if (kept > 0 && kept < 100)
                    controlCenter.chargeLimitOn = kept;
            }
        }

    }

    Process {
        id: chargeLimitSetProcess

        stderr: StdioCollector {
            id: chargeLimitSetErrors
        }

        // Re-read the real state, the firmware may round or refuse it.
        onExited: (code) => {
            if (code !== 0)
                controlCenter.chargeLimitError = chargeLimitSetErrors.text.trim().split("\n").pop() || "The charge limit could not be set.";

            chargeLimitProcess.running = true;
        }
    }

    Process {
        id: powerProfileSetProcess

        // Re-read the real state, the daemon may refuse or hold the profile.
        onExited: powerProfileProcess.running = true
    }

}
