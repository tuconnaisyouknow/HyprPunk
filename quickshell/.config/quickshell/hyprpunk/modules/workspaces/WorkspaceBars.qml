import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.theme

// Your workspaces as short upright bars, for the open island (IslandView), where the
// bar's dots would take too much room: the one you're on stands tallest and lit, the ones
// with windows a little taller than the empty ones. Like the dots, every workspace from 1
// to the last one in use here, but those another screen holds. A click takes you there.
Row {
    id: bars

    required property var screen
    property bool interactive: true
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspaces: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor === bars.monitor && (workspace.active || workspace.toplevels.values.length > 0);
    })
    readonly property int last: workspaces.reduce((highest, workspace) => {
        return Math.max(highest, workspace.id);
    }, 0)
    readonly property var elsewhere: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor !== bars.monitor;
    }).map((workspace) => {
        return workspace.id;
    })
    readonly property int barWidth: 4
    // Each bar's room, wider than the bar so it's easy to point at.
    readonly property int slotWidth: barWidth + spacing
    // As wide as with all ten: the island keeps one size however many you use.
    readonly property int fullWidth: 10 * slotWidth

    spacing: Metrics.spacing.small

    Repeater {
        model: 10

        Item {
            id: slot

            required property int index
            readonly property int workspaceId: index + 1
            readonly property var workspace: bars.workspaces.find((workspace) => {
                return workspace.id === slot.workspaceId;
            }) || null
            readonly property bool active: workspace !== null && workspace.focused
            readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
            // A window there asks for you.
            readonly property bool urgent: workspace !== null && workspace.urgent && !active

            visible: workspaceId <= bars.last && !bars.elsewhere.includes(workspaceId)
            width: bars.barWidth
            height: Metrics.islandBlockHeight

            // The pointer takes the bar's room and the gaps around it.
            Item {
                anchors.centerIn: parent
                width: bars.slotWidth
                height: parent.height

                HoverHandler {
                    id: hover

                    enabled: bars.interactive
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: bars.interactive
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    // An empty workspace has nothing to activate yet: Hyprland makes it.
                    onTapped: Hyprland.dispatch("hl.dsp.focus({ workspace = " + slot.workspaceId + " })")
                }

            }

            Rectangle {
                width: bars.barWidth
                height: (slot.active ? 18 : slot.occupied ? 10 : 6) + (hover.hovered && !slot.active ? 4 : 0)
                y: (parent.height - height) / 2
                radius: width / 2
                color: slot.urgent ? Colors.primary : slot.occupied ? Colors.secondary : Colors.alpha(Colors.secondary, 0.5)

                ColorFade on color {
                    token: Motion.color.small
                }

                Behavior on height {
                    Anim {
                        token: Motion.move.small
                    }

                }

                // The workspace you're on: a light, glowing in neon.
                Light {
                    anchors.fill: parent
                    radius: width / 2
                    color: Colors.alpha(Colors.primary, slot.active ? 1 : 0)

                    ColorFade on color {
                        token: Motion.color.small
                    }

                }

            }

        }

    }

}
