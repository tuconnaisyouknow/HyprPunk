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

// The bar along the top of each screen, a row of pills.
// On the left, the workspaces (hover for a preview) and the resources (hover for a
// little btop). In the middle, the dynamic island: clock, calendar, OSDs, and the
// panels that grow out of it. On the right, the pending updates when there are some
// (click to install), the Spotify record (hover for the player), and the control
// pill (hover for the control center).
PanelWindow {
    id: bar

    required property var shellState
    readonly property var workspaceIcons: ["", "", "", "", "", "", "", "", "", "", ""]
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isLaptopBattery && battery.isPresent
    // Which of your other workspaces the preview card opens on.
    property var previewWorkspace: null
    readonly property var previewWorkspaces: workspaceSwitcher.workspaces.filter((workspace) => {
        return !workspace.focused;
    }).sort((a, b) => {
        return a.id - b.id;
    })
    // A snapshot of the bar for the previews (keeping grabToImage's result keeps it alive).
    property var barSnapshot: null
    readonly property int workspacePreviewWidth: 400
    // The screen's shape, 16:9 until Hyprland has told which monitor the bar is on.
    readonly property int workspacePreviewHeight: {
        const monitor = Hyprland.monitorFor(bar.screen);
        return Math.round(workspacePreviewWidth * (monitor !== null && monitor.width > 0 ? monitor.height / monitor.width : 9 / 16));
    }
    // Only Spotify: browsers and other MPRIS players are ignored.
    readonly property var spotifyPlayer: {
        for (const player of Mpris.players.values) {
            if (player.dbusName === "org.mpris.MediaPlayer2.spotify")
                return player;

        }
        return null;
    }
    property bool statusOsdVisible: false
    // While the session is locked, the lock's island shows the OSD and the bar's own one
    // stays still. It isn't drawn under the lock, so it would only catch up on its
    // animations once the lock is gone.
    property bool sessionLocked: false
    readonly property bool islandOsdShown: statusOsdVisible && !sessionLocked
    property string statusOsdIcon: ""
    property string statusOsdLabel: ""
    property bool statusOsdEnabled: false
    // "airpods": a pod and its battery ring instead of an icon, label and gauge.
    // "battery": the battery's alert, its icon, a title and the time left.
    // "screenshot": a thumbnail of what was just captured (for a recording, its first
    // frame), titled statusOsdTitle; a click opens statusOsdFile.
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
    // The lowest warning level (20, 10 or 5 %) crossed since the last time it was plugged
    // in, 0 above them. Each warning shows once; the critical one stays up.
    property int batteryAlertStage: 0
    readonly property bool batteryCritical: hasBattery && UPower.onBattery && batteryAlertStage === 5
    // Off while the shell starts: UPower's first values aren't a plug or unplug.
    property bool powerEventsReady: false
    // Time left worked out from the battery's own draw, for the first seconds after
    // unplugging when UPower has no estimate yet. 0 when there's none.
    property real batteryDrawEstimate: 0
    readonly property real batteryTimeLeft: battery.timeToEmpty > 0 ? battery.timeToEmpty : batteryDrawEstimate
    readonly property bool batteryEstimating: statusOsdVisible && statusOsdKind === "battery" && statusOsdLabel === "On battery" && batteryTimeLeft <= 0
    readonly property var micSource: Pipewire.defaultAudioSource
    readonly property bool micMuted: micSource !== null && micSource.audio !== null && micSource.audio.muted
    property bool micStateInitialized: false
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVolume: audioSink !== null && audioSink.audio !== null ? Math.round(audioSink.audio.volume * 100) : 0
    readonly property bool audioMuted: audioSink !== null && audioSink.audio !== null && audioSink.audio.muted
    property bool volumeInitialized: false
    // The output whose volume changes we show, updated whenever the output changes.
    property var volumeSink: audioSink
    property real clockCenterOffset: bar.islandOsdShown ? 3 : -3
    // The regional formats you picked (locale-profilectl.sh). The calendar's day names
    // and first day of the week follow them, even though the shell keeps its startup locale.
    readonly property var regionalLocale: Qt.locale(Session.regionalProfile === "us" ? "en_US" : "fr_FR")

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
    readonly property bool networkConnecting: (networkDevice !== null && !networkDevice.connected) || Vpn.connecting
    readonly property bool wiredLocked: networkDevice !== null && networkDevice.connected && networkDevice.type === DeviceType.Wired && Vpn.connection !== null

    // Where each pill sits on screen, so the lock screen can start from there: the ones it
    // keeps (resources, island, control pill) and the ones it lets go.
    function lockGeometry() {
        const rect = (item) => {
            const origin = item.mapToItem(null, 0, 0);
            return {
                "x": origin.x,
                "y": origin.y,
                "width": item.width,
                "height": item.height,
                "radius": item.radius !== undefined ? item.radius : item.height / 2
            };
        };
        const others = [];
        for (const group of [leftGroup, centerGroup, rightGroup]) {
            for (const child of group.children) {
                if (child === monitorPill || child === clockPill || child === controlPill || !child.visible || child.width <= 0)
                    continue;

                // A drop-in slot: the pill inside it.
                others.push(rect(child.pill !== undefined && child.pill !== null ? child.pill : child));
            }
        }
        return {
            "monitor": monitorPill.visible ? rect(monitorPill) : null,
            "island": rect(clockPill),
            "control": rect(controlPill),
            "others": others
        };
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

        const network = bar.activeWifiNetwork(device);
        return Icons.wifi(network !== null ? network.signalStrength : 0, device.connected && Vpn.connection !== null);
    }

    function capitalized(text) {
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    // With maxLevel > 0, a gauge of level / maxLevel replaces the On/Off badge.
    function showStatusOsd(icon, label, enabled, level, maxLevel) {
        calendarPopup.dismiss();
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
        calendarPopup.dismiss();
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
        calendarPopup.dismiss();
        statusOsdKind = "screenshot";
        statusOsdImage = taken.file;
        statusOsdFile = taken.video || taken.file;
        statusOsdTitle = taken.video ? "Recording" : "Screenshot";
        statusOsdLabel = taken.video ? formatDuration(taken.duration) + " · Saved" : taken.annotated ? "Annotated · Saved" : "Copied · Saved";
        statusOsdHideDelay.interval = 3500;
        statusOsdVisible = true;
        statusOsdHideDelay.restart();
    }

    // Plugging in or unplugging shows in the island, unless unplugging brings up a
    // low-battery warning instead.
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
        calendarPopup.dismiss();
        statusOsdKind = "battery";
        statusOsdLabel = title;
        batteryDrawEstimate = 0;
        // Unplugged: stays until the time left is known, then a moment to read it.
        statusOsdHideDelay.interval = title === "On battery" && batteryTimeLeft <= 0 ? 8000 : title === "Charging" || title === "On battery" ? 2500 : 6000;
        statusOsdVisible = true;
        // The critical alert stays until the computer is plugged in.
        if (batteryCritical)
            statusOsdHideDelay.stop();
        else
            statusOsdHideDelay.restart();
    }

    // Ends the OSD now, as its delay would. Another OSD over the critical battery alert
    // goes back to the alert, which stays until the computer is plugged in.
    function endStatusOsd() {
        statusOsdHideDelay.stop();
        if (batteryCritical)
            showBatteryOsd("Battery critical");
        else
            statusOsdVisible = false;
    }

    // Green while charging, mauve on battery, red for the alerts.
    function batteryOsdColor() {
        if (statusOsdLabel === "Charging")
            return Theme.green;

        return statusOsdLabel === "On battery" ? Theme.mauve : Theme.red;
    }

    // "64% · 1 h 05 until full" while charging, "64% · 3 h 10 left" on battery,
    // just the percentage until UPower has an estimate.
    function batteryDetail() {
        const seconds = UPower.onBattery ? batteryTimeLeft : battery.timeToFull;
        if (!(seconds > 0))
            return batteryPercent + (batteryEstimating ? "% · Estimating…" : UPower.onBattery ? "%" : "% · Plugged in");

        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        const duration = hours > 0 ? hours + " h " + String(minutes).padStart(2, "0") : minutes + " min";
        return batteryPercent + "% · " + duration + (UPower.onBattery ? " left" : " until full");
    }

    function showVolumeOsd() {
        // Checked here too: the volume can change (dropping to 0 as an output goes away)
        // before the output itself does.
        if (audioSink !== volumeSink) {
            resetVolumeOsd();
            return ;
        }
        if (volumeInitialized && audioSink !== null && audioSink.ready && audioSink.audio !== null)
            // Muted, the gauge keeps its level and turns lavender.
            showStatusOsd(Icons.volume(audioVolume, audioMuted), audioMuted ? "Muted" : "Volume", !audioMuted, audioVolume, 100);

    }

    // Switching output (AirPods coming or going) brings its own volume, that's not a change.
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
    // Deferred: while the bar is being built, the pill's animations don't exist yet.
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
    // Named so Hyprland's layer rule can blur the player popup too.
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
                    if (!hovered)
                        workspacePopup.hoverEnded();

                }

                WorkspaceSwitcher {
                    id: workspaceSwitcher

                    screen: bar.screen
                    icons: bar.workspaceIcons
                    // Waits like the other pills. No need to preview the workspace you're on.
                    onHoveredWorkspaceChanged: {
                        if (hoveredWorkspace !== null && !hoveredWorkspace.focused && !workspacePopup.mapped)
                            workspacePopup.hoverStarted();
                        else
                            workspacePopup.cancelOpen();
                    }
                }

                PillPopup {
                    id: workspacePopup

                    pill: workspacePill
                    openable: workspaceSwitcher.hoveredWorkspace !== null
                    // The preview inside the control center's padding.
                    implicitWidth: bar.workspacePreviewWidth + 28
                    implicitHeight: bar.workspacePreviewHeight + 28
                    // Ask Hyprland where the windows are (it only says when asked), and
                    // snapshot the bar to lay over every preview.
                    onOpening: {
                        Hyprland.refreshToplevels();
                        barContent.grabToImage((result) => {
                            bar.barSnapshot = result;
                        });
                        bar.previewWorkspace = workspaceSwitcher.hoveredWorkspace;
                    }

                    // Rebuilt on every opening, so the windows are captured fresh.
                    Loader {
                        x: 14
                        y: 14
                        width: bar.workspacePreviewWidth
                        height: bar.workspacePreviewHeight
                        active: workspacePopup.mapped
                        opacity: workspacePopup.expanded ? 1 : 0

                        sourceComponent: WorkspacePreviewCard {
                            workspaces: bar.previewWorkspaces
                            initialWorkspace: bar.previewWorkspace
                            monitor: workspaceSwitcher.hyprlandMonitor
                            wallpaper: Session.wallpaper
                            barImage: bar.barSnapshot !== null ? bar.barSnapshot.url : ""
                            barRect: Qt.rect(barContent.x, barContent.y, barContent.width, barContent.height)
                            onWorkspaceChosen: (workspace) => {
                                workspace.activate();
                                workspacePopup.close();
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            // Opens the system monitor on hover, which grows out of it like the player.
            Pill {
                id: monitorPill

                visible: bar.width >= 1200
                onHoveredChanged: {
                    if (hovered)
                        monitorPopup.hoverStarted();
                    else
                        monitorPopup.hoverEnded();
                }

                IconText {
                    icon: ""
                    text: SystemStats.memoryText
                }

                IconText {
                    icon: ""
                    text: Math.round(SystemStats.cpuUsage * 100) + "%"
                }

                PillPopup {
                    id: monitorPopup

                    pill: monitorPill
                    implicitWidth: monitorContent.implicitWidth
                    implicitHeight: monitorContent.implicitHeight

                    SystemMonitorCard {
                        id: monitorContent

                        width: monitorPopup.width
                        opacity: monitorPopup.expanded ? 1 : 0
                        active: monitorPopup.mapped

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

        }

        // When the calendar covers the island, the privacy and recording dots move to its
        // right, following its edge as it grows.
        PrivacyDot {
            x: Math.round(centerGroup.x + clockPill.x + clockPill.width / 2 + calendarPopup.card.width / 2 + 8)
            y: Math.round(centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2)
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active ? calendarPopup.progress : 0
            visible: calendarPopup.mapped && opacity > 0
        }

        // Same when the island is busy with an OSD: they sit to its right.
        PrivacyDot {
            x: Math.round(centerGroup.x + clockPill.x + clockPill.width + 8)
            y: Math.round(centerGroup.y + clockPill.y + clockPill.height / 2 - height / 2)
            camera: bar.shellState.cameraInUse
            microphone: bar.shellState.microphoneInUse
            recording: bar.shellState.recording
            opacity: active && bar.islandOsdShown && !calendarPopup.mapped ? 1 : 0
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
                horizontalPadding: bar.islandOsdShown ? 36 : 20
                implicitHeight: bar.islandOsdShown ? 50 : 38
                // Grows two pixels at a time, so centring it on the bar and its content in it
                // never lands on a half pixel and the content stops shaking as it resizes.
                Layout.preferredWidth: 2 * Math.round(implicitWidth / 2)
                Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)
                contentOpacity: 1

                Label {
                    id: dateTimeLabel

                    visible: !bar.islandOsdShown
                    text: Qt.formatDateTime(clock.date, "HH:mm")

                    HoverHandler {
                        onHoveredChanged: {
                            if (hovered)
                                calendarPopup.hoverStarted();
                            else
                                calendarPopup.hoverEnded();
                        }
                    }

                    SystemClock {
                        id: clock

                        precision: SystemClock.Minutes
                    }

                }

                // Privacy: a dot after the time while something is listening or watching,
                // green for the camera, orange for the microphone alone.
                Item {
                    readonly property bool shown: !bar.islandOsdShown && (bar.shellState.cameraInUse || bar.shellState.microphoneInUse)

                    // Gone at once when an OSD takes the island, or its shrinking would pull
                    // the OSD sideways while it grows.
                    visible: !bar.islandOsdShown && Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? 8 : 0
                    Layout.leftMargin: shown ? -2 : -clockPill.spacing
                    implicitHeight: 8

                    Rectangle {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        radius: 4
                        scale: parent.shown ? 1 : 0
                        color: bar.shellState.cameraInUse ? Theme.green : Theme.peach

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

                // Recording: a pulsing red dot and how long it's been going, after the time.
                // Click to stop.
                Item {
                    id: recordingChip

                    readonly property bool shown: !bar.islandOsdShown && bar.shellState.recording

                    // Gone at once when an OSD takes the island, like the privacy dot.
                    visible: !bar.islandOsdShown && Layout.preferredWidth > 0
                    Layout.preferredWidth: shown ? recordingRow.implicitWidth + 16 : 0
                    Layout.leftMargin: shown ? 0 : -clockPill.spacing
                    implicitHeight: 24
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: recordingHover.hovered ? Theme.alpha(Theme.red, 0.28) : Theme.alpha(Theme.red, 0.16)

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
                            color: Theme.red

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
                            color: Theme.red
                            font.family: Theme.font
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

                IslandOsd {
                    bar: bar
                    visible: bar.islandOsdShown
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

                // The pill is ~90% open by then, so its edges don't clip the content.
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
                onTriggered: bar.endStatusOsd()
            }

            PillPopup {
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
                // Card height for the displayed month, measured from the real layout, and
                // eased when the next month has a week more or less.
                readonly property real contentHeight: calendarBody.y + calendarBody.implicitHeight + 18
                property real animatedHeight: contentHeight
                property int pendingMonthDelta: 0

                function changeMonth(delta) {
                    if (monthTransition.running)
                        return ;

                    pendingMonthDelta = delta;
                    monthTransition.start();
                }

                pill: clockPill
                align: Qt.AlignHCenter
                closeDelay: 180
                cardHeight: animatedHeight
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Bottom
                implicitWidth: 322
                // Sized for a six-week month so the card can animate without clipping. Not taken
                // from weekRows: the layout updates a frame late, and the popup would resize twice
                // (everything shakes).
                implicitHeight: calendarBody.y + calendarMonthLabel.implicitHeight + calendarBody.spacing + calendarGrid.sixWeekHeight + 18
                onOpening: monthOffset = 0

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
                    color: Theme.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

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
                    color: Theme.lavender
                    font.pixelSize: 15
                    opacity: calendarPopup.expanded ? 1 : 0

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
                    color: Theme.surface1
                    opacity: calendarPopup.expanded ? 1 : 0

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
                    opacity: (calendarPopup.expanded ? 1 : 0) * monthTransitionOpacity

                    Label {
                        id: calendarMonthLabel

                        Layout.alignment: Qt.AlignHCenter
                        text: bar.capitalized(bar.regionalLocale.standaloneMonthName(calendarPopup.displayedMonthNumber)) + " " + calendarPopup.displayedYear
                        color: Theme.mauve
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
                                color: Theme.mauve
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
                                color: isToday ? Theme.mauve : "transparent"

                                Label {
                                    anchors.centerIn: parent
                                    text: parent.validDay ? parent.dayNumber : ""
                                    color: parent.isToday ? Theme.base : Theme.mauve
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

                Behavior on animatedHeight {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        RowLayout {
            id: rightGroup

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -(bar.implicitHeight - 50) / 2
            spacing: 9
            // When the control pill changes width, it reports its place before the row has
            // settled against the right edge, so report again once it has.
            onXChanged: controlPill.publishGeometry()
            onYChanged: controlPill.publishGeometry()

            DropInSlot {
                shown: Updates.count > 0

                Pill {
                    IconText {
                        icon: ""

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Updates.upgrade()
                        }

                        // Keeps the last count while the pill flies away.
                        Binding on text {
                            when: Updates.count > 0
                            value: String(Updates.count)
                            restoreMode: Binding.RestoreNone
                        }

                    }

                }

            }

            // The Spotify track's cover as a spinning record. Hover it to open the player.
            DropInSlot {
                shown: bar.spotifyPlayer !== null

                Rectangle {
                    id: musicPill

                    // Angle of the front disc: 0 = upright, where every track starts.
                    property real spin: 0
                    // 0 -> 1 after a new track or a restart: the disc only starts spinning
                    // once it has settled upright.
                    property real spinFactor: 1
                    // While the player is open, the disc pauses and picks up from the same angle
                    // afterwards, without jumping.
                    readonly property bool displayFrozen: musicPopup.mapped
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

                    // A little pop on play, pause and track changes. Not while the player is
                    // open though: the pill sits under the card and would poke out of it.
                    function pulse() {
                        if (displayFrozen)
                            return ;

                        pulseAnimation.restart();
                    }

                    // Spotify's 64px cover rather than the 640px one: shown at 34px anyway, and much quicker to load.
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

                    // "Previous" a few seconds in restarts the track instead of changing it:
                    // the position jumps back to 0 on the same track.
                    function checkRestart(position) {
                        const current = position ?? bar.spotifyPlayer.position;
                        const expected = knownPosition + (knownPositionPlaying ? (Date.now() - knownPositionTime) / 1000 : 0);
                        // A position jump right after a track change isn't a restart (it used to give the
                        // new disc an extra spin), and "previous" that early changes track anyway.
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

                        // No hint (media keys, the phone…): going back to the previous track
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
                        } else {
                            // A pulse still running would grow out from under the cover.
                            pulseAnimation.stop();
                            scale = 1;
                        }
                    }
                    Component.onCompleted: Qt.callLater(resetDiscs)
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: 19
                    // The pill's background is painted by the hole and the ring below; a fill here
                    // would show twice under the ring.
                    color: "transparent"

                    // Shows while a disc rolls in or out of the hole.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: width / 2
                        color: Theme.panel
                    }

                    Behavior on spinSpeed {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.InOutQuad
                        }

                    }

                    // Two discs, so on a track change the old one can roll out while the new one
                    // rolls in, forwards or backwards.
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

                    // The pill around the hole. The masks leave a jagged edge (worse while spinning),
                    // so the ring covers it; the hole stays 32px wide.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: 3
                        border.color: Theme.panel
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

                    // Spotify doesn't always announce a restart (no Seeked signal), so after
                    // "previous" we ask for the position directly.
                    Timer {
                        id: restartProbeDelay

                        interval: 350
                        onTriggered: restartProbe.running = true
                    }

                    Process {
                        id: restartProbe

                        // Position in microseconds, plus the track it belongs to, so a track change
                        // that hasn't been announced yet doesn't look like a restart.
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
                            // The cover sometimes arrives after the track change, and sometimes just before,
                            // while the old disc is still in front (changeTrack handles that case).
                            if (musicPill.trackId() === musicPill.currentTrackId)
                                musicPill.frontDisc().source = musicPill.pillArt();

                        }

                        target: bar.spotifyPlayer
                    }

                    HoverHandler {
                        onHoveredChanged: hovered ? musicPopup.hoverStarted() : musicPopup.hoverEnded()
                    }

                    // Opens like the calendar: the card grows out of the cover pill and
                    // the cover glides to its place in the player.
                    PillPopup {
                        id: musicPopup

                        // The cover settles during the first 70% so it never crosses the fading-in title.
                        readonly property real coverProgress: Math.min(1, progress / 0.7)
                        // The disc's angle (-180..180): the cover leaves at that angle and straightens up
                        // as the player opens, then turns back to it when folding away.
                        readonly property real discAngle: ((musicPill.frontAngle % 360) + 540) % 360 - 180

                        pill: musicPill
                        align: Qt.AlignRight
                        available: bar.spotifyPlayer !== null
                        implicitWidth: 380
                        // Tall enough for the lyrics: the card grows and shrinks inside it.
                        implicitHeight: musicPlayerCard.fullHeight
                        cardHeight: musicPlayerCard.height
                        anchor.edges: Edges.Top | Edges.Right
                        anchor.gravity: Edges.Bottom | Edges.Left

                        MediaPlayerCard {
                            id: musicPlayerCard

                            active: musicPopup.mapped
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

                        // From the pill's little round cover to the player's artwork. Nothing spins: the disc
                        // grows at its frozen angle and the square cover fades in over it (and back out).
                        Item {
                            readonly property real size: musicPopup.lerp(32, musicPlayerCard.artSize)
                            readonly property real squareOpacity: Math.min(1, Math.max(0, (musicPopup.coverProgress - 0.4) / 0.5))

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.topMargin: musicPopup.lerp(3, musicPlayerCard.artMargin)
                            // Slides from the right edge to the left one of the growing card, so it is never cut.
                            anchors.leftMargin: (1 - musicPopup.coverProgress) * (musicPopup.card.width - 3 - size) + musicPopup.coverProgress * musicPlayerCard.artMargin
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
                                color: Theme.surface1

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
                                    color: Theme.mauve
                                    font.family: Theme.font
                                    font.pixelSize: musicPopup.lerp(16, 24)
                                }

                            }

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

                ControlStatus {
                    bar: bar
                    badgeColor: controlPill.baseColor
                }

            }

        }

    }

    // The time recorded, for the island.
    Timer {
        interval: 1000
        running: bar.shellState.recording
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.recordingElapsed = Math.max(0, Math.round((Date.now() - bar.shellState.recordingStarted) / 1000))
    }

    Connections {
        function onAirPodsOsdRequestsChanged() {
            const osd = bar.shellState.airPodsOsd;
            if (osd.screen === bar.screen.name)
                bar.showAirPodsOsd(osd);

        }

        target: bar.shellState
    }

    // The hardware's changes, in this screen's island too.
    Connections {
        function onCapsLockToggled(enabled) {
            bar.showStatusOsd("󰪛", "Caps Lock", enabled);
        }

        function onNumLockToggled(enabled) {
            bar.showStatusOsd("󰎤", "Num Lock", enabled);
        }

        function onTouchpadToggled(enabled) {
            bar.showStatusOsd("󰟸", "Touchpad", enabled);
        }

        function onBrightnessShown(percent) {
            bar.showStatusOsd(Icons.brightness(percent), "Brightness", percent > 0, percent, 100);
        }

        function onKeyboardBacklightShown(level, max) {
            bar.showStatusOsd("󰌌", "Keyboard light", level > 0, level, max);
        }

        target: Devices
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

    Timer {
        id: micInitDelay

        interval: 500
        running: true
        onTriggered: bar.micStateInitialized = true
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

    // UPower waits for a few readings first, so meanwhile the draw is read every second.
    Timer {
        running: bar.batteryEstimating
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryDrawProcess.running = true
    }

    Process {
        id: batteryDrawProcess

        // Each battery's energy and draw (µWh and µW). Batteries that only report charge
        // and current get multiplied by their voltage. The draw may be negative.
        command: ["sh", "-c", batteryDrawProcess.script]
        readonly property string script: 'for dir in /sys/class/power_supply/*; do
[ "$(cat "$dir/type" 2>/dev/null)" = Battery ] || continue
[ "$(cat "$dir/scope" 2>/dev/null)" = Device ] && continue
if [ -r "$dir/energy_now" ]; then echo "$(cat "$dir/energy_now") $(cat "$dir/power_now" 2>/dev/null || echo 0)"
elif [ -r "$dir/charge_now" ]; then volts=$(cat "$dir/voltage_now" 2>/dev/null || echo 0); echo "$(($(cat "$dir/charge_now") / 1000 * volts / 1000)) $(($(cat "$dir/current_now" 2>/dev/null || echo 0) / 1000 * volts / 1000))"
fi
done'

        stdout: StdioCollector {
            onStreamFinished: {
                let energy = 0;
                let draw = 0;
                for (const line of text.trim().split("\n")) {
                    const values = line.split(" ").map(Number);
                    if (values.length === 2 && !isNaN(values[0]) && !isNaN(values[1])) {
                        energy += values[0];
                        draw += Math.abs(values[1]);
                    }
                }
                // Hours left, in seconds.
                if (energy > 0 && draw > 0)
                    bar.batteryDrawEstimate = energy / draw * 3600;

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

    // Caffeine lives on the bar because the bar is always there, so it keeps hypridle at bay.
    IdleInhibitor {
        window: bar
        enabled: bar.shellState.caffeine
    }

}
