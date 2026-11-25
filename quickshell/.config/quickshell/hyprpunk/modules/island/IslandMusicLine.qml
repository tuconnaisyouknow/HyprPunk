import QtQuick
import qs.components
import qs.services
import qs.theme

// The music in the open island, over the control center's icons (IslandView): the track
// over its artist, between the cover's place and the equalizer's. The cover and the
// equalizer are the island's own, flown over their places as it opens. With no player,
// the line says so. A click opens the player.
IslandBlock {
    id: line

    // How much a player is there: the track comes in over the empty line as one starts.
    property real presence: 1
    readonly property real slot: Metrics.islandBlockHeight
    // Where the cover and the equalizer's slot sit, from the line's left edge.
    readonly property real coverX: 0
    readonly property real equalizerX: width - slot
    // The last track stays while the line empties after the player quits.
    property string title: ""
    property string artist: ""

    radius: Metrics.spacing.normal

    Binding on title {
        when: Music.player !== null
        value: Music.player?.trackTitle || Music.player?.identity || ""
        restoreMode: Binding.RestoreNone
    }

    Binding on artist {
        when: Music.player !== null
        value: Music.player?.trackArtist || Music.player?.trackAlbum || ""
        restoreMode: Binding.RestoreNone
    }

    IslandLineText {
        x: line.slot + Metrics.spacing.normal
        width: line.width - 2 * x
        opacity: line.presence
        title: line.title
        detail: line.artist
    }

    // Nothing playing.
    IslandLineEmpty {
        width: line.width
        opacity: 1 - line.presence
        icon: "music_note"
        label: "Nothing playing"
    }

}
