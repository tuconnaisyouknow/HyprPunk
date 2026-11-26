import QtQuick
import qs.components
import qs.theme

// One workspace in the bar or the open island, shown as a dot: its place in the row says which one it is.
// It always exists, and takes its place only while the row asks for it: it opens up as
// it's needed and closes as it isn't. The light that shows the one you're on isn't its
// own (WorkspaceSwitcher): the dot only gives way as it passes, since neon's glass would
// show it through.
Item {
    id: button

    required property int workspaceId
    // Its workspace, null while it's empty and nobody's on it.
    required property var workspace
    // It has its place in the row.
    required property bool shown
    // The room kept after it in the row.
    required property real gap
    // The light's edges, from this button's left edge, and how much of it is on.
    required property real lightLeft
    required property real lightRight
    required property real lightOpacity
    // Smaller, for the open island (WorkspaceSwitcher.compact), and taking the pointer.
    property bool compact: false
    property bool interactive: true
    readonly property bool active: workspace !== null && workspace.focused
    readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
    // A window there asks for you.
    readonly property bool urgent: workspace !== null && workspace.urgent && !active
    readonly property bool hovered: shown && hover.hovered
    readonly property int size: compact ? 24 : 32
    // Room for a dot at rest, for the light once you're on it.
    readonly property int restWidth: compact ? 14 : 24
    readonly property int activeWidth: compact ? 24 : 36
    readonly property int dotSize: compact ? 8 : 10
    // How much a dot grows under the pointer: the light is that tall, so pointing at a
    // dot already shows the size it would take.
    readonly property real pointedScale: 1.5
    // Its place in the row, from none to a dot's, and what being active adds to it. Both
    // take the same time both ways, so one closing as another opens leaves the pill's
    // width alone.
    property real reveal: shown ? 1 : 0
    property real extra: active ? activeWidth - restWidth : 0
    // The shape the light takes on it.
    readonly property real shapeWidth: reveal * restWidth + extra
    // The dot grows under the pointer.
    property real grow: hovered ? pointedScale : 1

    // The dot, cut where the light's edge stands: the part outside stays, the part under
    // it goes out with the light. Neon's glass would show it through.
    component DotPart: Item {
        id: part

        // The span it keeps, in its row's place.
        property real from
        property real to
        required property real place
        required property real diameter
        required property real dotScale
        required property color color

        x: Math.max(0, Math.min(place, from))
        width: Math.max(0, Math.min(place, to) - x)
        height: parent.height
        clip: true

        Rectangle {
            x: (part.place - width) / 2 - part.x
            anchors.verticalCenter: parent.verticalCenter
            width: part.diameter
            height: width
            radius: width / 2
            scale: part.dotScale
            color: part.color
        }

    }

    signal activated()

    implicitWidth: shapeWidth + reveal * gap
    implicitHeight: size
    visible: implicitWidth > 0

    // Where the light rests on it, the dot at its center.
    Item {
        id: shape

        width: button.shapeWidth
        height: button.size

        // It breathes until you go and see.
        SequentialAnimation on opacity {
            running: button.urgent
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    shape.opacity = 1;

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

        // Empty reads as off, a window asking for you as the accent.
        property color dotColor: button.urgent ? Colors.primary : button.occupied ? Colors.secondary : Colors.alpha(Colors.secondary, 0.5)

        ColorFade on dotColor {
            token: Motion.color.normal
        }

        // Outside the light, on the side it isn't.
        DotPart {
            readonly property bool lightAfter: button.lightLeft + button.lightRight > shape.width

            from: lightAfter ? 0 : button.lightRight
            to: lightAfter ? button.lightLeft : shape.width
            place: shape.width
            diameter: button.dotSize
            dotScale: button.grow * button.reveal
            color: shape.dotColor
        }

        DotPart {
            from: button.lightLeft
            to: button.lightRight
            place: shape.width
            diameter: button.dotSize
            dotScale: button.grow * button.reveal
            color: shape.dotColor
            opacity: 1 - button.lightOpacity
        }

    }


    // The gap after it is its own too, so the row has no dead spot: the button is all of
    // its room. Handlers rather than a MouseArea, like the island's blocks: inside the
    // island, a MouseArea saw the pointer but never got the press.
    HoverHandler {
        id: hover

        enabled: button.shown && button.interactive
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: button.shown && button.interactive
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: button.activated()
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

    Behavior on grow {
        Anim {
            token: Motion.pop
        }

    }

}
