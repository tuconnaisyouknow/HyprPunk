import QtQuick
import qs.components
import qs.services
import qs.theme

// Bars dancing while the music plays, settling into dots while it's paused: the island's
// and the player's. Each bar's height is a pure function of one shared clock
// (EqualizerClock), so two equalizers drawn at once (the island's and the one flying into
// the player) move as one, and the one taking over from the other never jumps.
Row {
    id: equalizer

    property bool playing: false
    // Off, it stands still where it is: hidden, or kept still for the battery.
    property bool running: true
    // How much the bars dance: eases out to the dots on a pause and back in on play.
    property real energy: playing ? 1 : 0
    // The shared clock's time while it moves, the time it stopped at while it stands.
    property real time: 0
    readonly property bool moving: running && (playing || energy > 0)
    // How much the bars keep to the island's round end, where they sit in a circle as
    // wide as the cover's at the other end: none of them reaches closer to the island's
    // edge than the cover does. 0 in the player, which has room.
    property real roundness: 0
    readonly property real roundRadius: Metrics.pillHeight / 2 - Metrics.islandMusicInset

    height: 18
    spacing: 4

    Binding on time {
        when: equalizer.moving
        value: EqualizerClock.time
        restoreMode: Binding.RestoreNone
    }

    ServiceRef {
        service: EqualizerClock
        active: equalizer.moving
    }

    // Two waves each, at paces that never line up, so the bars never move together.
    Repeater {
        model: [[7.1, 11.3, 0], [9.4, 5.3, 2.1], [6.2, 13.1, 4.2], [8.7, 4.9, 1]]

        Rectangle {
            required property var modelData
            required property int index
            // Across from the middle, and the tallest it can stand with its round ends
            // inside the circle.
            readonly property real offset: index * (width + equalizer.spacing) + (width - equalizer.width) / 2
            readonly property real roundRoom: 2 * Math.sqrt(Math.max(0, Math.pow(equalizer.roundRadius - width / 2, 2) - offset * offset)) + width
            readonly property real room: equalizer.height + (Math.min(equalizer.height, roundRoom) - equalizer.height) * equalizer.roundness
            readonly property real level: 0.5 + 0.3 * Math.sin(modelData[0] * equalizer.time + modelData[2]) + 0.2 * Math.sin(modelData[1] * equalizer.time + 2 * modelData[2])

            // Centred by hand: an anchor would keep its middle on a whole pixel, and
            // the bar would shake as it grows.
            y: (equalizer.height - height) / 2
            width: 4
            // At rest, a round dot.
            height: width + (room - width) * equalizer.energy * level
            radius: width / 2
            color: Colors.primary
        }

    }

    Behavior on energy {
        Anim {
            token: Motion.swap
        }

    }

}
