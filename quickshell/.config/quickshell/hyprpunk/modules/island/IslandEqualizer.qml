import QtQuick
import qs.config
import qs.modules.music
import qs.services
import qs.theme

// The music's equalizer at the island's right end (IslandView), in a slot as wide as the
// cover at the other end, so the island stays even around the time.
IslandPart {
    id: part

    // Drawn elsewhere for now, its place kept: the player's equalizer, flying out of it.
    property bool lifted: false
    // Off, the bars stand still: the island hidden under a card or the lock, where they
    // would only redraw the screen for nothing.
    property bool live: true
    // The room the slot leaves before its bars, which counts in the gap before them.
    readonly property real slack: bars.x

    openWidth: Metrics.pillHeight - 2 * Metrics.islandMusicInset
    openHeight: openWidth

    // On a whole pixel in its slot, as it is in the player: centred, its thin bars would
    // sit across half pixels. An even number of pixels in, so its place, the gap before
    // the bars included, stays even (IslandPart).
    Equalizer {
        id: bars

        x: 2 * Math.round((parent.width - width) / 4)
        anchors.verticalCenter: parent.verticalCenter
        opacity: part.lifted ? 0 : 1
        playing: Music.playing
        running: part.live && part.visible && MusicSettings.equalizer
        roundness: 1
    }

}
