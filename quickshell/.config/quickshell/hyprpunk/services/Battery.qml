pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

// The battery: its level, where the power comes from, the time left, the low and
// critical warnings at the levels you set (BatterySettings), and what the computer does
// when it stays critical. Always on, from UPower's changes (no polling). Only the time
// left measured from the battery's own draw works while someone shows it (ServiceRef).
Singleton {
    id: battery

    readonly property var device: UPower.displayDevice
    readonly property bool present: device.ready && device.isLaptopBattery && device.isPresent
    readonly property int percent: Math.round(device.percentage * 100)
    readonly property bool onBattery: UPower.onBattery
    // In seconds, 0 while unknown. Just unplugged, UPower waits for a few readings before
    // it has an estimate: meanwhile the time left comes from the battery's draw.
    readonly property real timeLeft: device.timeToEmpty > 0 ? device.timeToEmpty : drawEstimate
    readonly property real timeToFull: device.timeToFull
    // At or under the critical level on battery: the island's alert stays up, and the
    // computer does what the settings ask.
    readonly property bool critical: present && onBattery && BatterySettings.critical !== null && percent <= BatterySettings.critical
    // The warning given since the last time it was plugged in: 0 none, 1 low, 2 critical.
    // Each is given once, and only a deeper one follows.
    property int alertStage: 0
    // Off while the shell starts: UPower's first values aren't a plug or unplug.
    property bool ready: false
    // The time left is measured from the draw while this is above zero.
    property int refCount: 0
    property real drawEstimate: 0

    // A warning to give: 1 low, 2 critical.
    signal alerted(int stage)
    // Plugged in or unplugged, once the shell has started.
    signal sourceSwitched()

    function updateAlert() {
        if (!present)
            return ;

        const stage = !onBattery ? 0 : BatterySettings.critical !== null && percent <= BatterySettings.critical ? 2 : BatterySettings.low !== null && percent <= BatterySettings.low ? 1 : 0;
        if (stage !== 0 && stage <= alertStage)
            return ;

        alertStage = stage;
        if (stage > 0)
            alerted(stage);

    }

    // A fresh measure each time someone asks: an old one would be from another moment.
    onRefCountChanged: {
        if (refCount === 1)
            drawEstimate = 0;

    }
    onOnBatteryChanged: {
        updateAlert();
        if (ready)
            sourceSwitched();

    }
    Component.onCompleted: Qt.callLater(updateAlert)

    Connections {
        function onPercentageChanged() {
            battery.updateAlert();
        }

        target: battery.device
    }

    // New levels count at once.
    Connections {
        function onLowChanged() {
            battery.updateAlert();
        }

        function onCriticalChanged() {
            battery.updateAlert();
        }

        target: BatterySettings
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: battery.ready = true
    }

    // Sleeps or shuts down before the battery dies on you: a minute first, while the
    // island warns you, to plug it in, and again each minute it wakes still critical.
    Timer {
        running: battery.critical && BatterySettings.action !== "none"
        interval: 60000
        repeat: true
        // "suspend" or "poweroff", systemctl's own words.
        onTriggered: Quickshell.execDetached(["systemctl", BatterySettings.action])
    }

    // The draw, every second, while UPower has no estimate.
    Timer {
        running: battery.refCount > 0 && battery.device.timeToEmpty <= 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: draw.running = true
    }

    Process {
        id: draw

        // Each battery's energy and draw (µWh and µW). Batteries that only report charge
        // and current get multiplied by their voltage. The draw may be negative.
        command: ["sh", "-c", 'for dir in /sys/class/power_supply/*; do
[ "$(cat "$dir/type" 2>/dev/null)" = Battery ] || continue
[ "$(cat "$dir/scope" 2>/dev/null)" = Device ] && continue
if [ -r "$dir/energy_now" ]; then echo "$(cat "$dir/energy_now") $(cat "$dir/power_now" 2>/dev/null || echo 0)"
elif [ -r "$dir/charge_now" ]; then volts=$(cat "$dir/voltage_now" 2>/dev/null || echo 0); echo "$(($(cat "$dir/charge_now") / 1000 * volts / 1000)) $(($(cat "$dir/current_now" 2>/dev/null || echo 0) / 1000 * volts / 1000))"
fi
done']

        stdout: StdioCollector {
            onStreamFinished: {
                let energy = 0;
                let power = 0;
                for (const line of text.trim().split("\n")) {
                    const values = line.split(" ").map(Number);
                    if (values.length === 2 && !isNaN(values[0]) && !isNaN(values[1])) {
                        energy += values[0];
                        power += Math.abs(values[1]);
                    }
                }
                // Hours left, in seconds.
                if (energy > 0 && power > 0)
                    battery.drawEstimate = energy / power * 3600;

            }
        }

    }

}
