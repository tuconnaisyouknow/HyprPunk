pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The CPU, memory and temperature, read once a second for the whole shell (the bar's
// resources pill, its little btop and the lock screen). Straight from /proc and /sys,
// so no command has to start every second.
Singleton {
    id: stats

    readonly property int historyLength: 60
    // Whole CPU and each core, 0 to 1.
    property real cpuUsage: 0
    property var coreUsage: []
    // The last minute, oldest first, 0 to 1.
    property var cpuHistory: []
    property var memoryHistory: []
    // In KiB, like /proc/meminfo.
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property string temperature: "--°C"
    property string frequency: ""
    property string model: ""
    // The memory in use as the bar shows it, "5.2G".
    readonly property string memoryText: memoryTotal > 0 ? (memoryUsed / 1048576).toFixed(1) + "G" : "--"
    // How many open cards show the frequency, which is only read while one does.
    property int frequencyWatchers: 0
    // [idle, total] jiffies of the last sample, index 0 for the whole CPU.
    property var previousTimes: []

    function pushHistory(history, value) {
        return history.concat([value]).slice(-historyLength);
    }

    function parseStat(text) {
        const times = [];
        const cores = [];
        let usage = 0;
        for (const line of text.split("\n")) {
            if (!line.startsWith("cpu"))
                break;

            const parts = line.trim().split(/\s+/);
            const values = parts.slice(1, 9).map(Number);
            const idle = values[3] + values[4];
            const total = values.reduce((sum, value) => {
                return sum + value;
            }, 0);
            const index = parts[0] === "cpu" ? 0 : parseInt(parts[0].slice(3)) + 1;
            const previous = previousTimes[index];
            const load = previous && total > previous[1] ? 1 - (idle - previous[0]) / (total - previous[1]) : 0;
            times[index] = [idle, total];
            if (index === 0)
                usage = load;
            else
                cores[index - 1] = Math.max(0, Math.min(1, load));
        }
        previousTimes = times;
        cpuUsage = Math.max(0, Math.min(1, usage));
        coreUsage = cores;
        cpuHistory = pushHistory(cpuHistory, cpuUsage);
    }

    function parseMeminfo(text) {
        const memory = {};
        for (const line of text.split("\n")) {
            const match = line.match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/);
            if (match)
                memory[match[1]] = Number(match[2]);

        }
        memoryTotal = memory.MemTotal || 0;
        memoryUsed = memoryTotal - (memory.MemAvailable || 0);
        swapTotal = memory.SwapTotal || 0;
        swapUsed = swapTotal - (memory.SwapFree || 0);
        memoryHistory = pushHistory(memoryHistory, memoryTotal > 0 ? memoryUsed / memoryTotal : 0);
    }

    function parseCpuinfo(text) {
        const pattern = /^cpu MHz\s*:\s*([\d.]+)/gm;
        let sum = 0;
        let count = 0;
        let match;
        while ((match = pattern.exec(text)) !== null) {
            sum += Number(match[1]);
            count++;
        }
        frequency = Math.round(count > 0 ? sum / count : 0) + " MHz";
        if (model === "") {
            const name = text.match(/^model name\s*:\s*(.*)$/m);
            model = name ? name[1] : "";
        }
    }

    // Fresh as soon as a card opens, rather than at the next second.
    onFrequencyWatchersChanged: {
        if (frequencyWatchers > 0)
            cpuinfoFile.reload();

    }

    FileView {
        id: statFile

        path: "/proc/stat"
        onLoaded: stats.parseStat(text())
    }

    FileView {
        id: meminfoFile

        path: "/proc/meminfo"
        onLoaded: stats.parseMeminfo(text())
    }

    // Read at startup for the model name, then only while a card shows the frequency.
    FileView {
        id: cpuinfoFile

        path: "/proc/cpuinfo"
        onLoaded: stats.parseCpuinfo(text())
    }

    // Empty until the sensor is found, and when there's none.
    FileView {
        id: temperatureFile

        path: ""
        printErrors: false
        onLoaded: {
            const millidegrees = parseInt(text());
            stats.temperature = isNaN(millidegrees) ? "--°C" : Math.round(millidegrees / 1000) + "°C";
        }
    }

    // The CPU package's sensor, the one sensors calls "Package id 0" (Intel) or "Tctl" (AMD).
    Process {
        command: ["sh", "-c", "for hwmon in /sys/class/hwmon/hwmon*; do case $(cat \"$hwmon/name\" 2>/dev/null) in coretemp|k10temp|zenpower) echo \"$hwmon/temp1_input\"; exit;; esac; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: temperatureFile.path = text.trim()
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            statFile.reload();
            meminfoFile.reload();
            if (temperatureFile.path !== "")
                temperatureFile.reload();

            if (stats.frequencyWatchers > 0)
                cpuinfoFile.reload();

        }
    }

}
