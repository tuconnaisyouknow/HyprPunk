import QtQuick
import Quickshell.Hyprland

// The bar's workspace buttons: this screen's workspaces from 1 to 10, empty ones
// hidden unless you're on them. The mauve highlight slides to the active one, and the
// one under the pointer is passed on to the preview card.
Item {
    id: workspaceSwitcher

    required property var screen
    // Font Awesome glyph of each workspace, by id.
    required property var icons
    // The workspace under the pointer, null when there is none.
    property var hoveredWorkspace: null
    readonly property var hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property var workspaces: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor === workspaceSwitcher.hyprlandMonitor && (workspace.active || workspace.toplevels.values.length > 0);
    })
    property int activeButtonIndex: -1
    property int activeWorkspaceId: -1
    property bool activeWorkspaceOccupied: false
    property real fallbackSlideX: 0
    property real fallbackOpacity: 1

    function selectWorkspace(workspaceId, visualIndex, occupied) {
        const previousWorkspaceId = activeWorkspaceId;
        const previousIndex = activeButtonIndex;
        const previousWorkspaceOccupied = activeWorkspaceOccupied;
        activeWorkspaceId = workspaceId;
        activeButtonIndex = visualIndex;
        activeWorkspaceOccupied = occupied;
        const sameVisualPosition = previousIndex === visualIndex;
        const emptyToOccupiedAfter = !previousWorkspaceOccupied && occupied && workspaceId > previousWorkspaceId;
        if (previousWorkspaceId >= 0 && previousWorkspaceId !== workspaceId && (sameVisualPosition || emptyToOccupiedAfter)) {
            fallbackTransition.stop();
            fallbackSlideX = workspaceId > previousWorkspaceId ? 22 : -22;
            fallbackOpacity = 0.25;
            fallbackTransition.start();
        }
    }

    function clearSelectionIfUnfocused() {
        for (const workspace of workspaces) {
            if (workspace.focused)
                return ;

        }
        activeButtonIndex = -1;
        activeWorkspaceId = -1;
        activeWorkspaceOccupied = false;
    }

    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: workspaceRow.implicitHeight
    opacity: fallbackOpacity

    ParallelAnimation {
        id: fallbackTransition

        NumberAnimation {
            target: workspaceSwitcher
            property: "fallbackSlideX"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: workspaceSwitcher
            property: "fallbackOpacity"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        z: 0
        x: workspaceSwitcher.activeButtonIndex >= 0 ? workspaceSwitcher.activeButtonIndex * (31 + workspaceRow.spacing) : 0
        y: 0
        width: 44
        height: 31
        radius: height / 2
        color: Theme.mauve
        visible: workspaceSwitcher.activeButtonIndex >= 0

        Behavior on x {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }

        }

    }

    Row {
        id: workspaceRow

        z: 1
        spacing: 2

        Repeater {
            id: workspaceRepeater

            model: workspaceSwitcher.workspaces

            WorkspaceButton {
                id: workspaceButton

                required property var modelData
                required property int index

                workspaceId: modelData.id
                icon: workspaceSwitcher.icons[modelData.id]
                active: modelData.focused
                occupied: modelData.toplevels.values.length > 0
                drawActiveBackground: false
                onActivated: modelData.activate()
                onActiveChanged: {
                    if (active)
                        workspaceSwitcher.selectWorkspace(workspaceId, index, occupied);
                    else
                        Qt.callLater(workspaceSwitcher.clearSelectionIfUnfocused);
                }
                onHoveredChanged: {
                    if (hovered)
                        workspaceSwitcher.hoveredWorkspace = modelData;
                    else if (workspaceSwitcher.hoveredWorkspace === modelData)
                        workspaceSwitcher.hoveredWorkspace = null;
                }
                onOccupiedChanged: {
                    if (active)
                        workspaceSwitcher.activeWorkspaceOccupied = occupied;

                }
                Component.onCompleted: {
                    if (active)
                        workspaceSwitcher.selectWorkspace(workspaceId, index, occupied);

                }
            }

        }

    }

    transform: Translate {
        x: workspaceSwitcher.fallbackSlideX
    }

}
