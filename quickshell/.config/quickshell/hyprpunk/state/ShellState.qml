pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the shell shows and asks for, shared by every screen: do not disturb and
// caffeine. Each screen's own state (its island, its surfaces) is a
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

    property alias doNotDisturb: kept.doNotDisturb

    // Caffeine keeps the computer awake (no dimming, locking or sleep) for caffeineMinutes,
    // until caffeineUntil (ms since epoch). 0 minutes means until you turn it off.
    property alias caffeine: kept.caffeine
    property alias caffeineMinutes: kept.caffeineMinutes
    property alias caffeineUntil: kept.caffeineUntil
    // Whole minutes left, rounded up, while caffeine has a time.
    property int caffeineMinutesLeft: 0

    function setCaffeine(minutes) {
        caffeineMinutes = minutes;
        caffeineUntil = minutes > 0 ? Date.now() + minutes * 60000 : 0;
        caffeineMinutesLeft = minutes;
        caffeine = true;
    }

    // On until you turn it off, or off.
    function toggleCaffeine() {
        if (caffeine)
            caffeine = false;
        else
            setCaffeine(0);
    }

    // The state of a screen, by its name or the screen itself, or null if it's gone.
    function forScreen(screen) {
        if (!screen)
            return null;

        const name = typeof screen === "string" ? screen : screen.name;
        return screens.instances.find((state) => {
            return state.screen.name === name;
        }) ?? null;
    }

    // What you turned on outlives the shell reloading: a reload would quietly drop
    // caffeine and let the computer sleep, or let the notifications back in.
    PersistentProperties {
        id: kept

        property bool doNotDisturb: false
        property bool caffeine: false
        property int caffeineMinutes: 0
        property real caffeineUntil: 0

        reloadableId: "shellState"
    }

    Variants {
        id: screens

        model: Quickshell.screens

        ScreenState {
        }

    }

    // Counts caffeine's time down, and turns it off once it's up.
    Timer {
        running: shellState.caffeine && shellState.caffeineUntil > 0
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const left = shellState.caffeineUntil - Date.now();
            shellState.caffeineMinutesLeft = Math.max(0, Math.ceil(left / 60000));
            if (left <= 0)
                shellState.caffeine = false;

        }
    }

}
