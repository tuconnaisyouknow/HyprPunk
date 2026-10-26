import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// btop-like card for the resources pill: CPU and memory history, per-core
// load and the busiest processes. Only the content: the bar draws the card.
Item {
    id: monitor

    // Off while the card is not shown: stops listing the processes.
    property bool active: false
    property string temperature: "--°C"
    property string frequency: ""
    property string model: ""
    // "Intel(R) Core(TM) i7-1065G7 CPU @ 1.30GHz" -> "Intel Core i7-1065G7".
    readonly property string shortModel: model.replace(/\((R|TM)\)/g, "").replace(/\s+(CPU|Processor)\b.*$/i, "").replace(/\s+\d+-Core.*$/i, "").replace(/\s+/g, " ").trim()
    readonly property int historyLength: 60
    property var cpuHistory: []
    property var memoryHistory: []
    property real cpuUsage: 0
    property var coreUsage: []
    // [idle, total] jiffies of the last sample, index 0 for the whole CPU.
    property var previousTimes: []
    property real memoryTotal: 0
    property real memoryUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    property string processSort: "cpu"
    // Every process of the last sample, sorted here so switching the sort is instant.
    property var allProcesses: []
    readonly property var processes: allProcesses.slice().sort((a, b) => {
        return b[processSort] - a[processSort];
    }).slice(0, 5)

    function formatKiB(kib) {
        const gib = kib / 1048576;
        return gib >= 1 ? gib.toFixed(1) + "G" : Math.round(kib / 1024) + "M";
    }

    function pushHistory(history, value) {
        return history.concat([value]).slice(-historyLength);
    }

    function parseStats(text) {
        const times = [];
        const cores = [];
        const memory = {};
        let usage = 0;
        for (const line of text.trim().split("\n")) {
            const parts = line.trim().split(/\s+/);
            if (parts[0].startsWith("cpu")) {
                const values = parts.slice(1, 9).map(Number);
                const idle = values[3] + values[4];
                const total = values.reduce((sum, value) => sum + value, 0);
                const index = parts[0] === "cpu" ? 0 : parseInt(parts[0].slice(3)) + 1;
                const previous = previousTimes[index];
                const load = previous && total > previous[1] ? 1 - (idle - previous[0]) / (total - previous[1]) : 0;
                times[index] = [idle, total];
                if (index === 0)
                    usage = load;
                else
                    cores[index - 1] = Math.max(0, Math.min(1, load));
            } else if (parts[0].endsWith(":")) {
                memory[parts[0].slice(0, -1)] = Number(parts[1]);
            }
        }
        previousTimes = times;
        cpuUsage = Math.max(0, Math.min(1, usage));
        coreUsage = cores;
        memoryTotal = memory.MemTotal || 0;
        memoryUsed = memoryTotal - (memory.MemAvailable || 0);
        swapTotal = memory.SwapTotal || 0;
        swapUsed = swapTotal - (memory.SwapFree || 0);
        cpuHistory = pushHistory(cpuHistory, cpuUsage);
        memoryHistory = pushHistory(memoryHistory, memoryTotal > 0 ? memoryUsed / memoryTotal : 0);
    }

    function parseProcesses(text) {
        const list = [];
        for (const line of text.trim().split("\n")) {
            const parts = line.trim().split(/\s+/);
            if (parts.length >= 3)
                list.push({
                "cpu": Number(parts[0]),
                "memory": Number(parts[1]),
                "name": parts.slice(2).join(" ")
            });

        }
        allProcesses = list;
    }

    implicitWidth: 380
    implicitHeight: column.implicitHeight + 28

    // Sampled all the time, so the history is already there when the card opens.
    Process {
        id: statsProcess

        command: ["sh", "-c", "grep '^cpu' /proc/stat; grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree):' /proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: monitor.parseStats(text)
        }

    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProcess.running = true
    }

    // Two top iterations: the first one only has lifetime averages, the second the current load.
    // top itself is left out, it only shows up because it is measuring. Also run once
    // at startup, so the first opening already has a list to show while it refreshes.
    Process {
        id: processProcess

        running: true
        command: ["sh", "-c", "LC_ALL=C top -b -n 2 -d 0.5 -e k -w 512 | awk '/^top -/ {n++} n == 2 && /^ *[0-9]+ / && $12 != \"top\" {print $9, $6, $12}'"]

        stdout: StdioCollector {
            onStreamFinished: monitor.parseProcesses(text)
        }

    }

    Timer {
        interval: 2000
        running: monitor.active
        repeat: true
        triggeredOnStart: true
        onTriggered: processProcess.running = true
    }

    component SectionTitle: Text {
        color: "#cba6f7"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    component Detail: Text {
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.features: {
            "tnum": 1
        }
    }

    component Section: Item {
        default property alias content: sectionColumn.data

        Layout.fillWidth: true
        implicitHeight: sectionColumn.implicitHeight + 24

        GlassSurface {
        }

        ColumnLayout {
            id: sectionColumn

            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
        }

    }

    // Line of the last minute (0..1), right-aligned so it scrolls in from the right.
    component HistoryGraph: Canvas {
        property var values: []

        Layout.fillWidth: true
        implicitHeight: 48
        onValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (values.length < 2)
                return ;

            const step = width / (monitor.historyLength - 1);
            const startX = width - (values.length - 1) * step;
            const yOf = (value) => {
                return 1 + (height - 2) * (1 - value);
            };
            ctx.beginPath();
            ctx.moveTo(startX, yOf(values[0]));
            for (let i = 1; i < values.length; i++)
                ctx.lineTo(startX + i * step, yOf(values[i]));
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.strokeStyle = "#cba6f7";
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(startX, height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.28));
            fill.addColorStop(1, Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0));
            ctx.fillStyle = fill;
            ctx.fill();
        }
    }

    ColumnLayout {
        id: column

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        spacing: 10

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SectionTitle {
                    text: "  CPU"
                }

                Detail {
                    Layout.fillWidth: true
                    text: monitor.shortModel
                    elide: Text.ElideRight
                }

                SectionTitle {
                    text: Math.round(monitor.cpuUsage * 100) + "%"
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            HistoryGraph {
                values: monitor.cpuHistory
            }

            // One bar per core, filled from the bottom.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: monitor.coreUsage.length

                    Rectangle {
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 24
                        radius: 4
                        color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.max(radius * 2, parent.height * (monitor.coreUsage[parent.index] || 0))
                            radius: parent.radius
                            color: "#cba6f7"
                            opacity: 0.35 + 0.65 * (monitor.coreUsage[parent.index] || 0)

                            Behavior on height {
                                NumberAnimation {
                                    duration: 400
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

            }

            RowLayout {
                Layout.fillWidth: true

                Detail {
                    Layout.fillWidth: true
                    text: " " + monitor.temperature
                }

                Detail {
                    text: String.fromCodePoint(0xf04c5) + " " + monitor.frequency
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SectionTitle {
                    text: String.fromCodePoint(0xf0f86) + "  RAM"
                }

                Detail {
                    Layout.fillWidth: true
                    text: monitor.formatKiB(monitor.memoryUsed) + " / " + monitor.formatKiB(monitor.memoryTotal)
                }

                SectionTitle {
                    text: (monitor.memoryTotal > 0 ? Math.round(monitor.memoryUsed * 100 / monitor.memoryTotal) : 0) + "%"
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            HistoryGraph {
                values: monitor.memoryHistory
            }

            RowLayout {
                Layout.fillWidth: true

                Detail {
                    Layout.fillWidth: true
                    text: "Swap"
                }

                Detail {
                    text: monitor.swapTotal > 0 ? monitor.formatKiB(monitor.swapUsed) + " / " + monitor.formatKiB(monitor.swapTotal) : "off"
                    color: monitor.swapTotal > 0 ? "#b4befe" : "#7f849c"
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SectionTitle {
                    Layout.fillWidth: true
                    text: "  Processes"
                }

                Repeater {
                    model: [{
                        "key": "cpu",
                        "label": "CPU"
                    }, {
                        "key": "memory",
                        "label": "RAM"
                    }]

                    Rectangle {
                        id: sortChip

                        required property var modelData
                        readonly property bool selected: monitor.processSort === modelData.key

                        implicitWidth: chipLabel.implicitWidth + 18
                        implicitHeight: 22
                        radius: height / 2
                        color: "transparent"

                        // Mauve glass when selected, plain glass on hover otherwise.
                        GlassSurface {
                            radius: parent.radius
                            hovered: chipHover.hovered
                            opacity: sortChip.selected || chipHover.hovered ? 1 : 0
                            backgroundColor: sortChip.selected ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, chipHover.hovered ? 0.95 : 0.8) : "transparent"
                        }

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            text: sortChip.modelData.label
                            color: sortChip.selected ? "#1e1e2e" : "#b4befe"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: monitor.processSort = sortChip.modelData.key
                        }

                    }

                }

            }

            // Always five rows, so the card keeps its height while the list loads.
            Repeater {
                model: 5

                RowLayout {
                    required property int index
                    readonly property var process: monitor.processes[index] ?? null

                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: parent.process !== null ? parent.process.name : ""
                        color: "#cba6f7"
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }

                    // The sorted column in mauve, the other one in lavender.
                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        text: parent.process !== null ? parent.process.cpu.toFixed(1) + "%" : ""
                        color: monitor.processSort === "cpu" ? "#cba6f7" : "#b4befe"
                    }

                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        text: parent.process !== null ? monitor.formatKiB(parent.process.memory) : ""
                        color: monitor.processSort === "memory" ? "#cba6f7" : "#b4befe"
                    }

                }

            }

        }

    }

}
