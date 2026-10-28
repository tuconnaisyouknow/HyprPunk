//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = qt6ct
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Where the shell starts. Holds the state the screens share (which panel is open
// where, screenshots, caffeine…), answers the `qs -c hyprpunk ipc call …` commands
// that the shortcuts and scripts send, and puts a bar, popups and panels on every screen.
ShellRoot {
    QtObject {
        id: globalState

        property bool notificationCenterOpen: false
        property var notificationScreen: null
        property bool controlCenterOpen: false
        // Ask for a panel on a screen. panel is one of "controlcenter", "notifications",
        // "session", "wallpaper", "sddm", "launcher", "clipboard", "emoji", "keybindings",
        // "config", "monitor", "screenshot" or "menu"; action is "toggle", "open" or "close";
        // screen is a screen's name, or empty for the focused one.
        property var panelRequest: ({
            "panel": "",
            "action": "",
            "screen": ""
        })
        property int panelRequests: 0
        // Where the dynamic island (the clock pill) is, for the panels growing out of it.
        // Screen coordinates; centerOffset is how far it sits from the screen's middle.
        property var islandPill: ({
            "centerOffset": 0,
            "top": 6,
            "width": 70,
            "height": 38
        })

        // origin: the panel making the request (the main menu for its entries).
        function requestPanel(panel, action, screen, origin) {
            panelRequest = {
                "panel": panel,
                "action": action,
                "screen": screen || "",
                "origin": origin || ""
            };
            panelRequests += 1;
        }
        // Where the control center ends (screen y), so the popups can sit below it.
        property real controlCenterBottom: 0
        property var controlCenterBottomScreen: null
        // Where the bar's right-most pill is, for the control center to grow out of it.
        // right and top are distances from the screen's edges.
        property var controlPill: ({
            "right": 24,
            "top": 6,
            "width": 120,
            "height": 38
        })
        property bool controlPillHovered: false
        property var controlPillScreen: null
        property bool doNotDisturb: false
        // Screenshots. A request has a mode ("screen", "region", "annotate", "record",
        // "record-region" or "stop"), a screen (empty for the focused one) and a delay in ms.
        // Then the region being chosen ({screen, file, scale}), and the last capture for the
        // island: {screen, file, annotated}, or for a recording {screen, file (its first
        // frame), video, duration in s}.
        property var screenshotRequest: ({
            "mode": "",
            "screen": "",
            "delay": 0
        })
        property int screenshotRequests: 0
        property var screenshotSelection: null
        property var screenshotTaken: null
        // The screen being recorded, since recordingStarted (ms since epoch).
        property bool recording: false
        property string recordingScreen: ""
        property real recordingStarted: 0

        // The region chosen ({x, y, width, height} on the screen), null when cancelled.
        signal screenshotSelected(var rect)

        function requestScreenshot(mode, screen, delay) {
            screenshotRequest = {
                "mode": mode,
                "screen": screen || "",
                "delay": delay || 0
            };
            screenshotRequests += 1;
        }

        // For the privacy dot: something is using the camera or the microphone.
        readonly property bool cameraInUse: privacyService.cameraInUse
        readonly property bool microphoneInUse: privacyService.microphoneInUse
        // Caffeine keeps the computer awake (no dimming, locking or sleep) for caffeineMinutes,
        // until caffeineUntil (ms since epoch). 0 minutes means until you turn it off.
        property bool caffeine: false
        property int caffeineMinutes: 0
        property real caffeineUntil: 0

        function setCaffeine(minutes) {
            caffeineMinutes = minutes;
            caffeineUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0;
            caffeine = true;
        }
        // Until these times (ms since epoch), the next keyboard backlight or screen
        // brightness change shows no OSD. hypridle sets them before it dims things.
        property real keyboardOsdMutedUntil: 0
        property real screenOsdMutedUntil: 0
        // Which way the last skip went (1 next, -1 previous), valid until musicSkipUntil,
        // so the bar's discs roll the right way.
        property int musicSkipDirection: 0
        property real musicSkipUntil: 0
        // Counts "previous" presses, since one may just restart the track.
        property int musicPreviousRequests: 0
        // The AirPods OSD a screen's island shows once their card folds away:
        // {screen, image (their picture, or ""), level (null when unknown), charging}.
        property var airPodsOsd: ({
        })
        property int airPodsOsdRequests: 0
    }

    // hypridle calls `qs -c hyprpunk ipc call osd ignoreNextChange <keyboard|screen>`
    // right before dimming or restoring, so those changes don't pop an OSD.
    IpcHandler {
        function ignoreNextChange(device: string): void {
            const until = Date.now() + 2000;
            if (device === "keyboard")
                globalState.keyboardOsdMutedUntil = until;
            else if (device === "screen")
                globalState.screenOsdMutedUntil = until;
        }

        target: "osd"
    }

    // The previous/next shortcuts go through `qs -c hyprpunk ipc call music <previous|next>`
    // rather than playerctl, because MPRIS never says which way the track changed.
    IpcHandler {
        function skip(direction: int, command: string): void {
            globalState.musicSkipDirection = direction;
            globalState.musicSkipUntil = Date.now() + 2000;
            if (direction < 0)
                globalState.musicPreviousRequests += 1;

            Quickshell.execDetached(["playerctl", command]);
        }

        function next(): void {
            skip(1, "next");
        }

        function previous(): void {
            skip(-1, "previous");
        }

        target: "music"
    }

    // One handler per panel: `qs -c hyprpunk ipc call <panel> <toggle|open|close>`, used by the shortcuts.
    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("controlcenter", "toggle");
        }

        function open(): void {
            globalState.requestPanel("controlcenter", "open");
        }

        function close(): void {
            globalState.requestPanel("controlcenter", "close");
        }

        target: "controlcenter"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("notifications", "toggle");
        }

        function open(): void {
            globalState.requestPanel("notifications", "open");
        }

        function close(): void {
            globalState.requestPanel("notifications", "close");
        }

        target: "notifications"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("session", "toggle");
        }

        function open(): void {
            globalState.requestPanel("session", "open");
        }

        function close(): void {
            globalState.requestPanel("session", "close");
        }

        target: "session"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("wallpaper", "toggle");
        }

        function open(): void {
            globalState.requestPanel("wallpaper", "open");
        }

        function close(): void {
            globalState.requestPanel("wallpaper", "close");
        }

        target: "wallpaper"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("sddm", "toggle");
        }

        function open(): void {
            globalState.requestPanel("sddm", "open");
        }

        function close(): void {
            globalState.requestPanel("sddm", "close");
        }

        target: "sddm"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("launcher", "toggle");
        }

        function open(): void {
            globalState.requestPanel("launcher", "open");
        }

        function close(): void {
            globalState.requestPanel("launcher", "close");
        }

        target: "launcher"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("clipboard", "toggle");
        }

        function open(): void {
            globalState.requestPanel("clipboard", "open");
        }

        function close(): void {
            globalState.requestPanel("clipboard", "close");
        }

        target: "clipboard"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("emoji", "toggle");
        }

        function open(): void {
            globalState.requestPanel("emoji", "open");
        }

        function close(): void {
            globalState.requestPanel("emoji", "close");
        }

        target: "emoji"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("keybindings", "toggle");
        }

        function open(): void {
            globalState.requestPanel("keybindings", "open");
        }

        function close(): void {
            globalState.requestPanel("keybindings", "close");
        }

        target: "keybindings"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("menu", "toggle");
        }

        function open(): void {
            globalState.requestPanel("menu", "open");
        }

        function close(): void {
            globalState.requestPanel("menu", "close");
        }

        target: "menu"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("config", "toggle");
        }

        function open(): void {
            globalState.requestPanel("config", "open");
        }

        function close(): void {
            globalState.requestPanel("config", "close");
        }

        target: "config"
    }

    IpcHandler {
        function toggle(): void {
            globalState.requestPanel("monitor", "toggle");
        }

        function open(): void {
            globalState.requestPanel("monitor", "open");
        }

        function close(): void {
            globalState.requestPanel("monitor", "close");
        }

        target: "monitor"
    }

    NotificationServer {
        id: notificationService

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: (notification) => {
            notification.tracked = true;
        }
    }

    Variants {
        id: bars

        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Lock {
        bars: bars.instances
    }

    Variants {
        model: Quickshell.screens

        TrayCorner {
            required property var modelData

            screen: modelData
        }

    }

    Variants {
        model: Quickshell.screens

        ControlCenter {
            required property var modelData

            screen: modelData
            shellState: globalState
            airPods: airPodsService
        }

    }

    Variants {
        model: Quickshell.screens

        SessionMenu {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        WallpaperPicker {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        SddmPicker {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        AppLauncher {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        ClipboardPanel {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        EmojiPanel {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        KeybindingsPanel {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        ConfigPanel {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        MainMenu {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        MonitorPanel {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    NotificationPopups {
        shellState: globalState
        notificationServer: notificationService
    }

    // Turns caffeine off once its time is up.
    Timer {
        running: globalState.caffeine && globalState.caffeineUntil > 0
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() >= globalState.caffeineUntil)
                globalState.caffeine = false;

        }
    }

    Privacy {
        id: privacyService
    }

    Screenshot {
        shellState: globalState
    }

    Variants {
        model: Quickshell.screens

        ScreenshotMenu {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

    }

    Variants {
        model: Quickshell.screens

        ScreenshotSelector {
            required property var modelData

            screen: modelData
            screenName: modelData.name
            shellState: globalState
        }

    }

    AirPods {
        id: airPodsService
    }

    Variants {
        model: Quickshell.screens

        AirPodsPopup {
            required property var modelData

            screen: modelData
            shellState: globalState
            airPods: airPodsService
        }

    }

    Variants {
        model: Quickshell.screens

        NotificationCenter {
            required property var modelData

            screen: modelData
            shellState: globalState
            notificationServer: notificationService
        }

    }

}
