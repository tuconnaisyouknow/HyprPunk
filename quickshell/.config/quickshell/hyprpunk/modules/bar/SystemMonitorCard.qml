import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// A little btop for the resources pill: CPU and memory over the last minute, each
// core's load and the busiest processes. Just the content, the bar draws the card,
// and the numbers come from SystemStats and, while it's shown, SystemDetails.
Item {
    id: monitor

    // Shown: the details are only measured meanwhile.
    property bool active: false
    // "Intel(R) Core(TM) i7-1065G7 CPU @ 1.30GHz" -> "Intel Core i7-1065G7".
    readonly property string shortModel: SystemDetails.model.replace(/\((R|TM)\)/g, "").replace(/\s+(CPU|Processor)\b.*$/i, "").replace(/\s+\d+-Core.*$/i, "").replace(/\s+/g, " ").trim()
    property string processSort: "cpu"
    // Sorted here so switching the sort is instant.
    readonly property var processes: SystemDetails.processes.slice().sort((a, b) => {
        return b[processSort] - a[processSort];
    }).slice(0, 5)

    // Brings the rows to the new ranking a process at a time: one that stays moves to
    // its place rather than being dropped and added again, so its row can glide there.
    function syncRows() {
        for (let i = rows.count - 1; i >= 0; i--) {
            const pid = rows.get(i).pid;
            if (!processes.some((process) => {
                return process.pid === pid;
            }))
                rows.remove(i);

        }
        processes.forEach((process, index) => {
            let from = index;
            while (from < rows.count && rows.get(from).pid !== process.pid) {
                from++;
            }
            if (from === rows.count) {
                rows.insert(index, process);
            } else {
                if (from !== index)
                    rows.move(from, index, 1);

                rows.set(index, process);
            }
        });
    }

    function formatKiB(kib) {
        const gib = kib / 1048576;
        return gib >= 1 ? gib.toFixed(1) + "G" : Math.round(kib / 1024) + "M";
    }

    // A process's row: as tall as its name.
    readonly property real rowHeight: Math.ceil(rowFont.height)

    implicitWidth: 380
    onProcessesChanged: syncRows()
    Component.onCompleted: syncRows()
    implicitHeight: column.implicitHeight + 28
    ServiceRef {
        service: SystemDetails
        active: monitor.active
    }

    // The busiest processes, in the order shown.
    ListModel {
        id: rows
    }

    FontMetrics {
        id: rowFont

        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
    }

    // A section's reading, facing its title.
    component SectionTitle: Text {
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
        font.weight: Font.Bold
    }

    component IconTitle: IconText {
        heading: true
        iconSize: Metrics.text.emphasis
        font.pixelSize: Metrics.text.small
        font.weight: Font.Bold
    }

    component IconDetail: IconText {
        color: Colors.secondary
        font.pixelSize: Metrics.text.body
        font.weight: Font.Normal
    }

    component Detail: Text {
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.features: {
            "tnum": 1
        }
    }

    component Section: Item {
        default property alias content: sectionColumn.data

        Layout.fillWidth: true
        implicitHeight: sectionColumn.implicitHeight + 24

        GlassSurface {
            radius: Metrics.cardRadius
        }

        ColumnLayout {
            id: sectionColumn

            anchors.fill: parent
            anchors.margins: Metrics.spacing.large
            spacing: Metrics.spacing.normal
        }

    }

    // A column to sort the processes by. The light behind the chosen one is the
    // section's, so it can travel between them.
    component SortChip: Item {
        id: chip

        required property string label
        required property bool chosen
        readonly property bool hovered: chipHover.hovered

        signal picked()

        implicitWidth: chipLabel.implicitWidth + 18
        implicitHeight: 22

        // Plain glass under the pointer, on the column not chosen.
        GlassSurface {
            radius: height / 2
            hovered: true
            opacity: chip.hovered && !chip.chosen ? 1 : 0

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: chip.label
            color: chip.chosen ? Colors.over(Colors.primary) : Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.small
            font.weight: Font.Bold

            ColorFade on color {
                token: Motion.color.normal
            }

        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                chipBounce.restart();
                chip.picked();
            }
        }

        BounceAnimation {
            id: chipBounce

            target: chipLabel
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
            ctx.strokeStyle = Colors.primary;
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(startX, height);
            ctx.closePath();
            const fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Colors.alpha(Colors.primary, 0.28));
            fill.addColorStop(1, Colors.alpha(Colors.primary, 0));
            ctx.fillStyle = fill;
            ctx.fill();
        }
    }

    ColumnLayout {
        id: column

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Metrics.spacing.large
        spacing: Metrics.spacing.normal

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing.normal

                IconTitle {
                    icon: "memory"
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
                spacing: Metrics.spacing.small

                Repeater {
                    model: SystemStats.coreUsage.length

                    Rectangle {
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: 24
                        radius: 4
                        color: Colors.alpha(Colors.light, 0.08)

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.max(radius * 2, parent.height * (SystemStats.coreUsage[parent.index] || 0))
                            radius: parent.radius
                            color: Colors.primary
                            opacity: 0.35 + 0.65 * (SystemStats.coreUsage[parent.index] || 0)

                            Behavior on height {
                                Anim {
                                    token: Motion.resize.large
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
                    icon: "thermostat"
                    text: SystemStats.temperature
                }

                IconDetail {
                    icon: String.fromCodePoint(0xf04c5)
                    text: SystemDetails.frequency
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing.normal

                IconTitle {
                    icon: "memory_alt"
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
                    color: SystemStats.swapTotal > 0 ? Colors.secondary : Colors.alpha(Colors.secondary, 0.5)
                }

            }

        }

        Section {
            RowLayout {
                Layout.fillWidth: true
                spacing: Metrics.spacing.normal

                IconTitle {
                    Layout.fillWidth: true
                    icon: "list"
                    text: "Processes"
                }

                // One light for the column the processes are sorted by. Each edge goes
                // from 0 on the first chip to 1 on the second: the one ahead sets off at
                // once and the other lingers, so it stretches over like the workspaces'.
                Item {
                    id: sortChoice

                    readonly property int chosen: monitor.processSort === "cpu" ? 0 : 1
                    property real leftEdge: chosen
                    property real rightEdge: chosen

                    implicitWidth: sortChips.implicitWidth
                    implicitHeight: sortChips.implicitHeight

                    Item {
                        x: cpuChip.x + (memoryChip.x - cpuChip.x) * sortChoice.leftEdge
                        width: cpuChip.x + cpuChip.width + (memoryChip.x + memoryChip.width - cpuChip.x - cpuChip.width) * sortChoice.rightEdge - x
                        height: parent.height

                        GlassSurface {
                            radius: height / 2
                            hovered: cpuChip.chosen ? cpuChip.hovered : memoryChip.hovered
                            backgroundColor: Colors.alpha(Colors.primary, hovered ? 0.95 : 0.8)
                            lit: true

                            ColorFade on backgroundColor {
                                token: Motion.color.small
                            }

                        }

                    }

                    Row {
                        id: sortChips

                        spacing: Metrics.spacing.normal

                        SortChip {
                            id: cpuChip

                            chosen: monitor.processSort === "cpu"
                            onPicked: monitor.processSort = "cpu"
                            label: "CPU"
                        }

                        SortChip {
                            id: memoryChip

                            chosen: monitor.processSort === "memory"
                            onPicked: monitor.processSort = "memory"
                            label: "RAM"
                        }

                    }

                    Behavior on leftEdge {
                        id: leftSlide

                        Anim {
                            token: leftSlide.targetValue === 1 ? Motion.stretch.back : Motion.stretch.front
                        }

                    }

                    Behavior on rightEdge {
                        id: rightSlide

                        Anim {
                            token: rightSlide.targetValue === 1 ? Motion.stretch.front : Motion.stretch.back
                        }

                    }

                }

            }

            // Each row follows its process: it glides to its new place when the sort or
            // the load reorders them, and fades as its process comes or goes. Five rows'
            // room even while the list loads, so the card keeps its height.
            ListView {
                Layout.fillWidth: true
                implicitHeight: 5 * monitor.rowHeight + 4 * spacing
                interactive: false
                spacing: Metrics.spacing.normal

                model: rows

                delegate: RowLayout {
                    id: row

                    required property string name
                    required property real cpu
                    required property real memory

                    width: ListView.view.width
                    height: monitor.rowHeight
                    spacing: Metrics.spacing.normal

                    Text {
                        Layout.fillWidth: true
                        text: row.name
                        color: Colors.primary
                        elide: Text.ElideRight
                        font: rowFont.font
                    }

                    // The sorted column in the accent, the other one in the secondary color.
                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        // top counts a share of one core, the card a share of the whole CPU like btop.
                        text: (row.cpu / Math.max(1, SystemStats.coreUsage.length)).toFixed(1) + "%"
                        color: monitor.processSort === "cpu" ? Colors.primary : Colors.secondary

                        ColorFade on color {
                            token: Motion.color.normal
                        }

                    }

                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        text: monitor.formatKiB(row.memory)
                        color: monitor.processSort === "memory" ? Colors.primary : Colors.secondary

                        ColorFade on color {
                            token: Motion.color.normal
                        }

                    }
                }

                // A newcomer waits for what leaves its place, so two names never cross
                // over each other.
                add: Transition {
                    SequentialAnimation {
                        PropertyAction {
                            property: "opacity"
                            value: 0
                        }

                        PauseAnimation {
                            duration: Motion.leave.small.duration
                        }

                        Anim {
                            property: "opacity"
                            to: 1
                            token: Motion.enter.normal
                        }

                    }

                }

                remove: Transition {
                    Anim {
                        property: "opacity"
                        to: 0
                        token: Motion.leave.small
                    }

                }

                move: Transition {
                    Anim {
                        property: "y"
                        token: Motion.move.large
                    }

                }

                displaced: Transition {
                    Anim {
                        property: "y"
                        token: Motion.move.large
                    }

                }

            }

        }

    }

}
