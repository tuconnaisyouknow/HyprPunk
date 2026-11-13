pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// When the computer dims, locks and sleeps once you leave it, saved by powerctl.sh.
// Each step has a delay plugged in and one on battery; the shell's idle monitors
// follow the set for where the power comes from (shell.qml).
Singleton {
    id: power

    // Every saved setting, as powerctl.sh writes them: "plugged.dim" → "300".
    readonly property var settings: file.values
    readonly property bool hasBattery: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
    readonly property string source: hasBattery && UPower.onBattery ? "battery" : "plugged"
    readonly property bool mediaKeepsAwake: settings.media === "true"
    // Something is playing and you asked for that to keep the computer awake.
    readonly property bool awakeForMedia: mediaKeepsAwake && Mpris.players.values.some((player) => {
        return player.isPlaying;
    })

    // The delay of a step ("keyboard", "dim", "lock" or "suspend") in seconds, 0 for never.
    function delay(step, from) {
        return parseInt(settings[(from || source) + "." + step]) || 0;
    }

    function set(key, value) {
        file.run(["set", key, String(value)]);
    }

    // Never saved yet, it's written with the defaults, or nothing would ever lock.
    SettingsFile {
        id: file

        fileName: "power.conf"
        script: "powerctl.sh"
    }

}
