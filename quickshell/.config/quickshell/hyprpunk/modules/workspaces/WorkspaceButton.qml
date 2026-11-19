import QtQuick
import qs.components
import qs.theme

// One workspace in the bar, shown by its icon. It always exists, and takes its place in
// the row only while it has a workspace to show: it opens up as one appears and closes
// as it goes. The light isn't its own (WorkspaceSwitcher): it only draws the part of
// its icon the light covers in the color written on a light.
Item {
    id: button

    required property int workspaceId
    required property string icon
    // Its workspace, null while there's none to show.
    required property var workspace
    // The room kept after it in the row.
    required property real gap
    // The light's edges, from this button's left edge, and how much of it is on.
    required property real lightLeft
    required property real lightRight
    required property real lightOpacity
    readonly property bool shown: workspace !== null
    readonly property bool active: shown && workspace.focused
    readonly property bool occupied: shown && workspace.toplevels.values.length > 0
    // A window there asks for you.
    readonly property bool urgent: shown && workspace.urgent && !active
    readonly property bool hovered: shown && mouse.containsMouse
    // A disc at rest, a capsule once you're on it.
    readonly property int size: 32
    readonly property int activeWidth: 44
    // Its place in the row, from none to a disc, and what being active adds to it. Both
    // take the same time both ways, so one closing as another opens (from an empty
    // workspace to another) leaves the pill's width alone.
    property real reveal: shown ? 1 : 0
    property real extra: active ? activeWidth - size : 0
    // The shape the light takes on it.
    readonly property real shapeWidth: reveal * size + extra
    // The icon's size: a touch smaller at rest, growing with its place in the row.
    property real rest: active || hovered ? 1 : 0.94
    readonly property real glyphScale: rest * reveal

    signal activated()

    implicitWidth: shapeWidth + reveal * gap
    implicitHeight: size
    visible: implicitWidth > 0
    // An empty workspace you aren't on: the one another screen left this one on.
    opacity: occupied || active ? 1 : 0.55

    Item {
        id: shape

        width: button.shapeWidth
        height: button.size
        // Gone before its place has closed, where the icon would linger as a dot.
        opacity: button.reveal

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: button.hovered && !button.active ? Colors.surface1 : Colors.alpha(Colors.surface1, 0)

            ColorFade on color {
                token: Motion.color.normal
            }

        }

        WorkspaceGlyph {
            id: glyph

            anchors.centerIn: parent
            workspaceId: button.workspaceId
            text: button.icon
            scale: button.glyphScale
            color: Colors.primary

            // It breathes until you go and see.
            SequentialAnimation on opacity {
                running: button.urgent
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        glyph.opacity = 1;

                }

                NumberAnimation {
                    to: 0.3
                    duration: Motion.pulse.duration
                    easing.type: Motion.pulse.easing
                }

                NumberAnimation {
                    to: 1
                    duration: Motion.pulse.duration
                    easing.type: Motion.pulse.easing
                }

            }

        }

        // The icon again as it's written on a light, cut to where the light is: it
        // changes color exactly as the light passes over it. Neon writes on a light in
        // the light's own color, so there's nothing to redraw.
        Item {
            x: Math.max(0, button.lightLeft)
            width: Math.min(shape.width, button.lightRight) - x
            height: shape.height
            visible: width > 0 && button.lightOpacity > 0 && !Colors.emits
            opacity: button.lightOpacity
            clip: true

            WorkspaceGlyph {
                x: glyph.x - parent.x
                y: glyph.y
                workspaceId: button.workspaceId
                text: button.icon
                scale: button.glyphScale
                color: Colors.over(Colors.primary)
            }

        }

    }

    // The gap after it is its own too, so the row has no dead spot.
    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: button.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }

    Behavior on reveal {
        Anim {
            token: Motion.resize.normal
        }

    }

    Behavior on extra {
        Anim {
            token: Motion.resize.normal
        }

    }

    Behavior on rest {
        Anim {
            token: Motion.pop
        }

    }

    Behavior on opacity {
        Anim {
            token: Motion.color.small
        }

    }

}
