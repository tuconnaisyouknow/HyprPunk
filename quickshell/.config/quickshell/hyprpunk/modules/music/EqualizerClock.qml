pragma Singleton

import QtQuick
import Quickshell

// The one clock every equalizer dances to (Equalizer), moving while any of them moves
// (held through ServiceRef) and waiting where it stopped otherwise. One that shows up
// mid-way, like the one flying into the player, takes its time on its first frame instead
// of waiting for a tick of its own, so it never stands still a moment and then jumps.
Singleton {
    id: clock

    // The equalizers moving.
    property int refCount: 0
    // Seconds, moved on only while something dances. One turn is 20π seconds, which every
    // bar's waves end with a whole number of rounds (their paces are tenths), so it starts
    // over unseen.
    property real time: 0

    // The animations' own clock, which holds the time of the frame being drawn on each
    // screen. Counting the frames instead stepped the bars unevenly: with two screens they
    // come at no steady pace.
    NumberAnimation on time {
        from: 0
        to: 20 * Math.PI
        duration: 20000 * Math.PI
        loops: Animation.Infinite
        paused: clock.refCount === 0
    }

}
