import QtQuick
import Quickshell
import Quickshell.Io

// Warms the screens while the night light should be on: always, or between the hours
// you set (NightLightSettings). The night light is hyprsunset running: started warm,
// told a new warmth through its IPC while it runs, and stopped to give the screens
// their colors back.
Scope {
    id: nightLight

    // The time the schedule is checked against, moved on every half minute.
    property date now: new Date()
    readonly property bool inSchedule: {
        const from = NightLightSettings.from;
        const to = NightLightSettings.to;
        if (from === null || to === null)
            return false;

        const hour = now.getHours();
        // Across midnight, like 21 to 7.
        return from <= to ? hour >= from && hour < to : hour >= from || hour < to;
    }
    readonly property bool active: NightLightSettings.temperature !== null && (NightLightSettings.mode === "on" || (NightLightSettings.mode === "schedule" && inSchedule))

    Timer {
        running: NightLightSettings.mode === "schedule"
        interval: 30000
        repeat: true
        onTriggered: nightLight.now = new Date()
    }

    Process {
        id: hyprsunset

        running: nightLight.active
        command: ["hyprsunset", "-t", String(NightLightSettings.temperature)]
    }

    Connections {
        function onTemperatureChanged() {
            if (hyprsunset.running)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(NightLightSettings.temperature)]);

        }

        target: NightLightSettings
    }

}
