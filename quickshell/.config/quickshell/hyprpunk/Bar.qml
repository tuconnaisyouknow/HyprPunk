import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: bar

    required property var shellState
    property color base: "#1e1e2e"
    property color surface1: "#45475a"
    property color lavender: "#b4befe"
    property color overlay2: "#9399b2"
    property color mauve: "#cba6f7"
    property color red: "#f38ba8"
    property color green: "#a6e3a1"
    property color peach: "#fab387"
    readonly property var workspaceIcons: ["", "", "", "", "", "", "", "", "", "", ""]
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery && battery.isPresent
    property string cpuTemperature: "--°C"
    property string cpuFrequency: ""
    property string cpuModel: ""
    property string memoryText: "--"
    property int cpuUsage: 0
    // [idle, total] jiffies of the last /proc/stat sample.
    property var cpuStat: [0, 0]
    property int updateCount: 0
    property bool calendarVisible: false
    property bool calendarPopupVisible: false
    property bool musicVisible: false
    property bool musicPopupVisible: false
    // Set while a popup is mapping: it only starts growing once its first frame is on screen.
    property bool calendarOpenPending: false
    property bool musicOpenPending: false
    property bool monitorOpenPending: false
    property bool monitorVisible: false
    property bool monitorPopupVisible: false
    // How long a pill is hovered before its card opens: passing over the bar on the
    // way somewhere does not flash cards.
    readonly property int hoverOpenDelay: 350
    property bool workspaceOpenPending: false
    property bool workspaceVisible: false
    property bool workspacePopupVisible: false
    // The workspace the preview card opens on, among the ones the user is not on.
    property var previewWorkspace: null
    readonly property var previewWorkspaces: workspaceSwitcher.workspaces.filter((workspace) => {
        return !workspace.focused;
    }).sort((a, b) => {
        return a.id - b.id;
    })
    // Picture of the bar for the previews (grabToImage's result, which keeps it alive).
    property var barSnapshot: null
    readonly property int workspacePreviewWidth: 400
    // The screen's shape, 16:9 until Hyprland has told which monitor the bar is on.
    readonly property int workspacePreviewHeight: {
        const monitor = Hyprland.monitorFor(bar.screen);
        return Math.round(workspacePreviewWidth * (monitor !== null && monitor.width > 0 ? monitor.height / monitor.width : 9 / 16));
    }
    // 0 = card folded on the workspaces pill, 1 = preview fully open.
    property real workspaceProgress: workspaceVisible ? 1 : 0
    // The wallpaper set by wallpaperctl.sh, under the previewed windows.
    property string wallpaperPath: ""
    // 0 = card folded on the resources pill, 1 = system monitor fully open.
    property real monitorProgress: monitorVisible ? 1 : 0
    // 0 = popup folded on the cover pill, 1 = player fully open.
    property real musicProgress: musicVisible ? 1 : 0
    // Only Spotify, browsers and other MPRIS players are ignored.
    readonly property var spotifyPlayer: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    property bool statusOsdVisible: false
    property string statusOsdIcon: ""
    property string statusOsdLabel: ""
    property bool statusOsdEnabled: false
    // "airpods": a pod and its battery ring instead of an icon, label and gauge.
    // "battery": the battery's alert, its icon, a title and the time left.
    // "screenshot": the screenshot or recording just taken in small (statusOsdImage, the
    // recording's first frame), titled statusOsdTitle, a click opens statusOsdFile.
    property string statusOsdKind: ""
    property string statusOsdImage: ""
    property string statusOsdTitle: ""
    property string statusOsdFile: ""
    // Seconds since the recording started, for the island.
    property int recordingElapsed: 0
    property var statusOsdRingLevel: null
    property bool statusOsdRingCharging: false
    // Level gauge shown instead of the On/Off badge when statusOsdMaxLevel > 0.
    property int statusOsdLevel: 0
    property int statusOsdMaxLevel: 0
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    // The lowest threshold (20, 10 or 5 %) the battery went under since it was last
    // plugged in, 0 above them: each is told once, the critical one stays shown.
    property int batteryAlertStage: 0
    readonly property bool batteryCritical: hasBattery && UPower.onBattery && batteryAlertStage === 5
    // Off while the shell starts, UPower's first values are not a plug or unplug.
    property bool powerEventsReady: false
    // Seconds left from the battery's own draw, while UPower has no estimate yet
    // (the first seconds after unplugging), 0 without one.
    property real batteryDrawEstimate: 0
    readonly property real batteryTimeLeft: battery.timeToEmpty > 0 ? battery.timeToEmpty : batteryDrawEstimate
    readonly property bool batteryEstimating: statusOsdVisible && statusOsdKind === "battery" && statusOsdLabel === "On battery" && batteryTimeLeft <= 0
    property bool lockStateInitialized: false
    property bool capsLockEnabled: false
    property bool numLockEnabled: false
    property bool touchpadStateInitialized: false
    property bool touchpadEnabled: true
    readonly property var micSource: Pipewire.defaultAudioSource
    readonly property bool micMuted: micSource !== null && micSource.audio !== null && micSource.audio.muted
    property bool micStateInitialized: false
    property int keyboardBacklight: -1
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVolume: audioSink !== null && audioSink.audio !== null ? Math.round(audioSink.audio.volume * 100) : 0
    readonly property bool audioMuted: audioSink !== null && audioSink.audio !== null && audioSink.audio.muted
    property bool volumeInitialized: false
    // Output whose volume changes are shown, set again on each change of output.
    property var volumeSink: audioSink
    property int screenBrightness: 0
    property bool brightnessInitialized: false
    property string keyboardBacklightPath: ""
    property bool keyboardHwInitialized: false
    property real clockCenterOffset: bar.statusOsdVisible ? 3 : -3
    // Regional formats (locale-profilectl.sh): the calendar's names and first day of the
    // week follow them, although the shell keeps the locale it was started with.
    readonly property var regionalLocale: Qt.locale(Session.regionalProfile === "us" ? "en_US" : "fr_FR")
    readonly property string stateHome: {
        const configuredStateHome = Quickshell.env("XDG_STATE_HOME");
        return configuredStateHome && configuredStateHome !== "" ? configuredStateHome : Quickshell.env("HOME") + "/.local/state";
    }

    // The connected device first, else one NetworkManager is bringing up.
    readonly property var networkDevice: {
        let connecting = null;
        for (const device of Networking.devices.values) {
            if (device.connected)
                return device;

            if (connecting === null && device.state === ConnectionState.Connecting)
                connecting = device;

        }
        return connecting;
    }
    // Active VPN connections ({name, state}), Quickshell.Networking does not expose them.
    property var vpnConnections: []
    readonly property var vpnConnection: vpnConnections.find((connection) => {
        return connection.state === "activated";
    }) || vpnConnections.find((connection) => {
        return connection.state === "activating";
    }) || null
    readonly property bool vpnActive: vpnConnection !== null && vpnConnection.state === "activated"
    readonly property bool vpnConnecting: vpnConnection !== null && !vpnActive
    readonly property bool networkConnecting: (networkDevice !== null && !networkDevice.connected) || vpnConnecting
    readonly property bool wiredLocked: networkDevice !== null && networkDevice.connected && networkDevice.type === DeviceType.Wired && vpnConnection !== null

    function closeWorkspacePreview() {
        workspaceOpenPending = false;
        workspaceVisible = false;
        workspaceHideDelay.restart();
    }

    function activeWifiNetwork(device) {
        for (const network of device.networks.values) {
            if (network.connected)
                return network;

        }
        return null;
    }

    function networkIcon() {
        const device = bar.networkDevice;
        if (device === null)
            return "󰤮";

        if (device.type === DeviceType.Wired)
            return device.connected ? "󰈀" : "󰌚";

        // Locked while a VPN is up (or coming up) over the Wi-Fi.
        const locked = device.connected && bar.vpnConnection !== null;
        const icons = locked ? ["󰤬", "󰤡", "󰤤", "󰤧", "󰤪"] : ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
        const network = bar.activeWifiNetwork(device);
        const strength = network !== null ? network.signalStrength : 0;
        return icons[Math.max(0, Math.min(icons.length - 1, Math.floor(strength * icons.length)))];
    }

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    function batteryIcon() {
        // Plugged in: the same gauge with the charging bolt.
        const icons = UPower.onBattery ? ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"] : ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"];
        const percentage = Math.max(0, Math.min(1, bar.battery.percentage));
        return icons[Math.min(icons.length - 1, Math.floor(percentage * icons.length))];
    }

    // With maxLevel > 0, a gauge of level / maxLevel replaces the On/Off badge.
    function showStatusOsd(icon, label, enabled, level, maxLevel) {
        calendarCloseDelay.stop();
        calendarHideDelay.stop();
        calendarVisible = false;
        calendarPopupVisible = false;
        statusOsdKind = "";
        statusOsdHideDelay.interval = 1500;
        statusOsdIcon = icon;
        statusOsdLabel = label;
        statusOsdEnabled = enabled;
        statusOsdLevel = level !== undefined ? level : 0;
        statusOsdMaxLevel = maxLevel !== undefined ? maxLevel : 0;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    function showAirPodsOsd(osd) {
        calendarCloseDelay.stop();
        calendarHideDelay.stop();
        calendarVisible = false;
        calendarPopupVisible = false;
        statusOsdKind = "airpods";
        statusOsdImage = osd.image;
        statusOsdRingLevel = osd.level;
        statusOsdRingCharging = osd.charging;
        // Fades the content in like a new OSD.
        statusOsdLabel = "AirPods";
        statusOsdHideDelay.interval = 3000;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    function updateBatteryAlert() {
        if (!hasBattery)
            return ;

        if (!UPower.onBattery) {
            batteryAlertStage = 0;
            return ;
        }
        const stage = batteryPercent <= 5 ? 5 : batteryPercent <= 10 ? 10 : batteryPercent <= 20 ? 20 : 0;
        if (stage === 0 || (batteryAlertStage > 0 && stage >= batteryAlertStage)) {
            if (stage === 0)
                batteryAlertStage = 0;

            return ;
        }
        batteryAlertStage = stage;
        showBatteryOsd(stage === 5 ? "Battery critical" : "Battery low");
    }

    // m:ss, h:mm:ss past an hour.
    function formatDuration(seconds) {
        const pad = (value) => {
            return String(value).padStart(2, "0");
        };
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds / 60) % 60;
        return (hours > 0 ? hours + ":" + pad(minutes) : minutes) + ":" + pad(seconds % 60);
    }

    function showScreenshotOsd(taken) {
        calendarCloseDelay.stop();
        calendarHideDelay.stop();
        calendarVisible = false;
        calendarPopupVisible = false;
        statusOsdKind = "screenshot";
        statusOsdImage = taken.file;
        statusOsdFile = taken.video || taken.file;
        statusOsdTitle = taken.video ? "Recording" : "Screenshot";
        statusOsdLabel = taken.video ? formatDuration(taken.duration) + " · Saved" : taken.annotated ? "Annotated · Saved" : "Copied · Saved";
        statusOsdHideDelay.interval = 3500;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    // Plugged in or unplugged: told in the island, unless unplugging gives a low
    // battery's alert instead.
    function powerSourceChanged() {
        updateBatteryAlert();
        if (!hasBattery || !powerEventsReady)
            return ;

        if (!UPower.onBattery)
            showBatteryOsd("Charging");
        else if (batteryAlertStage === 0)
            showBatteryOsd("On battery");
    }

    function showBatteryOsd(title) {
        calendarCloseDelay.stop();
        calendarHideDelay.stop();
        calendarVisible = false;
        calendarPopupVisible = false;
        statusOsdKind = "battery";
        statusOsdLabel = title;
        batteryDrawEstimate = 0;
        // Unplugged: open until the time left is known, then a moment to read it.
        statusOsdHideDelay.interval = title === "On battery" && batteryTimeLeft <= 0 ? 8000 : title === "Charging" || title === "On battery" ? 2500 : 6000;
        statusOsdVisible = true;
        // The critical alert stays until the computer is plugged in.
        if (batteryCritical)
            statusOsdHideDelay.stop();
        else
            statusOsdHideDelay.restart();
    }

    // Green while charging, mauve on battery, red for the alerts.
    function batteryOsdColor() {
        if (statusOsdLabel === "Charging")
            return green;

        return statusOsdLabel === "On battery" ? mauve : red;
    }

    // "64% · 1 h 05 until full" while charging, "64% · 3 h 10 left" on battery, the
    // percentage alone until UPower has an estimate.
    function batteryDetail() {
        const seconds = UPower.onBattery ? batteryTimeLeft : battery.timeToFull;
        if (!(seconds > 0))
            return batteryPercent + (batteryEstimating ? "% · Estimating…" : UPower.onBattery ? "%" : "% · Plugged in");

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const duration = hours > 0 ? hours + " h " + String(minutes).padStart(2, "0") : minutes + " min";
        return batteryPercent + "% · " + duration + (UPower.onBattery ? " left" : " until full");
    }

    function volumeIcon() {
        if (audioMuted)
            return "";

        if (audioVolume === 0)
            return "";

        if (audioVolume < 34)
            return "";

        if (audioVolume < 67)
            return "";

        return "";
    }

    function brightnessIcon() {
        const icons = ["", "", "", "", "", "", "", "", ""];
        return icons[Math.min(icons.length - 1, Math.floor(screenBrightness * icons.length / 101))];
    }

    function showVolumeOsd() {
        // Checked here too: the volume can change (to 0 while an output goes away)
        // before the output itself does.
        if (audioSink !== volumeSink) {
            resetVolumeOsd();
            return ;
        }
        if (volumeInitialized && audioSink !== null && audioSink.ready && audioSink.audio !== null)
            // Muting keeps the volume: the gauge stays at its level, in lavender.
            showStatusOsd(volumeIcon(), audioMuted ? "Muted" : "Volume", !audioMuted, audioVolume, 100);

    }

    // Another output (e.g. AirPods coming or going) brings its own volume: not a change.
    function resetVolumeOsd() {
        volumeSink = audioSink;
        volumeInitialized = false;
        volumeInitDelay.restart();
    }

    // The island's new content fades in while the pill resizes around it.
    onStatusOsdVisibleChanged: islandContentFade.restart()
    onStatusOsdLabelChanged: islandContentFade.restart()
    onAudioVolumeChanged: showVolumeOsd()
    onAudioMutedChanged: showVolumeOsd()
    onAudioSinkChanged: resetVolumeOsd()
    // Deferred: during the bar's creation the pill's animations do not exist yet.
    onSpotifyPlayerChanged: Qt.callLater(musicPill.resetDiscs)
    onMicSourceChanged: {
        // Wait for the new source's state before reacting to mute changes.
        micStateInitialized = false;
        micInitDelay.restart();
    }
    onMicMutedChanged: {
        if (micStateInitialized)
            showStatusOsd(micMuted ? "󰍭" : "󰍬", "Microphone", !micMuted);

    }
    implicitHeight: 56
    color: "transparent"
    exclusiveZone: 50
    // Named so the player popup can be blurred by a blur_popups layer rule.
    WlrLayershell.namespace: "hyprpunk-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    Item {
        id: barContent

        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24

        RowLayout {
            id: leftGroup

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9

            // Previews a workspace on hover, in a card that grows out of it.
            Pill {
                id: workspacePill

                onHoveredChanged: {
                    if (!hovered) {
                        workspaceOpenDelay.stop();
                        if (bar.workspacePopupVisible)
                            workspaceCloseDelay.restart();

                    }
                }

                WorkspaceSwitcher {
                    id: workspaceSwitcher

                    screen: bar.screen
                    icons: bar.workspaceIcons
                    // Waits like the other pills. The focused workspace is already on screen.
                    onHoveredWorkspaceChanged: {
                        if (hoveredWorkspace !== null && !hoveredWorkspace.focused && !bar.workspacePopupVisible)
                            workspaceOpenDelay.restart();
                        else
                            workspaceOpenDelay.stop();
                    }
                }

                Timer {
                    id: workspaceOpenDelay

                    interval: bar.hoverOpenDelay
                    onTriggered: {
                        if (workspaceSwitcher.hoveredWorkspace === null)
                            return ;

                        // The windows' places, which Hyprland only sends when asked, and
                        // the bar as it stands, laid over every preview.
                        Hyprland.refreshToplevels();
                        barContent.grabToImage((result) => {
                            bar.barSnapshot = result;
                        });
                        bar.previewWorkspace = workspaceSwitcher.hoveredWorkspace;
                        workspaceCloseDelay.stop();
                        workspaceHideDelay.stop();
                        bar.workspaceOpenPending = true;
                        bar.workspacePopupVisible = true;
                    }
                }

                Timer {
                    id: workspaceCloseDelay

                    interval: 220
                    onTriggered: bar.closeWorkspacePreview()
                }

                Timer {
                    id: workspaceHideDelay

                    // Lets the card fold back onto the pill first.
                    interval: 320
                    onTriggered: bar.workspacePopupVisible = false
                }

                PopupWindow {
                    id: workspacePopup

                    readonly property real progress: bar.workspaceProgress

                    function lerp(from, to) {
                        return from + (to - from) * progress;
                    }

                    visible: bar.workspacePopupVisible

                    Connections {
                        function onFrameSwapped() {
                            if (bar.workspaceOpenPending) {
                                bar.workspaceOpenPending = false;
                                bar.workspaceVisible = true;
                            }
                        }

                        target: workspaceCard.Window.window
                    }

                    // The preview inside the control center's padding.
                    implicitWidth: bar.workspacePreviewWidth + 28
                    implicitHeight: bar.workspacePreviewHeight + 28
                    color: "transparent"
                    grabFocus: false

                    anchor {
                        item: workspacePill
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.SlideX
                    }

                    // The anchor is only computed on opening: follow the pill.
                    Connections {
                        function onXChanged() {
                            workspacePopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            workspacePopup.anchor.updateAnchor();
                        }

                        target: workspacePill
                    }

                    ClippingRectangle {
                        id: workspaceCard

                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: workspacePopup.lerp(workspacePill.width, workspacePopup.width)
                        height: workspacePopup.lerp(workspacePill.height, workspacePopup.height)
                        // The pill's corners: rounder ones would let the pill's show under the card.
                        radius: workspacePill.radius
                        color: "transparent"

                        // Same card as the pill it grows from, so the pill itself seems to grow.
                        GlassSurface {
                            radius: workspaceCard.radius
                            tinted: false
                            backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                        }

                        // Laid out at full size, only uncovered while the card grows. Made
                        // again at each opening, so the windows are captured afresh.
                        Loader {
                            x: 14
                            y: 14
                            width: bar.workspacePreviewWidth
                            height: bar.workspacePreviewHeight
                            active: bar.workspacePopupVisible
                            opacity: bar.workspaceVisible ? 1 : 0

                            sourceComponent: WorkspacePreviewCard {
                                workspaces: bar.previewWorkspaces
                                initialWorkspace: bar.previewWorkspace
                                monitor: workspaceSwitcher.hyprlandMonitor
                                wallpaper: bar.wallpaperPath
                                barImage: bar.barSnapshot !== null ? bar.barSnapshot.url : ""
                                barRect: Qt.rect(barContent.x, barContent.y, barContent.width, barContent.height)
                                onWorkspaceChosen: (workspace) => {
                                    workspace.activate();
                                    bar.closeWorkspacePreview();
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered) {
                                    workspaceCloseDelay.stop();
                                    workspaceHideDelay.stop();
                                    bar.workspaceVisible = true;
                                } else {
                                    workspaceCloseDelay.restart();
                                }
                            }
                        }

                    }

                    mask: Region {
                        item: workspaceCard
                    }

                }

            }

            // Opens the system monitor on hover, which grows out of it like the player.
            Pill {
                id: monitorPill

                visible: bar.width >= 1200
                onHoveredChanged: {
                    if (hovered) {
                        monitorCloseDelay.stop();
                        monitorHideDelay.stop();
                        if (!bar.monitorPopupVisible)
                            monitorOpenDelay.restart();
                        else
                            bar.monitorVisible = true;
                    } else {
                        monitorOpenDelay.stop();
                        monitorCloseDelay.restart();
                    }
                }

                IconText {
                    icon: ""
                    text: bar.memoryText
                }

                IconText {
                    icon: ""
                    text: bar.cpuUsage + "%"
                }

                Timer {
                    id: monitorOpenDelay

                    interval: bar.hoverOpenDelay
                    onTriggered: {
                        bar.monitorOpenPending = true;
                        bar.monitorPopupVisible = true;
                    }
                }

                Timer {
                    id: monitorCloseDelay

                    interval: 220
                    onTriggered: {
                        bar.monitorOpenPending = false;
                        bar.monitorVisible = false;
                        monitorHideDelay.restart();
                    }
                }

                Timer {
                    id: monitorHideDelay

                    // Lets the card fold back onto the pill first.
                    interval: 320
                    onTriggered: bar.monitorPopupVisible = false
                }

                PopupWindow {
                    id: monitorPopup

                    readonly property real progress: bar.monitorProgress

                    function lerp(from, to) {
                        return from + (to - from) * progress;
                    }

                    visible: bar.monitorPopupVisible

                    Connections {
                        function onFrameSwapped() {
                            if (bar.monitorOpenPending) {
                                bar.monitorOpenPending = false;
                                bar.monitorVisible = true;
                            }
                        }

                        target: monitorCard.Window.window
                    }

                    implicitWidth: monitorContent.implicitWidth
                    implicitHeight: monitorContent.implicitHeight
                    color: "transparent"
                    grabFocus: false

                    anchor {
                        item: monitorPill
                        edges: Edges.Top | Edges.Left
                        gravity: Edges.Bottom | Edges.Right
                        adjustment: PopupAdjustment.SlideX
                    }

                    // The anchor is only computed on opening: follow the pill when the
                    // workspaces before it change width.
                    Connections {
                        function onXChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        target: monitorPill
                    }

                    Connections {
                        function onXChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        function onYChanged() {
                            monitorPopup.anchor.updateAnchor();
                        }

                        target: monitorPill.parent
                    }

                    ClippingRectangle {
                        id: monitorCard

                        anchors.top: parent.top
                        anchors.left: parent.left
                        width: monitorPopup.lerp(monitorPill.width, monitorPopup.width)
                        height: monitorPopup.lerp(monitorPill.height, monitorPopup.height)
                        // The pill's corners: rounder ones would let the pill's show under the card.
                        radius: monitorPill.radius
                        color: "transparent"

                        // Same card as the pill it grows from: base at 0.9 with the glass rim,
                        // so the pill itself seems to grow.
                        GlassSurface {
                            radius: monitorCard.radius
                            tinted: false
                            backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                        }

                        // Laid out at full size, only uncovered while the card grows.
                        SystemMonitorCard {
                            id: monitorContent

                            anchors.top: parent.top
                            anchors.left: parent.left
                            width: monitorPopup.width
                            opacity: bar.monitorVisible ? 1 : 0
                            active: bar.monitorPopupVisible
                            temperature: bar.cpuTemperature
                            frequency: bar.cpuFrequency
                            model: bar.cpuModel

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            onHoveredChanged: {
                                if (hovered) {
                                    monitorCloseDelay.stop();
                                    monitorHideDelay.stop();
                                    bar.monitorVisible = true;
                                } else {
                                    monitorCloseDelay.restart();
                                }
                            }
                        }

                    }

                    mask: Region {
                        item: monitorCard
                    }

                }

            }

        }

        // The privacy and recording dots while the calendar covers the island: right of
        // its card, at the island's height, following its edge as it grows.
        PrivacyDot {
            x: centerGroup.x + clockPill.x + clockPill.width / 2 + calendarCard.width / 2 + 8
            y: centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active ? calendarCard.openness : 0
            visible: bar.calendarPopupVisible && opacity > 0
        }

        // The same while the island shows something else (an OSD): right of it.
        PrivacyDot {
            x: centerGroup.x + clockPill.x + clockPill.width + 8
            y: centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active && bar.statusOsdVisible && !bar.calendarPopupVisible ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }

            }

        }

        RowLayout {
            id: centerGroup

            anchors.centerIn: parent
            anchors.verticalCenterOffset: bar.clockCenterOffset
            spacing: 9
            // The island moves with the group (centring and the OSD offset), not inside it.
            onXChanged: clockPill.publishGeometry()
            onYChanged: clockPill.publishGeometry()

            Pill {
                id: clockPill

                function publishGeometry() {
                    const origin = mapToItem(null, 0, 0);
                    bar.shellState.islandPill = {
                        "centerOffset": origin.x + width / 2 - bar.width / 2,
                        "top": origin.y,
                        "width": width,
                        "height": height
                    };
                }

                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                spacing: 8

                // The screenshot or recording just taken opens in its viewer.
                TapHandler {
                    enabled: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
                    cursorShape: Qt.PointingHandCursor
                    onTapped: {
                        Quickshell.execDetached(["xdg-open", bar.statusOsdFile]);
                        bar.statusOsdVisible = false;
                    }
                }
                horizontalPadding: bar.statusOsdVisible ? 36 : 20
                implicitHeight: bar.statusOsdVisible ? 50 : 38
                contentOpacity: 1

                Label {
                    id: dateTimeLabel

                    visible: !bar.statusOsdVisible
                    text: Qt.formatDateTime(clock.date, "HH:mm")

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                calendarCloseDelay.stop();
                                calendarHideDelay.stop();
                                if (!bar.calendarPopupVisible)
                                    calendarOpenDelay.restart();
                                else
                                    bar.calendarVisible = true;
                            } else {
                                calendarOpenDelay.stop();
                                calendarCloseDelay.restart();
                            }
                        }
                    }

                    Timer {
                        id: calendarOpenDelay

                        interval: bar.hoverOpenDelay
                        onTriggered: {
                            calendarPopup.monthOffset = 0;
                            bar.calendarOpenPending = true;
                            bar.calendarPopupVisible = true;
                        }
                    }

                    SystemClock {
                        id: clock

                        precision: SystemClock.Minutes
                    }

                }

                // Privacy: a dot after the time while an app records you, green for the
                // camera (over the microphone), orange for the microphone alone.
                Item {
                    readonly property bool shown: !bar.statusOsdVisible && (bar.shellState.cameraInUse || bar.shellState.microphoneInUse)

                    visible: Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? 8 : 0
                    Layout.leftMargin: shown ? -2 : -clockPill.spacing
                    implicitHeight: 8

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        scale: parent.shown ? 1 : 0
                        color: bar.shellState.cameraInUse ? bar.green : bar.peach

                        Behavior on scale {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutBack
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }

                        }

                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on Layout.leftMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // Recording: a pulsing red dot and the time recorded after the time, a
                // click stops it.
                Item {
                    id: recordingChip

                    readonly property bool shown: !bar.statusOsdVisible && bar.shellState.recording

                    visible: Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? recordingRow.implicitWidth + 16 : 0
                    Layout.leftMargin: shown ? 0 : -clockPill.spacing
                    implicitHeight: 24
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: recordingHover.hovered ? Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.28) : Qt.rgba(243 / 255, 139 / 255, 168 / 255, 0.16)

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                    }

                    Row {
                        id: recordingRow

                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        spacing: 6

                        // The stop square on hover, the dot otherwise.
                        Rectangle {
                            id: recordingDot

                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: recordingHover.hovered ? 2 : 4
                            color: bar.red

                            SequentialAnimation on opacity {
                                running: recordingChip.shown && !recordingHover.hovered
                                loops: Animation.Infinite
                                onRunningChanged: {
                                    if (!running)
                                        recordingDot.opacity = 1;

                                }

                                NumberAnimation {
                                    to: 0.3
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }

                                NumberAnimation {
                                    to: 1
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }

                            }

                            Behavior on radius {
                                NumberAnimation {
                                    duration: 140
                                }

                            }

                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: bar.formatDuration(bar.recordingElapsed)
                            color: bar.red
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.features: {
                                "tnum": 1
                            }
                        }

                    }

                    HoverHandler {
                        id: recordingHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: bar.shellState.requestScreenshot("stop", "", 0)
                    }

                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on Layout.leftMargin {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                Text {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === ""
                    text: bar.statusOsdIcon
                    color: bar.mauve
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                }

                // Volume and screen brightness only show their icon and bar.
                Text {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel <= 10
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    text: bar.statusOsdLabel
                    color: bar.mauve
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Rectangle {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel <= 0
                    implicitWidth: statusOsdStateText.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: bar.statusOsdEnabled ? bar.mauve : bar.surface1

                    Text {
                        id: statusOsdStateText

                        anchors.centerIn: parent
                        text: bar.statusOsdEnabled ? "On" : "Off"
                        color: bar.statusOsdEnabled ? bar.base : bar.overlay2
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }

                }

                Row {
                    readonly property int segments: bar.statusOsdMaxLevel
                    readonly property int filled: bar.statusOsdLevel

                    visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel > 0 && bar.statusOsdMaxLevel <= 10
                    spacing: 4

                    Repeater {
                        model: parent.segments

                        Rectangle {
                            required property int index

                            width: 18
                            height: 8
                            radius: 4
                            color: index < parent.filled ? bar.mauve : bar.surface1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                    }

                }

                // Screenshot: the picture in small, then what became of it.
                ClippingRectangle {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
                    implicitWidth: Math.round(30 * Math.min(1.8, Math.max(0.6, screenshotThumbnail.implicitWidth / Math.max(1, screenshotThumbnail.implicitHeight))))
                    implicitHeight: 30
                    radius: 6
                    color: bar.surface1

                    Image {
                        id: screenshotThumbnail

                        anchors.fill: parent
                        source: bar.statusOsdKind === "screenshot" && bar.statusOsdImage !== "" ? "file://" + bar.statusOsdImage : ""
                        sourceSize.height: 90
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        smooth: true
                        mipmap: true
                    }

                    // A recording's play sign.
                    Text {
                        anchors.centerIn: parent
                        visible: bar.statusOsdTitle === "Recording"
                        text: "󰐊"
                        color: "#cdd6f4"
                        style: Text.Outline
                        styleColor: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.6)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                    }

                }

                Column {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "screenshot"
                    Layout.leftMargin: 2
                    spacing: 0

                    Text {
                        text: bar.statusOsdTitle
                        color: bar.mauve
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    Text {
                        text: bar.statusOsdLabel
                        color: bar.lavender
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                }

                // Battery: plugged in (green), unplugged (mauve) or running low (red,
                // pulsing while critical), a title and the time left or to full.
                Text {
                    id: batteryOsdIcon

                    visible: bar.statusOsdVisible && bar.statusOsdKind === "battery"
                    text: bar.batteryIcon()
                    color: bar.batteryOsdColor()
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 22

                    SequentialAnimation on opacity {
                        running: bar.batteryCritical && batteryOsdIcon.visible
                        loops: Animation.Infinite
                        onRunningChanged: {
                            if (!running)
                                batteryOsdIcon.opacity = 1;

                        }

                        NumberAnimation {
                            to: 0.35
                            duration: 600
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 600
                            easing.type: Easing.InOutSine
                        }

                    }

                }

                Column {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "battery"
                    Layout.leftMargin: 2
                    spacing: 0

                    Text {
                        text: bar.statusOsdLabel
                        color: bar.batteryOsdColor()
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    Text {
                        text: bar.batteryDetail()
                        color: bar.lavender
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                }

                // AirPods: the pods on the left, their battery ring on the right.
                Item {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
                    // As tall as the battery ring.
                    implicitWidth: 40
                    implicitHeight: 26

                    Image {
                        id: airPodsOsdImage

                        anchors.fill: parent
                        source: bar.statusOsdImage !== "" ? "file://" + bar.statusOsdImage : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize.height: 60
                        smooth: true
                        mipmap: true
                    }

                    // No render (AirPods Max, not downloaded yet): the glyph.
                    Text {
                        visible: airPodsOsdImage.status !== Image.Ready
                        anchors.centerIn: parent
                        text: "󱡏"
                        color: bar.mauve
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                    }

                }

                Item {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
                    implicitWidth: 136
                    implicitHeight: 1
                }

                Shape {
                    id: airPodsOsdRing

                    readonly property bool low: bar.statusOsdRingLevel !== null && bar.statusOsdRingLevel <= 20 && !bar.statusOsdRingCharging

                    visible: bar.statusOsdVisible && bar.statusOsdKind === "airpods"
                    implicitWidth: 26
                    implicitHeight: 26
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: bar.surface1
                        strokeWidth: 3.5
                        fillColor: "transparent"

                        PathAngleArc {
                            centerX: 13
                            centerY: 13
                            radiusX: 11
                            radiusY: 11
                            startAngle: 0
                            sweepAngle: 360
                        }

                    }

                    ShapePath {
                        strokeColor: airPodsOsdRing.low ? bar.red : bar.green
                        strokeWidth: 3.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 13
                            centerY: 13
                            radiusX: 11
                            radiusY: 11
                            startAngle: -90
                            sweepAngle: bar.statusOsdRingLevel === null ? 0 : 3.6 * bar.statusOsdRingLevel
                        }

                    }

                }

                // Fine-grained levels (volume, screen brightness): continuous bar.
                Rectangle {
                    visible: bar.statusOsdVisible && bar.statusOsdKind === "" && bar.statusOsdMaxLevel > 10
                    implicitWidth: 160
                    implicitHeight: 8
                    radius: 4
                    color: bar.surface1

                    Rectangle {
                        width: parent.width * Math.min(1, bar.statusOsdLevel / Math.max(1, bar.statusOsdMaxLevel))
                        height: parent.height
                        radius: parent.radius
                        // Lavender while off: a muted volume keeps its level.
                        color: bar.statusOsdEnabled ? bar.mauve : bar.lavender

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }

                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on implicitHeight {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            SequentialAnimation {
                id: islandContentFade

                PropertyAction {
                    target: clockPill
                    property: "contentOpacity"
                    value: 0
                }

                // The pill is ~90% open by then, so the content is not cut by its edges.
                PauseAnimation {
                    duration: 110
                }

                NumberAnimation {
                    target: clockPill
                    property: "contentOpacity"
                    to: 1
                    duration: 140
                    easing.type: Easing.OutCubic
                }

            }

            Timer {
                id: statusOsdHideDelay

                interval: 1500
                onTriggered: {
                    // Another OSD over the critical battery alert: back to the alert.
                    if (bar.batteryCritical)
                        bar.showBatteryOsd("Battery critical");
                    else
                        bar.statusOsdVisible = false;
                }
            }

            Timer {
                id: calendarCloseDelay

                interval: 180
                onTriggered: {
                    bar.calendarOpenPending = false;
                    bar.calendarVisible = false;
                    calendarHideDelay.restart();
                }
            }

            Timer {
                id: calendarHideDelay

                // Slightly longer than the 280 ms fold so the card is back on the pill first.
                interval: 320
                onTriggered: bar.calendarPopupVisible = false
            }

            PopupWindow {
                id: calendarPopup

                readonly property date currentDate: clock.date
                readonly property int currentYear: currentDate.getFullYear()
                readonly property int currentMonth: currentDate.getMonth()
                readonly property int currentDay: currentDate.getDate()
                property int monthOffset: 0
                readonly property date displayedMonth: new Date(currentYear, currentMonth + monthOffset, 1)
                readonly property int displayedYear: displayedMonth.getFullYear()
                readonly property int displayedMonthNumber: displayedMonth.getMonth()
                // Column of the month's first day, the week starting on the locale's first day.
                readonly property int firstWeekday: (displayedMonth.getDay() - bar.regionalLocale.firstDayOfWeek + 7) % 7
                readonly property int daysInMonth: new Date(displayedYear, displayedMonthNumber + 1, 0).getDate()
                readonly property int weekRows: Math.ceil((firstWeekday + daysInMonth) / 7)
                // Card height for the displayed month, measured from the real layout.
                readonly property real contentHeight: calendarBody.y + calendarBody.implicitHeight + 18
                property int pendingMonthDelta: 0

                function changeMonth(delta) {
                    if (monthTransition.running)
                        return ;

                    pendingMonthDelta = delta;
                    monthTransition.start();
                }

                visible: bar.calendarPopupVisible

                Connections {
                    function onFrameSwapped() {
                        if (bar.calendarOpenPending) {
                            bar.calendarOpenPending = false;
                            bar.calendarVisible = true;
                        }
                    }

                    target: calendarCard.Window.window
                }

                mask: Region {
                    item: calendarCard
                }
                implicitWidth: 322
                // Sized for a six-week month so the card can animate without being cut.
                // Not derived from weekRows: the layout updates a frame later, and the
                // popup would be resized twice (the whole content shakes).
                implicitHeight: calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + 18
                color: "transparent"
                grabFocus: false

                anchor {
                    item: clockPill
                    edges: Edges.Top
                    gravity: Edges.Bottom
                    adjustment: PopupAdjustment.SlideX
                }

                ClippingRectangle {
                    id: calendarCard

                    // 0 at the pill's size, 1 once fully open (follows the width animation).
                    readonly property real openness: Math.max(0, Math.min(1, (width - clockPill.width) / Math.max(1, calendarPopup.width - clockPill.width)))

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: bar.calendarVisible ? calendarPopup.width : clockPill.width
                    height: bar.calendarVisible ? calendarPopup.contentHeight : clockPill.height
                    // The pill's corners: rounder ones would let the pill's show under the card.
                    radius: clockPill.radius
                    color: "transparent"

                    // Same card as the island it grows from: base at 0.9, blurred by
                    // the hyprpunk-bar blur_popups layer rule, with the glass rim.
                    GlassSurface {
                        radius: calendarCard.radius
                        tinted: false
                        backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y > 0)
                                calendarPopup.changeMonth(-1);
                            else if (wheel.angleDelta.y < 0)
                                calendarPopup.changeMonth(1);
                            wheel.accepted = true;
                        }
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                calendarCloseDelay.stop();
                                calendarHideDelay.stop();
                                bar.calendarPopupVisible = true;
                                bar.calendarVisible = true;
                            } else {
                                calendarCloseDelay.restart();
                            }
                        }
                    }

                    Item {
                        id: expandedClockHeader

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: clockPill.width
                        height: clockPill.height

                        Label {
                            anchors.centerIn: parent
                            text: Qt.formatDateTime(clock.date, "HH:mm")
                        }

                    }

                    Rectangle {
                        id: calendarSeparator

                        anchors.top: expandedClockHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: bar.surface1
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    IconText {
                        id: calendarDate

                        anchors.top: calendarSeparator.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: "󰃭"
                        text: bar.regionalLocale.toString(clock.date, bar.regionalLocale.dateFormat(Locale.LongFormat))
                        color: bar.lavender
                        font.pixelSize: 15
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Rectangle {
                        id: dateSeparator

                        anchors.top: calendarDate.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 10
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        height: 1
                        color: bar.surface1
                        opacity: bar.calendarVisible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    ColumnLayout {
                        id: calendarBody

                        property real monthSlideY: 0
                        property real monthTransitionOpacity: 1

                        anchors.top: dateSeparator.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        anchors.topMargin: 8
                        spacing: 10
                        opacity: (bar.calendarVisible ? 1 : 0) * monthTransitionOpacity

                        Label {
                            id: calendarMonthLabel

                            Layout.alignment: Qt.AlignHCenter
                            text: bar.capitalized(bar.regionalLocale.standaloneMonthName(calendarPopup.displayedMonthNumber)) + " " + calendarPopup.displayedYear
                            color: bar.mauve
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        GridLayout {
                            id: calendarGrid

                            // Weekday row (25) and six weeks (29), with their spacing.
                            readonly property real sixWeekHeight: 25 + 6 * 29 + 6 * rowSpacing

                            Layout.fillWidth: true
                            columns: 7
                            columnSpacing: 4
                            rowSpacing: 4

                            Repeater {
                                // From the locale's first day, "Lun" rather than "lun.".
                                model: [0, 1, 2, 3, 4, 5, 6].map((offset) => {
                                    return bar.capitalized(bar.regionalLocale.dayName((bar.regionalLocale.firstDayOfWeek + offset) % 7, Locale.ShortFormat).replace(/\.$/, ""));
                                })

                                Label {
                                    required property string modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 25
                                    text: modelData
                                    color: bar.mauve
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                            }

                            Repeater {
                                model: calendarPopup.weekRows * 7

                                Rectangle {
                                    required property int index
                                    readonly property int dayNumber: index - calendarPopup.firstWeekday + 1
                                    readonly property bool validDay: dayNumber >= 1 && dayNumber <= calendarPopup.daysInMonth
                                    readonly property bool isToday: validDay && dayNumber === calendarPopup.currentDay && calendarPopup.displayedMonthNumber === calendarPopup.currentMonth && calendarPopup.displayedYear === calendarPopup.currentYear

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 29
                                    radius: 9
                                    color: isToday ? bar.mauve : "transparent"

                                    Label {
                                        anchors.centerIn: parent
                                        text: parent.validDay ? parent.dayNumber : ""
                                        color: parent.isToday ? bar.base : bar.mauve
                                        font.pixelSize: 14
                                        font.weight: parent.isToday ? Font.Bold : Font.Medium
                                    }

                                }

                            }

                        }

                        transform: Translate {
                            y: calendarBody.monthSlideY
                        }

                    }

                    SequentialAnimation {
                        id: monthTransition

                        ParallelAnimation {
                            NumberAnimation {
                                target: calendarBody
                                property: "monthSlideY"
                                to: calendarPopup.pendingMonthDelta > 0 ? -28 : 28
                                duration: 120
                                easing.type: Easing.InCubic
                            }

                            NumberAnimation {
                                target: calendarBody
                                property: "monthTransitionOpacity"
                                to: 0
                                duration: 100
                                easing.type: Easing.InCubic
                            }

                        }

                        ScriptAction {
                            script: {
                                calendarPopup.monthOffset += calendarPopup.pendingMonthDelta;
                                calendarBody.monthSlideY = calendarPopup.pendingMonthDelta > 0 ? 28 : -28;
                            }
                        }

                        ParallelAnimation {
                            NumberAnimation {
                                target: calendarBody
                                property: "monthSlideY"
                                to: 0
                                duration: 160
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: calendarBody
                                property: "monthTransitionOpacity"
                                to: 1
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9
            // When the control pill changes width, it publishes before the row has moved
            // back against the right edge: publish again once the row is in place.
            onXChanged: controlPill.publishGeometry()
            onYChanged: controlPill.publishGeometry()

            DropInSlot {
                shown: bar.updateCount > 0

                Pill {
                    IconText {
                        icon: ""

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: upgradeProcess.running = true
                        }

                        // Keeps the last count while the pill flies away.
                        Binding on text {
                            when: bar.updateCount > 0
                            value: String(bar.updateCount)
                            restoreMode: Binding.RestoreNone
                        }

                    }

                }

            }

            // Round cover of the Spotify track, opens the player on hover.
            DropInSlot {
                shown: bar.spotifyPlayer !== null

                Rectangle {
                    id: musicPill

                    // Angle of the front disc: 0 = upright, where every track starts.
                    property real spin: 0
                    // 0 -> 1 after a new track or a restart: the disc only starts spinning
                    // once it is upright in the hole.
                    property real spinFactor: 1
                    // While the player is open (from the hover until it is fully folded back),
                    // the disc stops and goes on from the same angle afterwards: no jump.
                    readonly property bool displayFrozen: bar.musicPopupVisible
                    readonly property real frontAngle: spin + rewind
                    // Degrees per second: speeds up and slows down like a turntable.
                    property real spinSpeed: bar.spotifyPlayer !== null && bar.spotifyPlayer.isPlaying ? 45 : 0
                    // Angle of the disc rolling out, frozen when the track changed.
                    property real outgoingSpin: 0
                    // 0 -> 1 while the discs swap, direction 1 = next track, -1 = previous.
                    property real swipe: 1
                    property int swipeDirection: 1
                    property bool frontIsA: true
                    property string currentTrackId: ""
                    property var trackHistory: []
                    // Set by the player buttons just before skipping.
                    property int skipHint: 0
                    // Extra angle of the front disc while it rewinds (track restarted).
                    property real rewind: 0
                    // Last position reported by the player (seconds), when and while playing or not.
                    property real knownPosition: 0
                    property real knownPositionTime: 0
                    property bool knownPositionPlaying: false
                    property real trackChangeTime: 0

                    // Pops out then settles, on play, pause and track changes alike.
                    function pulse() {
                        pulseAnimation.restart();
                    }

                    // Spotify's 64px variant of the 640px art: the pill shows it at 34px and it
                    // loads much faster.
                    function pillArt() {
                        return bar.spotifyPlayer.trackArtUrl.replace("/ab67616d0000b273", "/ab67616d00004851");
                    }

                    function frontDisc() {
                        return frontIsA ? discA : discB;
                    }

                    function trackId() {
                        const player = bar.spotifyPlayer;
                        return player.metadata["mpris:trackid"] ?? (player.trackTitle + player.trackArtist);
                    }

                    // The front disc comes in from one side, the other one leaves on the opposite side.
                    function discX(front) {
                        const travel = discWindow.width + 8;
                        return front ? swipeDirection * travel * (1 - swipe) : -swipeDirection * travel * swipe;
                    }

                    // Rolls without slipping: one turn every 2πr travelled.
                    function discRotation(front, x) {
                        return (front ? frontAngle : outgoingSpin) + x * 180 / (Math.PI * discWindow.width / 2);
                    }

                    function rememberPosition(position) {
                        knownPosition = position ?? bar.spotifyPlayer.position;
                        knownPositionTime = Date.now();
                        knownPositionPlaying = bar.spotifyPlayer.isPlaying;
                    }

                    // "Previous" past the first seconds restarts the track instead of changing it:
                    // the position jumps back to 0 on the same track.
                    function checkRestart(position) {
                        const current = position ?? bar.spotifyPlayer.position;
                        const expected = knownPosition + (knownPositionPlaying ? (Date.now() - knownPositionTime) / 1000 : 0);
                        // Position updates right after a track change are not restarts (they gave
                        // the new disc an extra turn); "previous" that early changes track anyway.
                        const settled = Date.now() - trackChangeTime > 2000;
                        const restarted = settled && trackId() === currentTrackId && current < 1.5 && expected > 2;
                        rememberPosition(current);
                        if (restarted && displayFrozen) {
                            // Hidden under the player's cover: straight back to upright.
                            rewindAnimation.stop();
                            spin = 0;
                            rewind = 0;
                            pulse();
                        } else if (restarted) {
                            // Back to upright, at least one full turn so it shows.
                            spinRamp.stop();
                            spinFactor = 0;
                            rewindAnimation.to = -(spin + (spin < 120 ? 360 : 0));
                            pulse();
                            rewindAnimation.restart();
                        }
                    }

                    function resetDiscs() {
                        discSwipe.stop();
                        rewindAnimation.stop();
                        swipe = 1;
                        spin = 0;
                        rewind = 0;
                        spinFactor = 1;
                        currentTrackId = bar.spotifyPlayer !== null ? trackId() : "";
                        trackHistory = currentTrackId !== "" ? [currentTrackId] : [];
                        frontDisc().source = bar.spotifyPlayer !== null ? pillArt() : "";
                        if (bar.spotifyPlayer !== null)
                            rememberPosition();

                    }

                    function changeTrack() {
                        const id = trackId();
                        if (id === currentTrackId)
                            return ;

                        // Without a hint (media keys, phone...): back to the previous track
                        // in the history means backwards.
                        const history = trackHistory.slice();
                        let direction = skipHint;
                        if (direction === 0 && Date.now() < bar.shellState.musicSkipUntil)
                            direction = bar.shellState.musicSkipDirection;

                        if (direction === 0)
                            direction = history.length >= 2 && history[history.length - 2] === id ? -1 : 1;

                        if (direction < 0 && history.length >= 2 && history[history.length - 2] === id)
                            history.pop();
                        else
                            history.push(id);
                        trackHistory = history.slice(-50);
                        skipHint = 0;
                        currentTrackId = id;
                        // The player still reports the old track's position at this point.
                        rememberPosition(0);
                        trackChangeTime = Date.now();
                        discSwipe.stop();
                        // The new disc waits outside the hole, the old one stays in place.
                        swipe = 0;
                        // The old disc keeps its angle, the new one rolls in and lands upright.
                        outgoingSpin = frontAngle;
                        rewindAnimation.stop();
                        rewind = 0;
                        spin = 0;
                        spinRamp.stop();
                        spinFactor = 0;
                        swipeDirection = direction;
                        const previousArt = frontDisc().source;
                        frontIsA = !frontIsA;
                        const art = pillArt();
                        // Spotify sometimes sends the new art a moment later (onTrackArtUrlChanged).
                        const artPending = art === "" || art === previousArt.toString();
                        frontDisc().source = artPending ? "" : art;
                        // No waiting for the cover: it fades in on the disc once loaded.
                        pulse();
                        discSwipe.restart();
                    }

                    onDisplayFrozenChanged: {
                        // Starts again gently once the player is folded back.
                        if (!displayFrozen) {
                            spinFactor = 0;
                            spinRamp.restart();
                        }
                    }
                    Component.onCompleted: Qt.callLater(resetDiscs)
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: 19
                    // The pills' card is painted by the hole and the ring below, once
                    // everywhere: a fill here would show twice under the ring.
                    color: "transparent"

                    // Shows while a disc rolls in or out of the hole.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: width / 2
                        color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                    }

                    Behavior on spinSpeed {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.InOutQuad
                        }

                    }

                    // Two discs: on a track change the old one rolls out of the hole and
                    // the new one rolls in, forwards or backwards.
                    Item {
                        id: discWindow

                        anchors.fill: parent
                        // Slightly larger than the hole: its edge is drawn by the ring above.
                        anchors.margins: 2

                        CoverDisc {
                            id: discA

                            width: parent.width
                            height: parent.height
                            x: musicPill.discX(musicPill.frontIsA)
                            rotation: musicPill.discRotation(musicPill.frontIsA, x)
                            visible: musicPill.frontIsA || musicPill.swipe < 1
                        }

                        CoverDisc {
                            id: discB

                            width: parent.width
                            height: parent.height
                            x: musicPill.discX(!musicPill.frontIsA)
                            rotation: musicPill.discRotation(!musicPill.frontIsA, x)
                            visible: !musicPill.frontIsA || musicPill.swipe < 1
                        }

                    }

                    Rectangle {
                        id: discWindowMask

                        anchors.fill: discWindow
                        radius: width / 2
                        visible: false
                        layer.enabled: true
                    }

                    // A layer on discWindow was not redrawn when a disc rotated.
                    ShaderEffectSource {
                        id: discWindowSource

                        sourceItem: discWindow
                        hideSource: true
                        live: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: discWindow
                        source: discWindowSource
                        maskEnabled: true
                        maskSource: discWindowMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    // The pill around the hole, the pills' card. The masks leave a jagged edge
                    // (worse while spinning): the ring covers it, the hole stays 32px wide.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                        antialiasing: true
                    }

                    // Over the ring, like the other pills' rim.
                    GlassSurface {
                        z: 1
                        radius: 19
                        tinted: false
                    }

                    // Spins while playing, keeps its angle while paused.
                    FrameAnimation {
                        running: musicPill.spinSpeed > 0 && !musicPill.displayFrozen
                        onTriggered: musicPill.spin = (musicPill.spin + musicPill.spinSpeed * musicPill.spinFactor * frameTime) % 360
                    }

                    SequentialAnimation {
                        id: pulseAnimation

                        NumberAnimation {
                            target: musicPill
                            property: "scale"
                            to: 1.16
                            duration: 120
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: musicPill
                            property: "scale"
                            to: 1
                            duration: 480
                            easing.type: Easing.OutBack
                            easing.overshoot: 3
                        }

                    }

                    // Leaves time for a real track change (which also resets the position)
                    // to be announced first.
                    Timer {
                        id: restartCheckDelay

                        interval: 150
                        onTriggered: musicPill.checkRestart()
                    }

                    // One quick turn backwards, like a record pulled back by hand.
                    NumberAnimation {
                        id: rewindAnimation

                        target: musicPill
                        property: "rewind"
                        from: 0
                        duration: 650
                        easing.type: Easing.OutCubic
                        onFinished: {
                            musicPill.spin = 0;
                            musicPill.rewind = 0;
                            spinRamp.restart();
                        }
                    }

                    // Spotify does not always announce the restart (no Seeked signal): after a
                    // "previous" request, its position is asked directly.
                    Timer {
                        id: restartProbeDelay

                        interval: 350
                        onTriggered: restartProbe.running = true
                    }

                    Process {
                        id: restartProbe

                        // Position in microseconds, and the track it belongs to: a real track
                        // change not announced yet must not look like a restart.
                        command: ["playerctl", "-p", "spotify", "metadata", "--format", "{{position}} {{mpris:trackid}}"]

                        stdout: StdioCollector {
                            onStreamFinished: {
                                const [position, track] = text.trim().split(" ");
                                if (bar.spotifyPlayer !== null && track === musicPill.currentTrackId && !isNaN(parseInt(position)))
                                    musicPill.checkRestart(parseInt(position) / 1e6);

                            }
                        }

                    }

                    Connections {
                        function onMusicPreviousRequestsChanged() {
                            restartProbeDelay.restart();
                        }

                        target: bar.shellState
                    }

                    // Starts spinning gently, like a turntable getting up to speed.
                    NumberAnimation {
                        id: spinRamp

                        target: musicPill
                        property: "spinFactor"
                        to: 1
                        duration: 700
                        easing.type: Easing.InQuad
                    }

                    NumberAnimation {
                        id: discSwipe

                        target: musicPill
                        property: "swipe"
                        from: 0
                        to: 1
                        duration: 520
                        easing.type: Easing.OutCubic
                        onFinished: spinRamp.restart()
                    }

                    Connections {
                        function onPostTrackChanged() {
                            musicPill.changeTrack();
                        }

                        function onPositionChanged() {
                            restartCheckDelay.restart();
                        }

                        function onIsPlayingChanged() {
                            musicPill.rememberPosition();
                            musicPill.pulse();
                        }

                        function onTrackArtUrlChanged() {
                            // Art sometimes arrives after the track change. It also arrives just
                            // before it, while the old disc is still in front: left to changeTrack.
                            if (musicPill.trackId() === musicPill.currentTrackId)
                                musicPill.frontDisc().source = musicPill.pillArt();

                        }

                        target: bar.spotifyPlayer
                    }

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered) {
                                musicCloseDelay.stop();
                                musicHideDelay.stop();
                                if (!bar.musicPopupVisible)
                                    musicOpenDelay.restart();
                                else
                                    bar.musicVisible = true;
                            } else {
                                musicOpenDelay.stop();
                                musicCloseDelay.restart();
                            }
                        }
                    }

                    Timer {
                        id: musicOpenDelay

                        interval: bar.hoverOpenDelay
                        onTriggered: {
                            bar.musicOpenPending = true;
                            bar.musicPopupVisible = true;
                        }
                    }

                    Timer {
                        id: musicCloseDelay

                        interval: 220
                        onTriggered: {
                            bar.musicOpenPending = false;
                            bar.musicVisible = false;
                            musicHideDelay.restart();
                        }
                    }

                    Timer {
                        id: musicHideDelay

                        // Lets the card fold back onto the pill first.
                        interval: 320
                        onTriggered: bar.musicPopupVisible = false
                    }

                    // Opens like the calendar: the card grows out of the cover pill and
                    // the cover moves to its place in the player.
                    PopupWindow {
                        id: musicPopup

                        readonly property real progress: bar.musicProgress
                        // The cover settles during the first 70% so it never crosses the fading-in title.
                        readonly property real coverProgress: Math.min(1, progress / 0.7)
                        // Angle of the pill's disc (-180..180): the cover leaves it at that angle and
                        // straightens up while opening, and turns back to it while folding.
                        readonly property real discAngle: ((musicPill.frontAngle % 360) + 540) % 360 - 180

                        function lerp(from, to) {
                            return from + (to - from) * progress;
                        }

                        visible: bar.musicPopupVisible && bar.spotifyPlayer !== null

                        Connections {
                            function onFrameSwapped() {
                                if (bar.musicOpenPending) {
                                    bar.musicOpenPending = false;
                                    bar.musicVisible = true;
                                }
                            }

                            target: musicCard.Window.window
                        }

                        implicitWidth: 380
                        // Tall enough for the lyrics: the card grows and shrinks inside it.
                        implicitHeight: musicPlayerCard.fullHeight
                        color: "transparent"
                        grabFocus: false

                        anchor {
                            item: musicPill
                            edges: Edges.Top | Edges.Right
                            gravity: Edges.Bottom | Edges.Left
                            adjustment: PopupAdjustment.SlideX
                        }

                        // The anchor is only computed on opening: follow the pill when it
                        // resizes or when the control pill after it changes width.
                        Connections {
                            function onXChanged() {
                                musicPopup.anchor.updateAnchor();
                            }

                            function onYChanged() {
                                musicPopup.anchor.updateAnchor();
                            }

                            function onWidthChanged() {
                                musicPopup.anchor.updateAnchor();
                            }

                            target: musicPill
                        }

                        Connections {
                            function onXChanged() {
                                musicPopup.anchor.updateAnchor();
                            }

                            function onYChanged() {
                                musicPopup.anchor.updateAnchor();
                            }

                            target: musicPill.parent
                        }

                        ClippingRectangle {
                            id: musicCard

                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: musicPopup.lerp(musicPill.width, musicPopup.width)
                            height: musicPopup.lerp(musicPill.height, musicPlayerCard.height)
                            // The pill's corners: rounder ones would let the pill's show under the card.
                            radius: musicPill.radius
                            color: "transparent"

                            // Same card as the pill it grows from: base at 0.9,
                            // blurred by the hyprpunk-bar blur_popups layer rule, with the glass rim.
                            GlassSurface {
                                radius: musicCard.radius
                                tinted: false
                                backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.9)
                            }

                            MediaPlayerCard {
                                id: musicPlayerCard

                                active: bar.musicPopupVisible
                                anchors.top: parent.top
                                anchors.right: parent.right
                                width: musicPopup.width
                                opacity: Math.max(0, (musicPopup.progress - 0.7) / 0.3)
                                player: bar.spotifyPlayer
                                glassVisible: false
                                coverVisible: false
                                onSkipRequested: (direction) => {
                                    musicPill.skipHint = direction;
                                    if (direction < 0)
                                        restartProbeDelay.restart();

                                }
                            }

                            // From the pill's cover (32px circle, 3px inset) to the player's artwork.
                            // Nothing turns: the pill's disc grows at its frozen angle, and the upright
                            // square cover fades in over it (and out again while folding back).
                            Item {
                                readonly property real size: musicPopup.lerp(32, musicPlayerCard.artSize)
                                readonly property real squareOpacity: Math.min(1, Math.max(0, (musicPopup.coverProgress - 0.4) / 0.5))

                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.topMargin: musicPopup.lerp(3, musicPlayerCard.artMargin)
                                // Slides from the right edge to the left one of the growing card, so it is never cut.
                                anchors.leftMargin: (1 - musicPopup.coverProgress) * (musicCard.width - 3 - size) + musicPopup.coverProgress * musicPlayerCard.artMargin
                                width: size
                                height: size

                                CoverDisc {
                                    anchors.fill: parent
                                    visible: parent.squareOpacity < 1
                                    rotation: musicPopup.discAngle
                                    antialiasing: true
                                    // Same art as the pill's disc, so both match when it folds back.
                                    source: bar.spotifyPlayer !== null ? musicPill.pillArt() : ""
                                    decodeSize: 64
                                }

                                ClippingRectangle {
                                    anchors.fill: parent
                                    opacity: parent.squareOpacity
                                    visible: opacity > 0
                                    radius: musicPlayerCard.artRadius
                                    color: bar.surface1

                                    Image {
                                        id: musicPopupCover

                                        anchors.fill: parent
                                        source: bar.spotifyPlayer !== null ? bar.spotifyPlayer.trackArtUrl : ""
                                        asynchronous: true
                                        cache: true
                                        fillMode: Image.PreserveAspectCrop
                                        // Its size changes while the player opens: smooth downscaling at any size.
                                        mipmap: true
                                        visible: status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: musicPopupCover.status !== Image.Ready
                                        text: "󰎆"
                                        color: bar.mauve
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: musicPopup.lerp(16, 24)
                                    }

                                }

                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered) {
                                        musicCloseDelay.stop();
                                        musicHideDelay.stop();
                                        bar.musicVisible = true;
                                    } else {
                                        musicCloseDelay.restart();
                                    }
                                }
                            }

                        }

                        mask: Region {
                            item: musicCard
                        }

                    }

                }

            }

            // Opens the control center, which grows out of it.
            Pill {
                id: controlPill

                function publishGeometry() {
                    const origin = mapToItem(null, 0, 0);
                    bar.shellState.controlPill = {
                        "right": bar.width - origin.x - width,
                        "top": origin.y,
                        "width": width,
                        "height": height
                    };
                }

                onXChanged: publishGeometry()
                onYChanged: publishGeometry()
                onWidthChanged: publishGeometry()
                onHeightChanged: publishGeometry()
                Component.onCompleted: publishGeometry()
                onHoveredChanged: {
                    bar.shellState.controlPillScreen = bar.screen;
                    bar.shellState.controlPillHovered = hovered;
                }

                // Spinner in place of the icon while NetworkManager connects (VPN included).
                Item {
                    implicitWidth: bar.networkConnecting ? 16 : networkLabel.implicitWidth
                    implicitHeight: networkLabel.implicitHeight

                    Label {
                        id: networkLabel

                        visible: !bar.networkConnecting
                        text: bar.networkIcon()
                    }

                    Shape {
                        id: networkSpinner

                        property real sweep: 90

                        visible: bar.networkConnecting
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.25)
                            strokeWidth: 2

                            PathAngleArc {
                                centerX: networkSpinner.width / 2
                                centerY: networkSpinner.height / 2
                                radiusX: networkSpinner.width / 2 - 1
                                radiusY: networkSpinner.height / 2 - 1
                                startAngle: 0
                                sweepAngle: 360
                            }

                        }

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: "#cba6f7"
                            strokeWidth: 2
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: networkSpinner.width / 2
                                centerY: networkSpinner.height / 2
                                radiusX: networkSpinner.width / 2 - 1
                                radiusY: networkSpinner.height / 2 - 1
                                startAngle: -90
                                sweepAngle: networkSpinner.sweep
                            }

                        }

                        RotationAnimator on rotation {
                            running: networkSpinner.visible
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }

                        // The arc stretches and shrinks as it turns.
                        SequentialAnimation on sweep {
                            running: networkSpinner.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 270
                                duration: 700
                                easing.type: Easing.InOutCubic
                            }

                            NumberAnimation {
                                to: 40
                                duration: 700
                                easing.type: Easing.InOutCubic
                            }

                        }

                    }

                    // No locked Ethernet glyph in Material Design: a padlock badge instead.
                    Rectangle {
                        visible: bar.wiredLocked && !bar.networkConnecting
                        anchors.right: networkLabel.right
                        anchors.bottom: networkLabel.bottom
                        anchors.rightMargin: -4
                        anchors.bottomMargin: 1
                        width: 11
                        height: 11
                        radius: width / 2
                        color: controlPill.color

                        Label {
                            anchors.centerIn: parent
                            text: "󰌾"
                            font.pixelSize: 9
                        }

                    }

                }

                // Caffeine on: the computer stays awake.
                Label {
                    visible: bar.shellState.caffeine
                    text: "󰅶"
                }

                IconText {
                    visible: bar.audioSink !== null
                    icon: bar.volumeIcon()
                    text: bar.audioVolume + "%"
                }

                IconText {
                    id: batteryPill

                    visible: bar.hasBattery
                    // Red only while it runs out: charging, a low level is fine.
                    color: UPower.onBattery && bar.batteryPercent <= 20 ? bar.red : bar.mauve
                    icon: bar.batteryIcon()
                    text: bar.batteryPercent + "%"

                    // Pulses from 10 %.
                    SequentialAnimation on opacity {
                        running: bar.hasBattery && UPower.onBattery && bar.batteryPercent <= 10
                        loops: Animation.Infinite
                        onRunningChanged: {
                            if (!running)
                                batteryPill.opacity = 1;

                        }

                        NumberAnimation {
                            to: 0.4
                            duration: 900
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 900
                            easing.type: Easing.InOutSine
                        }

                    }

                }

            }

        }

    }

    Process {
        id: resourceProcess

        command: ["sh", "-c", "free -m | awk '/^Mem:/ {printf \"%.1fG\\n\", $3/1024}'; sensors 2>/dev/null | awk '/Package id 0:/ {gsub(/[+°C]/, \"\", $4); printf \"%.0f°C\\n\", $4; found=1; exit} /^Tctl:/ {gsub(/[+°C]/, \"\", $2); printf \"%.0f°C\\n\", $2; found=1; exit} /^Tdie:/ {gsub(/[+°C]/, \"\", $2); printf \"%.0f°C\\n\", $2; found=1; exit} END {if (!found) print \"--°C\"}'; awk '/cpu MHz/ {sum += $4; count++} END {printf \"%.0f MHz\\n\", count ? sum/count : 0}' /proc/cpuinfo; awk -F': ' '/^model name/ {print $2; exit}' /proc/cpuinfo; head -n1 /proc/stat"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length > 0 && lines[0] !== "")
                    bar.memoryText = lines[0];

                if (lines.length > 1)
                    bar.cpuTemperature = lines[1];

                if (lines.length > 3) {
                    bar.cpuFrequency = lines[2];
                    bar.cpuModel = lines[3];
                }
                const stat = lines.find((line) => {
                    return line.startsWith("cpu ");
                });
                if (stat !== undefined) {
                    const jiffies = stat.trim().split(/\s+/).slice(1).map(Number);
                    const idle = jiffies[3] + (jiffies[4] || 0);
                    const total = jiffies.slice(0, 8).reduce((sum, value) => {
                        return sum + (value || 0);
                    }, 0);
                    if (bar.cpuStat[1] > 0 && total > bar.cpuStat[1])
                        bar.cpuUsage = Math.round(100 * (1 - (idle - bar.cpuStat[0]) / (total - bar.cpuStat[1])));

                    bar.cpuStat = [idle, total];
                }
            }
        }

    }

    Process {
        id: vpnProcess

        // NAME last: it is the only field that can hold an (escaped) colon.
        command: ["nmcli", "-t", "-f", "TYPE,STATE,NAME", "connection", "show", "--active"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const connections = [];
                for (const line of text.trim().split("\n")) {
                    const fields = line.split(":");
                    if (fields.length >= 3 && (fields[0] === "vpn" || fields[0] === "wireguard"))
                        connections.push({
                        "state": fields[1],
                        "name": fields.slice(2).join(":").replace(/\\:/g, ":")
                    });

                }
                bar.vpnConnections = connections;
            }
        }

    }

    // Any NetworkManager change refreshes the VPN list, coalesced.
    Process {
        command: ["nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: vpnRefresh.restart()
        }

    }

    Timer {
        id: vpnRefresh

        interval: 250
        onTriggered: vpnProcess.running = true
    }

    Process {
        id: updateProcess

        // Official repos and AUR, counted together.
        command: ["sh", "-c", "{ checkupdates; yay -Qua; } 2>/dev/null | wc -l"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                bar.updateCount = isNaN(count) ? 0 : count;
            }
        }

    }

    Process {
        id: upgradeProcess

        command: ["kitty", "-e", "yay", "-Syu", "--noconfirm", "--removemake"]
        // The current locale, not the one the shell was started with.
        environment: Session.localeEnvironment
        onExited: updateProcess.running = true
    }

    // The time recorded, for the island.
    Timer {
        interval: 1000
        running: bar.shellState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.recordingElapsed = Math.max(0, Math.round((Date.now() - bar.shellState.recordingStarted) / 1000))
    }

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updateProcess.running = true
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: resourceProcess.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: updateProcess.running = true
    }

    Process {
        id: lockStateProcess

        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | jq -r '([.keyboards[]?.capsLock] | any), ([.keyboards[]?.numLock] | any)'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2)
                    return ;

                const newCapsLock = lines[0] === "true";
                const newNumLock = lines[1] === "true";
                if (bar.lockStateInitialized) {
                    if (newCapsLock !== bar.capsLockEnabled)
                        bar.showStatusOsd("󰪛", "Caps Lock", newCapsLock);

                    if (newNumLock !== bar.numLockEnabled)
                        bar.showStatusOsd("󰎤", "Num Lock", newNumLock);

                }
                bar.capsLockEnabled = newCapsLock;
                bar.numLockEnabled = newNumLock;
                bar.lockStateInitialized = true;
            }
        }

    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (!lockStateProcess.running)
                lockStateProcess.running = true;

        }
    }

    FileView {
        id: touchpadStateFile

        function updateTouchpadState() {
            const match = touchpadStateFile.text().match(/(?:^|\n)enabled=(true|false)(?:\n|$)/);
            if (match === null)
                return ;

            const enabled = match[1] === "true";
            if (bar.touchpadStateInitialized && enabled !== bar.touchpadEnabled)
                bar.showStatusOsd("󰟸", "Touchpad", enabled);

            bar.touchpadEnabled = enabled;
            bar.touchpadStateInitialized = true;
        }

        path: bar.stateHome + "/hyprpunk/touchpad-state.conf"
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: updateTouchpadState()
        onTextChanged: updateTouchpadState()
        onFileChanged: reload()
    }

    Connections {
        function onAirPodsOsdRequestsChanged() {
            const osd = bar.shellState.airPodsOsd;
            if (osd.screen === bar.screen.name)
                bar.showAirPodsOsd(osd);

        }

        target: bar.shellState
    }

    PwObjectTracker {
        objects: bar.micSource !== null ? [bar.micSource] : []
    }

    PwObjectTracker {
        objects: bar.audioSink !== null ? [bar.audioSink] : []
    }

    Timer {
        id: volumeInitDelay

        interval: 600
        running: true
        onTriggered: bar.volumeInitialized = true
    }

    Process {
        id: brightnessProcess

        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return ;

                const newBrightness = parseInt(fields[3]);
                const changed = bar.brightnessInitialized && newBrightness !== bar.screenBrightness;
                // Changes announced by hypridle are not shown (only the next one).
                const muted = changed && Date.now() < bar.shellState.screenOsdMutedUntil;
                if (muted)
                    bar.shellState.screenOsdMutedUntil = 0;

                bar.screenBrightness = newBrightness;
                if (changed && !muted)
                    bar.showStatusOsd(bar.brightnessIcon(), "Brightness", newBrightness > 0, newBrightness, 100);

                bar.brightnessInitialized = true;
            }
        }

    }

    Process {
        command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
        running: true

        stdout: SplitParser {
            onRead: brightnessProcess.running = true
        }

    }

    Timer {
        id: micInitDelay

        interval: 500
        running: true
        onTriggered: bar.micStateInitialized = true
    }

    Process {
        command: ["sh", "-c", "ls -d /sys/class/leds/*::kbd_backlight 2>/dev/null | head -n 1"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: bar.keyboardBacklightPath = text.trim()
        }

    }

    // The ASUS driver changes the keyboard backlight itself on Fn keys and
    // sysfs sends no inotify event for it, so the value is polled.
    FileView {
        id: keyboardBacklightFile

        function updateKeyboardBacklight() {
            const level = parseInt(keyboardBacklightFile.text());
            if (isNaN(level) || level === bar.keyboardBacklight)
                return ;

            const max = parseInt(keyboardBacklightMaxFile.text()) || 3;
            // Changes announced by hypridle are not shown (only the next one).
            const muted = Date.now() < bar.shellState.keyboardOsdMutedUntil;
            if (muted)
                bar.shellState.keyboardOsdMutedUntil = 0;

            if (bar.keyboardBacklight >= 0 && !muted)
                bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);

            bar.keyboardBacklight = level;
        }

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/brightness" : ""
        printErrors: false
        onLoaded: updateKeyboardBacklight()
    }

    // Only updated by the driver, i.e. on Fn key presses, never by brightnessctl
    // (hypridle): such changes always get the OSD.
    FileView {
        id: keyboardBacklightHwFile

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/brightness_hw_changed" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const level = parseInt(text());
            const max = parseInt(keyboardBacklightMaxFile.text()) || 3;
            if (bar.keyboardHwInitialized && !isNaN(level))
                bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);

            // The first load only reads the last value, it is not a key press.
            bar.keyboardHwInitialized = true;
        }
        // Unreadable until the first Fn key press since boot.
        onLoadFailed: bar.keyboardHwInitialized = true
    }

    FileView {
        id: keyboardBacklightMaxFile

        path: bar.keyboardBacklightPath !== "" ? bar.keyboardBacklightPath + "/max_brightness" : ""
        printErrors: false
    }

    Timer {
        interval: 250
        running: bar.keyboardBacklightPath !== ""
        repeat: true
        onTriggered: keyboardBacklightFile.reload()
    }

    Behavior on musicProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    FileView {
        path: Session.stateDir + "/wallpaper.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/^wallpaper=(.*)$/m);
            bar.wallpaperPath = match ? match[1] : "";
        }
    }

    Behavior on workspaceProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on monitorProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }

    }

    Behavior on clockCenterOffset {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }

    }

    // The battery's alerts, from UPower's changes (no polling).
    Connections {
        function onPercentageChanged() {
            bar.updateBatteryAlert();
        }

        target: bar.battery
        // Already low when the shell starts.
        Component.onCompleted: Qt.callLater(bar.updateBatteryAlert)
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: bar.powerEventsReady = true
    }

    // The time left as soon as it is known, then the usual moment to read it.
    Connections {
        function onBatteryEstimatingChanged() {
            if (!bar.batteryEstimating && bar.statusOsdVisible && bar.statusOsdLabel === "On battery") {
                statusOsdHideDelay.interval = 2500;
                statusOsdHideDelay.restart();
            }
        }

        target: bar
    }

    // UPower waits for a few readings: the draw is read every second meanwhile.
    Timer {
        running: bar.batteryEstimating
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryDrawProcess.running = true
    }

    Process {
        id: batteryDrawProcess

        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/energy_now /sys/class/power_supply/BAT*/power_now"]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split("\n").map(Number);
                // µWh and µW: hours left, in seconds.
                if (values.length >= 2 && values[0] > 0 && values[1] > 0)
                    bar.batteryDrawEstimate = values[0] / values[1] * 3600;

            }
        }

    }

    Connections {
        function onOnBatteryChanged() {
            bar.powerSourceChanged();
        }

        target: UPower
    }

    Connections {
        function onScreenshotTakenChanged() {
            const taken = bar.shellState.screenshotTaken;
            if (taken !== null && taken.screen === bar.screen.name)
                bar.showScreenshotOsd(taken);

        }

        target: bar.shellState
    }

    // Caffeine: the bar is always shown, so its inhibitor holds hypridle off.
    IdleInhibitor {
        window: bar
        enabled: bar.shellState.caffeine
    }

}
