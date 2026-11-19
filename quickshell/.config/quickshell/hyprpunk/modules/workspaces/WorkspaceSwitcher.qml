import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.theme

// The bar's workspace buttons: this screen's workspaces from 1 to 10, empty ones
// hidden unless you're on them. One light shows the one you're on. It's the only thing
// that travels: it stretches to the next workspace and the icons take its color as it
// passes, while each button only opens or closes its own place. The button under the
// pointer is passed on to the preview card.
Item {
    id: workspaceSwitcher

    required property var screen
    // Font Awesome glyph of each workspace, by id.
    required property var icons
    // The workspace under the pointer, null when there is none.
    readonly property var hoveredWorkspace: hoveredButton !== null ? hoveredButton.workspace : null
    property Item hoveredButton: null
    readonly property var hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property var workspaces: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor === workspaceSwitcher.hyprlandMonitor && (workspace.active || workspace.toplevels.values.length > 0);
    })
    // The one you're on, null while you're on another screen.
    readonly property var focusedWorkspace: workspaces.find((workspace) => {
        return workspace.focused;
    }) || null

    function followFocus() {
        if (focusedWorkspace !== null)
            light.moveTo(buttons.itemAt(focusedWorkspace.id - 1));

    }

    // The last gap is nobody's.
    implicitWidth: workspaceRow.implicitWidth - Metrics.spacing.hairline
    implicitHeight: workspaceRow.implicitHeight
    onFocusedWorkspaceChanged: followFocus()
    Component.onCompleted: followFocus()

    // It rests on the button of the workspace you're on, and goes out where it stands
    // when you leave for another screen. On its way to another button each edge goes
    // from the edge of the button it left to the edge of the one it's going to, the
    // front one first. Both ends follow their buttons as the row moves, so the light
    // never trails behind a button that closes. A move you interrupt sets off again
    // from where the light is.
    Light {
        id: light

        // The button it's on or going to, and the one it left.
        property Item target: null
        property Item origin: null
        // How far its edges were from the button it left, when a move was interrupted.
        property real leftOffset: 0
        property real rightOffset: 0
        // How far along each edge is.
        property real front: 1
        property real back: 1
        // Going right, so its right edge leads.
        property bool forward: true
        readonly property real fromLeft: origin !== null ? origin.x + leftOffset : 0
        readonly property real fromRight: origin !== null ? origin.x + origin.shapeWidth + rightOffset : 0
        readonly property real leftEdge: target !== null ? fromLeft + (target.x - fromLeft) * (forward ? back : front) : 0
        readonly property real rightEdge: target !== null ? fromRight + (target.x + target.shapeWidth - fromRight) * (forward ? front : back) : 0

        function moveTo(button) {
            if (button === null || button === target)
                return ;

            travel.stop();
            // Nothing to travel from while it's out: it comes on in place.
            if (target === null || opacity === 0) {
                target = button;
                origin = button;
                leftOffset = 0;
                rightOffset = 0;
                front = 1;
                back = 1;
                return ;
            }
            const left = leftEdge - target.x;
            const right = rightEdge - target.x - target.shapeWidth;
            forward = button.workspaceId > target.workspaceId;
            origin = target;
            leftOffset = left;
            rightOffset = right;
            front = 0;
            back = 0;
            target = button;
            travel.start();
        }

        x: leftEdge
        width: rightEdge - leftEdge
        height: target !== null ? target.size : 0
        visible: target !== null
        // The whole light, glass included: in neon the unlit tube would stay otherwise.
        opacity: workspaceSwitcher.focusedWorkspace !== null ? 1 : 0

        ParallelAnimation {
            id: travel

            Anim {
                target: light
                property: "front"
                to: 1
                token: Motion.stretch.front
            }

            Anim {
                target: light
                property: "back"
                to: 1
                token: Motion.stretch.back
            }

        }

        Behavior on opacity {
            Anim {
                token: Motion.color.normal
            }

        }

    }

    Row {
        id: workspaceRow

        Repeater {
            id: buttons

            model: 10

            WorkspaceButton {
                id: button

                required property int index

                workspaceId: index + 1
                icon: workspaceSwitcher.icons[workspaceId]
                workspace: workspaceSwitcher.workspaces.find((workspace) => {
                    return workspace.id === workspaceId;
                }) || null
                gap: Metrics.spacing.hairline
                lightLeft: light.x - x
                lightRight: light.x + light.width - x
                lightOpacity: light.visible ? light.opacity : 0
                onActivated: workspace.activate()
                onHoveredChanged: {
                    if (hovered)
                        workspaceSwitcher.hoveredButton = button;
                    else if (workspaceSwitcher.hoveredButton === button)
                        workspaceSwitcher.hoveredButton = null;
                }
            }

        }

    }

}
