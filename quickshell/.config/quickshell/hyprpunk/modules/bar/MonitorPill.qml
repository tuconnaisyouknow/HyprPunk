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
    opacity: monitorPill.bar.pillHidden("monitor") ? 0 : 1
    clickable: true
    onClicked: monitorPopup.togglePinned()

    IconText {
        icon: ""
        text: SystemStats.memoryText
    }

    IconText {
        icon: ""
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
            opacity: monitorPopup.expanded ? 1 : 0
            active: monitorPopup.mapped

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

}
