pragma Singleton

import QtQuick
import Quickshell

// The one clock every equalizer dances to (Equalizer), moving on the frames while any of
// them moves (held through ServiceRef). One that shows up mid-way, like the one flying
// into the player, takes its time on its first frame instead of waiting for a tick of its
// own, so it never stands still a moment and then jumps.
Singleton {
    id: clock

    // The equalizers moving.
    property int refCount: 0
    // Seconds, moved on only while something dances.
    property real time: 0

    // Moved by the frames' steady pace: the time measured as each frame is made wanders by
    // a few milliseconds, and the bars stepped unevenly.
    FrameAnimation {
        running: clock.refCount > 0
        onTriggered: clock.time += smoothFrameTime
    }

}
