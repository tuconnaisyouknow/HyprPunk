import QtQuick
import qs.components
import qs.services
import qs.theme

// The machine's load, in the open island over the control center's icons (IslandView):
// the processor over the memory, each a gauge, no figures: the system monitor has them,
// and a click opens it.
IslandBlock {
    id: line

    readonly property real slot: Metrics.islandBlockHeight
    // The gauges start together past the longer name.
    readonly property real labelWidth: Math.ceil(Math.max(cpuName.width, memoryName.width)) + Metrics.spacing.normal

    radius: Metrics.spacing.normal

    Rectangle {
        width: line.slot
        height: line.slot
        radius: line.radius
        color: Colors.alpha(Colors.secondary, 0.1)

        Icon {
            x: (parent.width - implicitWidth) / 2
            y: (parent.height - implicitHeight) / 2
            text: "memory"
            color: Colors.secondary
            size: Metrics.text.title
        }

    }

    Column {
        x: line.slot + Metrics.spacing.normal
        y: (line.height - height) / 2
        width: line.width - x - Metrics.spacing.large

        Gauge {
            label: cpuName.text
            labelWidth: line.labelWidth
            share: SystemStats.cpuUsage
        }

        Gauge {
            label: memoryName.text
            labelWidth: line.labelWidth
            share: SystemStats.memoryTotal > 0 ? SystemStats.memoryUsed / SystemStats.memoryTotal : 0
        }

    }

    TextMetrics {
        id: cpuName

        font.family: Metrics.font
        font.pixelSize: Metrics.text.small
        font.weight: Font.DemiBold
        text: "CPU"
    }

    TextMetrics {
        id: memoryName

        font: cpuName.font
        text: "RAM"
    }

    // What it measures, and how much of it is used, as a fill (an amount).
    component Gauge: Item {
        id: gauge

        property string label
        property real share
        property real labelWidth

        width: parent.width
        height: labelText.implicitHeight

        Text {
            id: labelText

            width: gauge.labelWidth
            text: gauge.label
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.small
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: track

            x: labelText.width
            y: (gauge.height - height) / 2
            width: gauge.width - x
            height: 4
            radius: height / 2
            color: Colors.alpha(Colors.secondary, 0.2)

            Rectangle {
                width: Math.max(track.height, track.width * Math.max(0, Math.min(1, gauge.share)))
                height: track.height
                radius: track.radius
                color: Colors.primary

                // Eased from one second's reading to the next, only while you see it.
                Behavior on width {
                    enabled: track.visible

                    Anim {
                        token: Motion.resize.small
                    }

                }

            }

        }

    }

}
