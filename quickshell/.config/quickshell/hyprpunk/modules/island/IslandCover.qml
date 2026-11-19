import QtQuick
import qs.modules.music
import qs.services
import qs.theme

// The track's cover, round in the island's left end (IslandView), opening there when
// a player starts and closing when the last one quits. A click on it, or on the equalizer at the
// other end, opens the player out of the island (PlayerCard).
IslandPart {
    id: part

    // Drawn elsewhere for now, its place kept: the player's cover, flying out of it.
    property bool lifted: false

    openWidth: Metrics.pillHeight - 2 * Metrics.islandMusicInset
    openHeight: openWidth

    CoverArt {
        anchors.fill: parent
        opacity: part.lifted ? 0 : 1
        decodeSize: 2 * Math.ceil(part.openWidth)

        // The last cover stays while the part closes after the player quits.
        Binding on source {
            when: Music.player !== null
            value: Music.player?.trackArtUrl ?? ""
            restoreMode: Binding.RestoreNone
        }

    }

}
