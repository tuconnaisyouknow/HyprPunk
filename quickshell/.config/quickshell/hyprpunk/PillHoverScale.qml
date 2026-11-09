import QtQuick

// How a pill you can click grows under the pointer: the same few pixels as the control
// center's blocks (ControlBlock), with its glass lit up beside it. A transform, so it adds
// to the pill's own scale (the player's pulse on a new track).
Scale {
    required property Item pill
    // The pointer is on the pill and the pill answers it.
    property bool active: false
    readonly property real amount: active ? 1 + 6 / Math.max(pill.width, 1) : 1

    origin.x: pill.width / 2
    origin.y: pill.height / 2
    xScale: amount
    yScale: amount

    Behavior on xScale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Behavior on yScale {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

}
