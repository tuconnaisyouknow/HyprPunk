pragma Singleton

import QtQuick
import Quickshell

// How the shell moves. Every animation takes its timing from here, named by what the
// element does, so two moves of the same kind feel the same everywhere and the shell's
// rhythm changes in one place. Anim and ColorFade read these for you.
Singleton {
    id: motion

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
    // The island's content changing where it stands (its faces, the parts that come and
    // go in it): it eases in as well as out, so a change that follows another move flows
    // on from it instead of cutting in.
    readonly property var swap: ({
        "duration": 300,
        "easing": Easing.InOutQuad
    })

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

    // Going from one page of a panel into another, through the glass you opened it from:
    // that glass opens up to the panel's edges with the new page inside it, the old page
    // growing past you by as much. The new page shows in the door from the start, as the
    // old one fades around it (PageStack).
    readonly property QtObject page: QtObject {
        readonly property int duration: 380
        // The size the new page comes up from: the old one grows by the same share.
        readonly property real into: 0.5
        // The share of the way in over which the door's glass shows on its block, and the
        // one over which it melts into the panel.
        readonly property real doorIn: 0.15
        readonly property real doorOut: 0.3
    }
    // How long the time takes between the island and the lock screen's clock, the same
    // both ways.
    readonly property int clockTravel: 450
    // The time leaving the island for the lock screen's clock, growing as it goes: it
    // sets off at once and lands a touch past its place, like the shell's other moves,
    // only gentler over that distance.
    readonly property var clockFlight: ({
        "duration": clockTravel,
        "easing": Easing.OutBack,
        "overshoot": 0.7
    })
    // Its way back home into the island: it sets off gently and falls into its place,
    // still moving as it lands, without going past. The island takes the impact.
    readonly property var clockReturn: ({
        "duration": clockTravel,
        "easing": Easing.InQuad
    })
    // The island under the time as it lands: it gives by as much as under a press and
    // springs back a touch too far, in one move. No finger holds it at the bottom, so it
    // turns back there without stopping, and comes to rest by itself.
    readonly property QtObject impact: QtObject {
        readonly property int duration: 450

        // How far it has given along the way: 1 at its deepest, below 0 past its size,
        // 0 at rest.
        function give(progress) {
            return Math.sin(2 * Math.PI * progress) * (1 - progress) / 0.766;
        }

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

    // A question coming up from a window's edge over what it's about: it lands a touch
    // past its place and comes back.
    readonly property var sheet: ({
        "duration": 450,
        "easing": Easing.OutBack,
        "overshoot": 1.7
    })

    // Something let go taking its place (a screen dropped in the displays' drawing): it
    // lands a touch past it and comes back.
    readonly property var place: ({
        "duration": 400,
        "easing": Easing.OutBack,
        "overshoot": 1.2
    })

    // A light going from one place to another (the workspace you're on): its front edge
    // sets off at once and its back lingers before catching up, so it stretches toward
    // where it's going.
    readonly property QtObject stretch: QtObject {
        readonly property var front: motion.move.normal
        readonly property var back: ({
            "duration": 340,
            "easing": Easing.InOutQuad
        })
    }

    // Words arriving on the machine (Decode): how long they take to settle, how often
    // they scramble anew on the way, and what they're scrambled into.
    readonly property QtObject decode: QtObject {
        readonly property int duration: 350
        readonly property int pace: 35
        readonly property string signs: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    }

    // Something breathing on its own while a state lasts (a recording, a wait).
    readonly property QtObject pulse: QtObject {
        readonly property int duration: 700
        readonly property int easing: Easing.InOutSine
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
    // lock screen. The lock waits for it the same both ways: before its snapshot, and
    // before playing its way out.
    readonly property int waveSettle: 150

    // How far a press squeezes something that big (bounce): the same few pixels for every
    // size, at most 10% for the small ones.
    function squeeze(size) {
        return Math.max(0.9, 1 - 8 / Math.max(size, 1));
    }

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
