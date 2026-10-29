import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// A little btop for the resources pill: CPU and memory over the last minute, each
// core's load and the busiest processes. Just the content, the bar draws the card,
// and the numbers come from SystemStats.
Item {
    id: monitor

    // Off while the card is not shown: stops listing the processes.
    property bool active: false
    // "Intel(R) Core(TM) i7-1065G7 CPU @ 1.30GHz" -> "Intel Core i7-1065G7".
    readonly property string shortModel: SystemStats.model.replace(/\((R|TM)\)/g, "").replace(/\s+(CPU|Processor)\b.*$/i, "").replace(/\s+\d+-Core.*$/i, "").replace(/\s+/g, " ").trim()
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
    // The frequency is only read while a card shows it.
    onActiveChanged: SystemStats.frequencyWatchers += active ? 1 : -1
    Component.onDestruction: {
        if (active)
            SystemStats.frequencyWatchers -= 1;

    }

    // top runs twice because its first pass only knows lifetime averages, and waits a
    // whole second in between, since a shorter wait makes the numbers jump in 2% steps.
    // top itself is left out (it only shows up because it's measuring). Also run once at
    // startup, so the first opening has something to show while it refreshes.
    Process {
        id: processProcess

        running: true
        command: ["sh", "-c", "LC_ALL=C top -b -n 2 -d 1 -e k -w 512 | awk '/^top -/ {n++} n == 2 && /^ *[0-9]+ / && $12 != \"top\" {print $9, $6, $12}'"]

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
        color: Theme.mauve
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    component IconTitle: IconText {
        font.pixelSize: 14
        font.weight: Font.Bold
    }

    component IconDetail: IconText {
        color: Theme.lavender
        font.pixelSize: 12
        font.weight: Font.Normal
        font.features: {
            "tnum": 1
        }
    }

    component Detail: Text {
        color: Theme.lavender
        font.family: Theme.font
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

            const step = width / (SystemStats.historyLength - 1);
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
            ctx.strokeStyle = Theme.mauve;
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(startX, height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Theme.alpha(Theme.mauve, 0.28));
            fill.addColorStop(1, Theme.alpha(Theme.mauve, 0));
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

                IconTitle {
                    icon: ""
                    text: "CPU"
                }

                Detail {
                    Layout.fillWidth: true
                    text: monitor.shortModel
                    elide: Text.ElideRight
                }

                SectionTitle {
                    text: Math.round(SystemStats.cpuUsage * 100) + "%"
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            HistoryGraph {
                values: SystemStats.cpuHistory
            }

            // One bar per core, filled from the bottom.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: SystemStats.coreUsage.length

                    Rectangle {
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 24
                        radius: 4
                        color: Theme.alpha(Theme.text, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.max(radius * 2, parent.height * (SystemStats.coreUsage[parent.index] || 0))
                            radius: parent.radius
                            color: Theme.mauve
                            opacity: 0.35 + 0.65 * (SystemStats.coreUsage[parent.index] || 0)

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

                IconDetail {
                    Layout.fillWidth: true
                    icon: ""
                    text: SystemStats.temperature
                }

                IconDetail {
                    icon: String.fromCodePoint(0xf04c5)
                    text: SystemStats.frequency
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconTitle {
                    icon: ""
                    text: "RAM"
                }

                Detail {
                    Layout.fillWidth: true
                    text: monitor.formatKiB(SystemStats.memoryUsed) + " / " + monitor.formatKiB(SystemStats.memoryTotal)
                }

                SectionTitle {
                    text: (SystemStats.memoryTotal > 0 ? Math.round(SystemStats.memoryUsed * 100 / SystemStats.memoryTotal) : 0) + "%"
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            HistoryGraph {
                values: SystemStats.memoryHistory
            }

            RowLayout {
                Layout.fillWidth: true

                Detail {
                    Layout.fillWidth: true
                    text: "Swap"
                }

                Detail {
                    text: SystemStats.swapTotal > 0 ? monitor.formatKiB(SystemStats.swapUsed) + " / " + monitor.formatKiB(SystemStats.swapTotal) : "off"
                    color: SystemStats.swapTotal > 0 ? Theme.lavender : Theme.overlay1
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                IconTitle {
                    Layout.fillWidth: true
                    icon: ""
                    text: "Processes"
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
                            backgroundColor: sortChip.selected ? Theme.alpha(Theme.mauve, chipHover.hovered ? 0.95 : 0.8) : "transparent"
                        }

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            text: sortChip.modelData.label
                            color: sortChip.selected ? Theme.base : Theme.lavender
                            font.family: Theme.font
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
                        color: Theme.mauve
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 13
                    }

                    // The sorted column in mauve, the other one in lavender.
                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        // top counts a share of one core, the card a share of the whole CPU like btop.
                        text: parent.process !== null ? (parent.process.cpu / Math.max(1, SystemStats.coreUsage.length)).toFixed(1) + "%" : ""
                        color: monitor.processSort === "cpu" ? Theme.mauve : Theme.lavender
                    }

                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        text: parent.process !== null ? monitor.formatKiB(parent.process.memory) : ""
                        color: monitor.processSort === "memory" ? Theme.mauve : Theme.lavender
                    }

                }

            }

        }

    }

}
