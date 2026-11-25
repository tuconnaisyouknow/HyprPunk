import QtQuick
import qs.components
import qs.services
import qs.theme

// The resources pill: memory and processor at a glance, opening the system monitor,
// which grows out of it like the player. Only on a bar wide enough for it. With the
// island alone in the bar, the system monitor is one of its cards.
Pill {
    id: monitorPill

    required property var bar
    readonly property alias popup: monitorPopup
    // The bar is wide enough for it.
    readonly property bool fits: bar.width >= 1200

    covered: monitorPill.bar.pillHidden("monitor")
    clickable: true
    onClicked: monitorPopup.togglePinned()

    IconText {
        icon: "memory_alt"
        text: SystemStats.memoryText
    }

    IconText {
        icon: "memory"
        text: Math.round(SystemStats.cpuUsage * 100) + "%"
    }

    PillPopup {
        id: monitorPopup

        cardLayer: monitorPill.bar.cardLayer
        pill: monitorPill.bar.islandOnly ? monitorPill.bar.islandItem : monitorPill
        pillName: monitorPill.bar.islandOnly ? "island" : "monitor"
        frame: monitorPill.bar.islandOnly ? monitorPill.bar.islandFrame : null
        align: monitorPill.bar.islandOnly ? Qt.AlignHCenter : Qt.AlignLeft
        panelName: "systemmonitor"
        screenState: monitorPill.bar.screenState
        // Nothing to open from on a bar too narrow for its pill, but the island.
        requestable: monitorPill.fits || monitorPill.bar.islandOnly
        implicitWidth: monitorContent.implicitWidth
        implicitHeight: monitorContent.implicitHeight

        SystemMonitorCard {
            id: monitorContent

            width: monitorPopup.width
            opacity: monitorPopup.showing ? 1 : 0
            active: monitorPopup.mapped

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

}
