pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The CPU's model and frequency and the busiest processes, for the bar's little btop.
// Works only while someone looks (ServiceRef): the always-on numbers are SystemStats'.
Singleton {
    id: details

    property int refCount: 0
    readonly property bool running: refCount > 0
    // "Intel(R) Core(TM) i7-1065G7 CPU @ 1.30GHz", read once.
    property string model: ""
    property string frequency: ""
    // Every process of the last sample: {cpu, memory (KiB), pid, name}. Kept between
    // openings, so a card shows the last one at once while the next is measured. The pid
    // lets a card follow each process from one sample to the next.
    property var processes: []

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

    function parseProcesses(text) {
        const list = [];
        for (const line of text.trim().split("\n")) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 4)
                list.push({
                "cpu": Number(parts[0]),
                "memory": Number(parts[1]),
                "pid": Number(parts[2]),
                "name": parts.slice(3).join(" ")
            });

        }
        processes = list;
    }

    // Fresh as soon as someone looks, rather than at the next tick.
    onRunningChanged: {
        if (running)
            cpuinfoFile.reload();

    }

    // Read at startup too, for the model name.
    FileView {
        id: cpuinfoFile

        path: "/proc/cpuinfo"
        onLoaded: details.parseCpuinfo(text())
    }

    // top runs twice because its first pass only knows lifetime averages, and waits a
    // whole second in between, since a shorter wait makes the numbers jump in 2% steps.
    // top itself is left out (it only shows up because it's measuring). Also run once at
    // startup: a sample takes a second, and the first opening shouldn't wait for it.
    Process {
        id: sample

        running: true
        command: ["sh", "-c", "LC_ALL=C top -b -n 2 -d 1 -e k -w 512 | awk '/^top -/ {n++} n == 2 && /^ *[0-9]+ / && $12 != \"top\" {print $9, $6, $1, $12}'"]

        stdout: StdioCollector {
            onStreamFinished: details.parseProcesses(text)
        }

    }

    Timer {
        interval: 2000
        running: details.running
        repeat: true
        triggeredOnStart: true
        onTriggered: sample.running = true
    }

    Timer {
        interval: 1000
        running: details.running
        repeat: true
        onTriggered: cpuinfoFile.reload()
    }

}
