pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Warms the screens while the night light should be on: always, or between the hours
// you set (NightLightSettings). On a schedule, toggle() goes against it until its next
// turn, then the schedule leads again. The night light is hyprsunset running: started
// warm, told a new warmth through its IPC while it runs, and stopped to give the screens
// their colors back.
Singleton {
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
    // Turned on or off against the schedule, until its next turn.
    readonly property bool overridden: now.getTime() < kept.overrideUntil
    readonly property bool scheduledOn: inSchedule !== overridden
    readonly property bool active: NightLightSettings.temperature !== null && (NightLightSettings.mode === "on" || (NightLightSettings.mode === "schedule" && scheduledOn))

    // The next hour the schedule turns at, from now.
    function nextTurn() {
        const turns = [];
        for (const day of [0, 1]) {
            for (const hour of [NightLightSettings.from, NightLightSettings.to])
                turns.push(new Date(now.getFullYear(), now.getMonth(), now.getDate() + day, hour).getTime());

        }
        return Math.min(...turns.filter((time) => {
            return time > now.getTime();
        }));
    }

    // Following the hours, or left as it is now, on or off.
    function setScheduled(scheduled) {
        NightLightSettings.set("mode", scheduled ? "schedule" : active ? "on" : "off");
    }

    // On or off. On a schedule, against it until its next turn, or back with it: the
    // schedule itself is only left in the settings.
    function toggle() {
        if (NightLightSettings.mode !== "schedule") {
            NightLightSettings.set("mode", active ? "off" : "on");
            return ;
        }
        now = new Date();
        kept.overrideUntil = overridden ? 0 : nextTurn();
    }

    Timer {
        running: NightLightSettings.mode === "schedule"
        interval: 30000
        repeat: true
        onTriggered: nightLight.now = new Date()
    }

    // Ended with the shell, even crashed: left running, the next shell couldn't stop it.
    TiedProcess {
        id: hyprsunset

        running: nightLight.active
        program: ["hyprsunset", "-t", String(NightLightSettings.temperature)]
    }

    // A reload doesn't undo what you turned on or off for the night.
    PersistentProperties {
        id: kept

        property real overrideUntil: 0

        reloadableId: "nightLight"
    }

    Connections {
        // A schedule picked again starts as it says.
        function onModeChanged() {
            kept.overrideUntil = 0;
        }

        function onTemperatureChanged() {
            if (hyprsunset.running)
                Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(NightLightSettings.temperature)]);

        }

        target: NightLightSettings
    }

}
