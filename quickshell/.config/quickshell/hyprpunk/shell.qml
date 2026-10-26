//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = qt6ct
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    QtObject {
        id: globalState

        property bool notificationCenterOpen: false
        property var notificationScreen: null
        property bool controlCenterOpen: false
        // Requests for a screen's panels: panel is "controlcenter", "notifications",
        // "session", "wallpaper", "sddm", "launcher", "clipboard", "emoji",
        // "keybindings", "config", "monitor" or "menu", action "toggle", "open"
        // or "close", screen a screen name (the focused one when empty).
        property var panelRequest: ({
            "panel": "",
            "action": "",
            "screen": ""
        })
        property int panelRequests: 0
        // The dynamic island (clock pill), the session menu grows out of it (screen
        // coordinates, centerOffset is the distance from the screen's horizontal centre).
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
        // Bottom edge of the control center panel (screen y), followed by the popups.
        property real controlCenterBottom: 0
        property var controlCenterBottomScreen: null
        // Right-most bar pill, the control center grows out of it (screen coordinates,
        // right and top are distances from the screen edges).
        property var controlPill: ({
            "right": 24,
            "top": 6,
            "width": 120,
            "height": 38
        })
        property bool controlPillHovered: false
        property var controlPillScreen: null
        property bool doNotDisturb: false
        // Until these times (ms since epoch), the next keyboard backlight or
        // screen brightness change gets no OSD. Set through IPC by hypridle.
        property real keyboardOsdMutedUntil: 0
        property real screenOsdMutedUntil: 0
        // Skip direction announced through IPC (1 next, -1 previous), valid until
        // musicSkipUntil, so the bar's discs roll the right way.
        property int musicSkipDirection: 0
        property real musicSkipUntil: 0
        // Incremented on each "previous" request, which may restart the track instead.
        property int musicPreviousRequests: 0
        // AirPods OSD on a screen's island, once the AirPods card folds back:
        // {screen, image (the pods' render, "" for none), level (null when unknown), charging}.
        property var airPodsOsd: ({
        })
        property int airPodsOsdRequests: 0
    }

    // hypridle calls `qs -c hyprpunk ipc call osd ignoreNextChange <keyboard|screen>`
    // right before dimming or restoring, so its own changes get no OSD.
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

    // The previous/next keybinds call `qs -c hyprpunk ipc call music <previous|next>`
    // instead of playerctl directly: MPRIS does not tell which way the track changed.
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

    // Keybinds call `qs -c hyprpunk ipc call <controlcenter|notifications|session|wallpaper|sddm> <toggle|open|close>`.
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
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            shellState: globalState
        }

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
