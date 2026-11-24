import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.theme

// The bar's workspace buttons: a dot for each workspace from 1 to the last one in use
// here, all but the ones another screen holds, so a dot's place says which workspace it
// is. One light shows the
// one you're on. It's the only thing that travels: it stretches to the next workspace
// over the dots, while each button only opens or closes its own place. The button under
// the pointer is passed on to the preview card.
Item {
    id: workspaceSwitcher

    required property var screen
    // The workspace under the pointer, null when there is none.
    readonly property var hoveredWorkspace: hoveredButton !== null ? hoveredButton.workspace : null
    property Item hoveredButton: null
    readonly property var hyprlandMonitor: Hyprland.monitorFor(screen)
    readonly property var workspaces: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor === workspaceSwitcher.hyprlandMonitor && (workspace.active || workspace.toplevels.values.length > 0);
    })
    // The row ends there, on the workspace you're on if it's further.
    readonly property int last: workspaces.reduce((highest, workspace) => {
        return Math.max(highest, workspace.id);
    }, 0)
    // The workspaces other screens hold, by id: their dots make way.
    readonly property var elsewhere: Hyprland.workspaces.values.filter((workspace) => {
        return workspace.id > 0 && workspace.id <= 10 && workspace.monitor !== workspaceSwitcher.hyprlandMonitor;
    }).map((workspace) => {
        return workspace.id;
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

        // The dot stretched, as thick as the dots.
        readonly property int thickness: target !== null ? target.dotSize : 0

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
        y: target !== null ? (target.size - thickness) / 2 : 0
        z: 1
        height: thickness
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
                workspace: workspaceSwitcher.workspaces.find((workspace) => {
                    return workspace.id === workspaceId;
                }) || null
                shown: workspaceId <= workspaceSwitcher.last && !workspaceSwitcher.elsewhere.includes(workspaceId)
                gap: Metrics.spacing.hairline
                lightLeft: light.x - x
                lightRight: light.x + light.width - x
                lightOpacity: light.visible ? light.opacity : 0
                // An empty workspace has nothing to activate yet: Hyprland makes it.
                onActivated: Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })")
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
