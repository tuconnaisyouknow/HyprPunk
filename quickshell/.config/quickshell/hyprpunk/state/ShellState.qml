pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the shell shows and asks for, shared by every screen: the panels you ask for and
// where, the island's owners, screenshots, caffeine. Each screen's own
// state is a ScreenState, found with forScreen().
Singleton {
    id: shellState

    // The island's calendar card is open, with the notifications waiting, and where.
    property bool notificationCenterOpen: false
    property var notificationScreen: null
    property bool controlCenterOpen: false
    // Ask for a panel on a screen. panel is one of "controlcenter", "notifications",
    // "session", "wallpaper", "theme", "launcher", "clipboard", "emoji", "keybindings",
    // "config", "workspaces", "systemmonitor", "player", "screenshot", "polkit",
    // "filechooser", "screenshare", "menu", or "settings" for the settings window;
    // action is "toggle", "open" or "close"; screen is a screen's name, or empty for
    // the focused one.
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

        const screenState = forScreen(target);
        if (request.action !== "close" && screenState !== null && screenState.fullscreen && !promptPanels.includes(panel))
            return "";

        return request.action;
    }
    property bool doNotDisturb: false
    // Screenshots. A request has a mode ("screen", "region", "annotate", "record",
    // "record-region", "share-region" or "stop"), a screen (empty for the focused one) and a delay in ms.
    // Then the region being chosen ({screen, file, scale}), and the last capture for the
    // island: {screen, file, annotated, copied, saved}, or for a recording {screen, file
    // (its first frame), video, duration in s}.
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
    // The AirPods OSD a screen's island shows once their card folds away:
    // {screen, image (their picture, or ""), level (null when unknown), charging}.
    property var airPodsOsd: ({
    })
    property int airPodsOsdRequests: 0

    // The state of a screen, by its name or the screen itself, or null if it's gone.
    function forScreen(screen) {
        const name = typeof screen === "string" ? screen : screen.name;
        return screens.instances.find((state) => {
            return state.screen.name === name;
        }) ?? null;
    }

    Variants {
        id: screens

        model: Quickshell.screens

        ScreenState {
        }

    }

    // Turns caffeine off once its time is up.
    Timer {
        running: shellState.caffeine && shellState.caffeineUntil > 0
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (Date.now() >= shellState.caffeineUntil)
                shellState.caffeine = false;

        }
    }

}
