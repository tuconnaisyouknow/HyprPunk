import QtQuick
import Quickshell
import Quickshell.Services.UPower

// What the computer does once the battery is critical, as the settings say
// (BatterySettings): sleeps or shuts down before it dies on you. A minute first, while
// the island warns you, to plug it in; again each minute it wakes still critical.
Scope {
    readonly property bool critical: Power.hasBattery && UPower.onBattery && BatterySettings.critical !== null && Math.round(UPower.displayDevice.percentage * 100) <= BatterySettings.critical

    Timer {
        running: parent.critical && BatterySettings.action !== "none"
        interval: 60000
        repeat: true
        // "suspend" or "poweroff", systemctl's own words.
        onTriggered: Quickshell.execDetached(["systemctl", BatterySettings.action])
    }

}
