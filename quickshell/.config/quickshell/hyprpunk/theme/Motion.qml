pragma Singleton

import QtQuick
import Quickshell

// How the shell moves. Every animation takes its timing from here, named by what the
// element does, so two moves of the same kind feel the same everywhere and the shell's
// rhythm changes in one place. Anim and ColorAnim read these for you.
Singleton {
    // Something going somewhere, or a shape changing size, starting fast so it answers
    // right away. Large is a card unfolding out of its pill.
    readonly property var move: tokens(Easing.OutCubic, 1)
    readonly property var resize: move
    // Appearing: decelerates into place.
    readonly property var enter: move
    // Going away: accelerates out, and quicker than it came, so it never holds up
    // what comes next.
    readonly property var leave: tokens(Easing.InCubic, 0.75)
    // A color or an opacity changing in place.
    readonly property var color: tokens(Easing.OutCubic, 1)

    // The answer to a press: squeezed a little, then springing back a touch too far
    // (BounceAnimation).
    readonly property QtObject bounce: QtObject {
        readonly property int pressDuration: 90
        readonly property int pressEasing: Easing.OutQuad
        readonly property int releaseDuration: 450
        readonly property int releaseEasing: Easing.OutBack
        readonly property real overshoot: 4
    }

    // A card's shape going a few pixels past its size as it finishes growing, then
    // coming back (CardSettle). It peaks as the card reaches its size.
    readonly property QtObject settle: QtObject {
        readonly property int amount: 8
        readonly property int delay: 110
        readonly property int outDuration: 150
        readonly property int outEasing: Easing.OutQuad
        readonly property int backDuration: 320
        readonly property int backEasing: Easing.InOutQuad
    }

    // Something breathing on its own while a state lasts (a recording, a wait).
    readonly property QtObject pulse: QtObject {
        readonly property int duration: 700
        readonly property int easing: Easing.InOutSine
    }

    // How long the pointer rests on a pill before its card opens on hover (sweeping
    // across the bar doesn't flash it), and how long the card waits once it has left.
    readonly property int hoverOpenDelay: 350
    readonly property int hoverCloseDelay: 220
    // How long the music wave takes to settle into the floor or rise from it, around the
    // lock screen.
    readonly property int waveSettle: 450

    // Three sizes, by how far the element travels.
    function tokens(easing, scale) {
        return {
            "small": {
                "duration": Math.round(140 * scale),
                "easing": easing
            },
            "normal": {
                "duration": Math.round(220 * scale),
                "easing": easing
            },
            "large": {
                "duration": Math.round(280 * scale),
                "easing": easing
            }
        };
    }

}
