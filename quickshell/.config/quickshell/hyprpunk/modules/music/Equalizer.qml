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
    // A dot's share of the height, where the bars rest.
    readonly property real rest: 0.2

    height: 18
    spacing: 3

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
            readonly property real level: 0.5 + 0.3 * Math.sin(modelData[0] * equalizer.time + modelData[2]) + 0.2 * Math.sin(modelData[1] * equalizer.time + 2 * modelData[2])

            // Centred by hand: an anchor would keep its middle on a whole pixel, and
            // the bar would shake as it grows.
            y: (equalizer.height - height) / 2
            width: 3
            height: equalizer.height * (equalizer.rest + (1 - equalizer.rest) * equalizer.energy * level)
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
