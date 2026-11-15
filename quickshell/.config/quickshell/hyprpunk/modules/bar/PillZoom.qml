import QtQuick
import qs.components
import qs.theme

// How a pill you can click answers the pointer, like the control center's blocks: it
// grows a few pixels under it, and squeezes while pressed, springing back a touch too far
// on release (BounceAnimation). A transform, so it adds to the pill's own scale (the
// player's pulse on a new track).
Scale {
    id: zoom

    required property Item pill
    // The pointer is on the pill and the pill answers it.
    property bool active: false
    property bool pressed: false
    property real grown: active ? 1 + 6 / Math.max(pill.width, 1) : 1
    property real squeezed: pressed ? Motion.squeeze(pill.width) : 1

    origin.x: pill.width / 2
    origin.y: pill.height / 2
    xScale: grown * squeezed
    yScale: grown * squeezed
    // How far that draws the pill past its place on each side, where the cards that grow
    // out of it start and end.
    readonly property real spreadX: pill.width * (xScale - 1) / 2
    readonly property real spreadY: pill.height * (yScale - 1) / 2

    Behavior on grown {
        Anim {
            token: Motion.move.small
        }

    }

    Behavior on squeezed {
        NumberAnimation {
            duration: zoom.pressed ? Motion.bounce.pressDuration : Motion.bounce.releaseDuration
            easing.type: zoom.pressed ? Motion.bounce.pressEasing : Motion.bounce.releaseEasing
            easing.overshoot: Motion.bounce.overshoot
        }

    }

}
