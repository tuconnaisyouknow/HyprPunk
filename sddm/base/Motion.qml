pragma Singleton

import QtQuick

// How the login screen moves: the shell's own timings (its theme/Motion.qml), for the
// moves the two share, each named by what the element does. Keep both alike.
QtObject {
    // A pill growing under the pointer, or taking a new name's width.
    readonly property var move: ({
        "duration": 140,
        "easing": Easing.OutCubic
    })
    // Appearing: decelerates into place.
    readonly property var enter: ({
        "duration": 280,
        "easing": Easing.OutCubic
    })
    // A color or an opacity changing in place.
    readonly property var color: move
    // The island's parts coming and going where they stand: eased in as well as out, so
    // one change flows on from another.
    readonly property var swap: ({
        "duration": 300,
        "easing": Easing.InOutQuad
    })
    // The answer to a press: squeezed a little, then springing back a touch too far.
    readonly property QtObject bounce: QtObject {
        readonly property int pressDuration: 90
        readonly property int pressEasing: Easing.OutQuad
        readonly property int releaseDuration: 450
        readonly property int releaseEasing: Easing.OutBack
        readonly property real overshoot: 4
    }
    // A pill coming from above the bar: it falls into place and bounces.
    readonly property QtObject drop: QtObject {
        // High enough to be off screen.
        readonly property int height: 60
        readonly property int fallDuration: 700
        readonly property int fallEasing: Easing.OutBounce
    }
    // No, with a shake of the head: each swing smaller than the last, where the island
    // goes from its place.
    readonly property QtObject shake: QtObject {
        readonly property var swings: [-12, 10, -6, 0]
        readonly property int swingDuration: 60
        readonly property int duration: swings.length * swingDuration
    }
    // Something taking its size with a touch past it, then settling: a password's square.
    readonly property var pop: ({
        "duration": 200,
        "easing": Easing.OutBack
    })
    // A character of the clock turning to the next (RollingText): the new one rises from
    // below and lands a touch past its place.
    readonly property var roll: ({
        "duration": 450,
        "easing": Easing.OutBack,
        "overshoot": 1
    })
    // Words arriving on the machine (Decode): how long they take to settle, how often
    // they scramble anew on the way, and what they're scrambled into.
    readonly property QtObject decode: QtObject {
        readonly property int duration: 350
        readonly property int pace: 35
        readonly property string signs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    }
    // Between the pills arriving one after another.
    readonly property int stagger: 70
    // How long an action that can't be undone stays armed, and a refusal stays written.
    readonly property int armed: 3000
    readonly property int refusal: 2200

    // How far a press squeezes something that big: the same few pixels for every size,
    // at most 10% for the small ones.
    function squeeze(size) {
        return Math.max(0.9, 1 - 8 / Math.max(size, 1));
    }

}
