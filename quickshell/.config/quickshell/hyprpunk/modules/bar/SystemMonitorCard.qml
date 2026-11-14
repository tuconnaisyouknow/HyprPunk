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

    function formatKiB(kib) {
        const gib = kib / 1048576;
        return gib >= 1 ? gib.toFixed(1) + "G" : Math.round(kib / 1024) + "M";
    }

    implicitWidth: 380
    implicitHeight: column.implicitHeight + 28
    ServiceRef {
        service: SystemDetails
        active: monitor.active
    }

    component SectionTitle: Text {
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
        font.weight: Font.Bold
    }

    component IconTitle: IconText {
        font.pixelSize: Metrics.text.emphasis
        font.weight: Font.Bold
    }

    component IconDetail: IconText {
        color: Colors.secondary
        font.pixelSize: Metrics.text.body
        font.weight: Font.Normal
        font.features: {
            "tnum": 1
        }
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
                    icon: ""
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

                        // Accent glass when selected, plain glass on hover otherwise.
                        GlassSurface {
                            radius: parent.radius
                            hovered: chipHover.hovered
                            opacity: sortChip.selected || chipHover.hovered ? 1 : 0
                            backgroundColor: sortChip.selected ? Colors.alpha(Colors.primary, chipHover.hovered ? 0.95 : 0.8) : "transparent"
                        }

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            text: sortChip.modelData.label
                            color: sortChip.selected ? Colors.base : Colors.secondary
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.small
                            font.weight: Font.Bold
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            gesturePolicy: TapHandler.ReleaseWithinBounds
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
                    spacing: Metrics.spacing.normal

                    Text {
                        Layout.fillWidth: true
                        text: parent.process !== null ? parent.process.name : ""
                        color: Colors.primary
                        elide: Text.ElideRight
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                    }

                    // The sorted column in the accent, the other one in the secondary color.
                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        // top counts a share of one core, the card a share of the whole CPU like btop.
                        text: parent.process !== null ? (parent.process.cpu / Math.max(1, SystemStats.coreUsage.length)).toFixed(1) + "%" : ""
                        color: monitor.processSort === "cpu" ? Colors.primary : Colors.secondary
                    }

                    Detail {
                        Layout.preferredWidth: 48
                        horizontalAlignment: Text.AlignRight
                        text: parent.process !== null ? monitor.formatKiB(parent.process.memory) : ""
                        color: monitor.processSort === "memory" ? Colors.primary : Colors.secondary
                    }

                }

            }

        }

    }

}
