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
    // from where it stood to the edge of the one it's going to, the front one first.
    // Where it set off from is kept as a place in the row (a third into the second
    // button), not in pixels: the row opens and closes under it, and a place that
    // closes takes the light's edge along, so the light never leaves the row.
    Light {
        id: light

        // The dot stretched, as thick as a dot under the pointer.
        readonly property real thickness: target !== null ? target.dotSize * target.pointedScale : 0

        // The button it's on or going to.
        property Item target: null
        // Where its edges set off from, as places in the row: the button's index, and
        // how far into its room.
        property real leftPlace: 0
        property real rightPlace: 0
        // How far along each edge is.
        property real front: 1
        property real back: 1
        // Going right, so its right edge leads.
        property bool forward: true
        readonly property real fromLeft: at(leftPlace)
        readonly property real fromRight: at(rightPlace)
        readonly property real leftEdge: target !== null ? fromLeft + (target.x - fromLeft) * (forward ? back : front) : 0
        readonly property real rightEdge: target !== null ? fromRight + (target.x + target.shapeWidth - fromRight) * (forward ? front : back) : 0

        // A place in the row, from a point on it, and back.
        function placeOf(point) {
            for (let index = 0; index < buttons.count; index++) {
                const button = buttons.itemAt(index);
                if (button.implicitWidth > 0 && point < button.x + button.implicitWidth)
                    return index + Math.max(0, point - button.x) / button.implicitWidth;

            }
            return buttons.count;
        }

        function at(place) {
            const index = Math.min(Math.floor(place), buttons.count - 1);
            const button = buttons.itemAt(index);
            return button !== null ? button.x + (place - index) * button.implicitWidth : 0;
        }

        function moveTo(button) {
            if (button === null || button === target)
                return ;

            travel.stop();
            // Nothing to travel from while it's out: it comes on in place.
            if (target === null || opacity === 0) {
                target = button;
                front = 1;
                back = 1;
                return ;
            }
            leftPlace = placeOf(leftEdge);
            rightPlace = placeOf(rightEdge);
            forward = button.workspaceId > target.workspaceId;
            front = 0;
            back = 0;
            target = button;
            travel.start();
        }

        x: leftEdge
        width: rightEdge - leftEdge
        // On a whole pixel, or its edges blur.
        y: target !== null ? Math.round((target.size - thickness) / 2) : 0
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
