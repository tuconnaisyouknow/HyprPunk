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

    // A pill that comes and goes from above the bar (DropInSlot, the OSD beside a card):
    // it falls into place and bounces, and flies back up when it's over.
    readonly property QtObject drop: QtObject {
        // High enough to be off screen.
        readonly property int height: 60
        readonly property int fallDuration: 700
        readonly property int fallEasing: Easing.OutBounce
        readonly property int riseDuration: 300
        readonly property int riseEasing: Easing.InBack
    }

    // Going from one page of a panel to another, like on iOS: the new page slides in
    // over the old one backing off, and the old one is nearly gone before the new one
    // shows, so they never mush together (PageStack).
    readonly property QtObject page: QtObject {
        readonly property int duration: 320
        // How far each page slides, as a share of the page's width.
        readonly property real slideIn: 0.3
        readonly property real backOff: 0.15
    }
    // No, with a shake of the head (a wrong password, a name you can't save under): each
    // swing smaller than the last, where the element goes from its place (Shake).
    readonly property QtObject shake: QtObject {
        readonly property var swings: [-12, 10, -6, 0]
        readonly property int swingDuration: 60
    }

    // Something taking its size with a touch past it, then settling: a hovered emoji or
    // icon, a workspace button, a dot that appears.
    readonly property var pop: ({
        "duration": 200,
        "easing": Easing.OutBack
    })

    // Something breathing on its own while a state lasts (a recording, a wait).
    readonly property QtObject pulse: QtObject {
        readonly property int duration: 700
        readonly property int easing: Easing.InOutSine
    }

    // The record in the bar (MusicPill), moving like a real one: the turntable getting up
    // to speed and slowing down, the next disc rolling in, a disc pulled back by hand when
    // the track restarts, and a pop on play, pause and a new track.
    readonly property QtObject record: QtObject {
        readonly property var spinUp: ({
            "duration": 700,
            "easing": Easing.InQuad
        })
        readonly property var speed: ({
            "duration": 900,
            "easing": Easing.InOutQuad
        })
        readonly property var roll: ({
            "duration": 520,
            "easing": Easing.OutCubic
        })
        readonly property var rewind: ({
            "duration": 650,
            "easing": Easing.OutCubic
        })
        readonly property var popOut: ({
            "duration": 120,
            "easing": Easing.OutQuad
        })
        readonly property var popBack: ({
            "duration": 480,
            "easing": Easing.OutBack
        })
        readonly property real popScale: 1.16
        readonly property real popOvershoot: 3
    }

    // The lyrics following the song (LyricsView): the view glides to the line sung, the
    // old lines slide away, the new ones rise one after another from the line sung.
    readonly property QtObject lyrics: QtObject {
        readonly property var follow: ({
            "duration": 560,
            "easing": Easing.OutCubic
        })
        readonly property var leave: ({
            "duration": 260,
            "easing": Easing.InCubic
        })
        readonly property var arrive: ({
            "duration": 420,
            "easing": Easing.OutCubic
        })
        readonly property int arriveStagger: 45
        // The line sung growing to its size.
        readonly property var line: ({
            "duration": 360,
            "easing": Easing.OutCubic
        })
    }

    // How long the pointer rests on a pill before its card opens on hover (sweeping
    // across the bar doesn't flash it), and how long the card waits once it has left.
    readonly property int hoverOpenDelay: 350
    readonly property int hoverCloseDelay: 220
    // Between items going one after another (clearing the notifications), so you see
    // them go in order without waiting on each.
    readonly property int stagger: 70
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
