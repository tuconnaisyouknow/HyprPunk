pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the shell shows and asks for, shared by every screen: do not disturb, screenshots,
// caffeine, the AirPods OSD. Each screen's own state (its island, its surfaces) is a
// ScreenState, found with forScreen() or focused().
Singleton {
    id: shellState

    // The surfaces that belong to no screen (the settings window), by name, reached
    // through any screen's open(), close() and toggle().
    property var surfaces: ({
    })

    function register(name, surface) {
        surfaces[name] = surface;
    }

    // The screen you're on: Hyprland's focused monitor, else the first screen.
    function focused() {
        const monitor = Hyprland.focusedMonitor;
        return (monitor !== null ? forScreen(monitor.name) : null) ?? screens.instances[0] ?? null;
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
