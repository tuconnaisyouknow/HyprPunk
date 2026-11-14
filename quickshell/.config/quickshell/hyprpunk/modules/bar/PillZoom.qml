import QtQuick

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
    // The same few pixels for every size, at most 10% for the small ones.
    property real squeezed: pressed ? Math.max(0.9, 1 - 8 / Math.max(pill.width, 1)) : 1

    origin.x: pill.width / 2
    origin.y: pill.height / 2
    xScale: grown * squeezed
    yScale: grown * squeezed
    // How far that draws the pill past its place on each side, where the cards that grow
    // out of it start and end.
    readonly property real spreadX: pill.width * (xScale - 1) / 2
    readonly property real spreadY: pill.height * (yScale - 1) / 2

    Behavior on grown {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Behavior on squeezed {
        NumberAnimation {
            duration: zoom.pressed ? 90 : 450
            easing.type: zoom.pressed ? Easing.OutQuad : Easing.OutBack
            easing.overshoot: 4
        }

    }

}
