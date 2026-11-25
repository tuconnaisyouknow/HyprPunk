import QtQuick
import qs.components
import qs.services
import qs.theme

// The resources pill: memory and processor at a glance, opening the system monitor,
// which grows out of it like the player. Only on a bar wide enough for it.
Pill {
    id: monitorPill

    required property var bar
    readonly property alias popup: monitorPopup

    visible: monitorPill.bar.width >= 1200
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
        pill: monitorPill
        pillName: "monitor"
        panelName: "systemmonitor"
        screenState: monitorPill.bar.screenState
        // Nothing to open from on a bar too narrow for its pill.
        requestable: monitorPill.visible
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
