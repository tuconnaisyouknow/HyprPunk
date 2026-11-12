//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = qt6ct
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING = gray
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER = 1
//@ pragma IconTheme Papirus-Dark

// Gray antialiasing for the text: colored edges assume an opaque background and
// glitch through the see-through glass, worst over a light page.
// Animations follow the clock: by default Qt moves them one screen refresh per frame
// drawn, so whenever drawing falls behind (the glass over several windows at once)
// they play in slow motion, a 280 ms fold taking twice as long.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit

// Where the shell starts. Holds the state the screens share (which panel is open
// where, screenshots, caffeine…), answers the `qs -c hyprpunk ipc call …` commands
// that the shortcuts and scripts send, and puts a bar, popups and panels on every screen.
ShellRoot {
    // The desktop's music wave runs as its own Quickshell, so the shell's stalls (building
    // the lock screen) don't freeze it. -n: only one, whenever the shell starts or reloads.
    Component.onCompleted: Quickshell.execDetached(["qs", "-n", "-p", Quickshell.shellPath("VisualizerShell.qml")])

    QtObject {
        id: globalState

        // The island's calendar card is open, with the notifications waiting, and where.
        property bool notificationCenterOpen: false
        property var notificationScreen: null
        property bool controlCenterOpen: false
        // Ask for a panel on a screen. panel is one of "controlcenter", "notifications",
        // "session", "wallpaper", "theme", "launcher", "clipboard", "emoji", "keybindings",
        // "config", "monitor", "workspaces", "systemmonitor", "player", "screenshot",
        // "polkit", "filechooser", "screenshare" or "menu"; action is "toggle", "open" or
        // "close"; screen is a screen's name, or empty for the focused one.
        property var panelRequest: ({
            "panel": "",
            "action": "",
            "screen": ""
        })
        property int panelRequests: 0
        // The island panels open right now, as "panel@screen", so the notifications and
        // the AirPods card wait their turn, then take the island's shape from them as they
        // close (IslandFrame). The calendar card and the AirPods card count too.
        property var islandPanels: []
        // The island panels that answer an app (a password, a file, a screen to share):
        // the other panels can't take the island from them, and they take turns.
        readonly property var promptPanels: ["polkit", "filechooser", "screenshare"]
        // The screens showing a fullscreen window, which the shell's window is under: the
        // panels you ask for don't open there, the prompts do (they show once it's gone).
        property var fullscreenScreens: []

        // Something takes the island on a screen (an island panel, the calendar): the
        // others fold back.
        signal islandClaimed(string screenName, string owner)

        // A prompt holds the island on that screen, other than the one asking.
        function promptShown(screenName, except) {
            return islandPanels.some((key) => {
                const [name, screen] = key.split("@");
                return screen === screenName && name !== except && promptPanels.includes(name);
            });
        }

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

        // What the last request asks of this panel on this screen ("toggle", "open" or
        // "close"), or "" when it's meant for another one, or can't open there.
        function requestedAction(panel, screen) {
            const request = panelRequest;
            const target = request.screen || (Hyprland.focusedMonitor !== null ? Hyprland.focusedMonitor.name : "");
            if (request.panel !== panel || target !== screen.name)
                return "";

            if (request.action !== "close" && fullscreenScreens.includes(target) && !promptPanels.includes(panel))
                return "";

            return request.action;
        }
        property bool doNotDisturb: false
        // Screenshots. A request has a mode ("screen", "region", "annotate", "record",
        // "record-region", "share-region" or "stop"), a screen (empty for the focused one) and a delay in ms.
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
                Devices.keyboardOsdMutedUntil = until;
            else if (device === "screen")
                Devices.screenOsdMutedUntil = until;
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
    Variants {
        model: ["controlcenter", "notifications", "session", "wallpaper", "theme", "launcher", "clipboard", "emoji", "keybindings", "menu", "config", "monitor", "workspaces", "systemmonitor", "player"]

        // Kept around the handler, so ipc show lists only the three functions.
        Scope {
            id: panelIpc

            required property string modelData

            IpcHandler {
                function toggle(): void {
                    globalState.requestPanel(panelIpc.modelData, "toggle");
                }

                function open(): void {
                    globalState.requestPanel(panelIpc.modelData, "open");
                }

                function close(): void {
                    globalState.requestPanel(panelIpc.modelData, "close");
                }

                target: panelIpc.modelData
            }

        }

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

    NotificationHistory {
        id: notificationArchive

        notificationServer: notificationService
    }

    // The shell answers the password prompts itself, on the focused screen.
    PolkitAgent {
        id: polkitService

        onAuthenticationRequestStarted: globalState.requestPanel("polkit", "open")
    }

    // The apps' Open and Save dialogs, through the portal, on the focused screen too.
    FileChooser {
        id: fileChooserService

        onRequested: globalState.requestPanel("filechooser", "open")
    }

    // What an app gets to see when it shares your screen, through
    // xdg-desktop-portal-hyprland, on the focused screen too.
    ScreenShare {
        id: screenShareService

        shellState: globalState
        onRequested: globalState.requestPanel("screenshare", "open")
    }

    // The bar and its cards on every screen.
    Variants {
        id: screens

        model: Quickshell.screens

        ScreenShell {
            required property var modelData

            screen: modelData
            shellState: globalState
            notificationServer: notificationService
            notificationHistory: notificationArchive
            polkitAgent: polkitService
            fileChooser: fileChooserService
            screenShare: screenShareService
            airPods: airPodsService
        }

    }

    Lock {
        bars: screens.instances.map((shell) => {
            return shell.bar;
        })
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

    // A network that wants you to sign in first: a notification takes you to its page.
    Connections {
        function onConnectivityChanged() {
            if (Networking.connectivity === NetworkConnectivity.Portal)
                Quickshell.execDetached([Session.scripts + "/captive-portal.sh"]);

        }

        target: Networking
    }

}
