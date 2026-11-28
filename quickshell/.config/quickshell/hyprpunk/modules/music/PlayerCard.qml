import QtQuick
import qs.components
import qs.config
import qs.modules.bar
import qs.services
import qs.theme

// The player, one of the island's cards: a click on the island's cover or equalizer, or
// its shortcut, grows it out of the island in the shape the island's cards share
// (IslandFrame). The cover flies from the island's left end to the artwork's place,
// squaring off as it grows, and the equalizer from the right end to its place in the
// card; folding back, both land in the island's ends.
PillPopup {
    id: playerPopup

    required property var bar
    // The island it grows out of (IslandPill), where the cover and the equalizer start.
    required property Item island
    readonly property var islandPill: bar.islandPill
    // The cover settles during the first 70%, so it never crosses the fading-in title, and
    // stays in its slot as the card bounces past its ends.
    readonly property real flight: Math.max(0, Math.min(1, progress / 0.7))
    // The island as you see it, zoomed under the pointer, which they start from.
    readonly property real zoomX: 1 + 2 * islandPill.spreadX / Math.max(islandPill.width, 1)
    readonly property real zoomY: 1 + 2 * islandPill.spreadY / Math.max(islandPill.height, 1)
    // The island's middle, from the left edge of the content's room, which stays put on
    // screen while the shape grows (PillPopup): the shape's own edge moves.
    readonly property real islandMiddle: bar.width / 2 + islandPill.centerOffset - x
    // The cover's and the equalizer's slot in the island.
    readonly property real slotSize: Metrics.pillHeight - 2 * Metrics.islandMusicInset
    // They show while the card is the island's, or folds back onto the island's music.
    // Another card taking the island's shape over, or the island taking an OSD, has no
    // music to meet: they fade with the rest of the content.
    readonly property bool musicCarried: bar.islandFrame.owner === playerPopup || bar.islandFrame.owner === null && island.face === "clock"

    // Where something of the given size starts, flying from a slot of the island (given
    // from its left edge) to a middle in the player (given from its left edge). Never
    // closer to the shape's edge than in the island: the shape folds back faster than
    // they fly, and would hide them. The shape without its bounce, which they don't
    // take: they rest in the island's slots as the shape goes past them. On whole pixels:
    // thin bars sliding across half pixels shimmer.
    function flyX(islandX, playerX, size) {
        const start = islandMiddle + (islandX + slotSize / 2 - islandPill.width / 2) * zoomX;
        const end = musicPlayerCard.x + playerX;
        const left = frame.steadyShape.x - x;
        const edge = Metrics.islandMusicInset + size / 2;
        return Math.round(Math.max(left + edge, Math.min(left + frame.steadyShape.width - edge, start + (end - start) * flight)) - size / 2);
    }

    // Kept off the shape's bottom edge the same way, from a slot of the island given from
    // its top.
    function flyY(islandY, playerY, size) {
        const start = islandY + slotSize / 2;
        const y = start + (playerY - start) * flight;
        const bottom = frame.steadyShape.y + frame.steadyShape.height - frameContent.y;
        return Math.round(Math.min(bottom - Metrics.islandMusicInset - size / 2, y) - size / 2);
    }

    cardLayer: bar.cardLayer
    pill: island
    pillName: "island"
    frame: bar.islandFrame
    panelName: "player"
    screenState: bar.screenState
    // No player to show while none runs.
    requestable: Music.player !== null
    available: Music.player !== null
    align: Qt.AlignHCenter
    carriesMusic: true
    implicitWidth: 380
    // Tall enough for the lyrics: the card grows and shrinks inside it.
    implicitHeight: musicPlayerCard.fullHeight
    cardHeight: musicPlayerCard.height
    // Opened with its shortcut: left and right (Vim's too) turn the players' pages, up and
    // down scroll the lyrics.
    onKeyPressed: (key) => {
        const keys = Session.vimKeyCodes;
        if (key === Qt.Key_Left || key === keys[0])
            musicPlayerCard.turnTo(musicPlayerCard.page - 1);
        else if (key === Qt.Key_Right || key === keys[1])
            musicPlayerCard.turnTo(musicPlayerCard.page + 1);
        else if (key === Qt.Key_Down || key === keys[2])
            musicPlayerCard.scrollLyrics(1);
        else if (key === Qt.Key_Up || key === keys[3])
            musicPlayerCard.scrollLyrics(-1);
    }

    // The last player quit: nothing left to show.
    Connections {
        function onPlayerChanged() {
            if (Music.player === null && playerPopup.expanded)
                playerPopup.close();

        }

        target: Music
    }

    MediaPlayerCard {
        id: musicPlayerCard

        active: playerPopup.mapped
        // Centred on a whole pixel: the card's width changes by fractions as it grows,
        // and a centre anchor shook its content by half a pixel back and forth.
        x: Math.round((parent.width - width) / 2)
        width: playerPopup.implicitWidth
        opacity: Math.max(0, (playerPopup.progress - 0.7) / 0.3)
        player: Music.player
        glassVisible: false
        coverVisible: false
        equalizerVisible: false
    }

    carried: Item {
        anchors.fill: parent
        opacity: playerPopup.musicCarried ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

        // From the island's round cover to the player's artwork, the same picture all
        // the way.
        CoverArt {
            readonly property real size: playerPopup.slotSize * playerPopup.zoomY + (musicPlayerCard.artSize - playerPopup.slotSize * playerPopup.zoomY) * playerPopup.flight

            // It turns the page with the title (MediaPlayerCard).
            x: playerPopup.flyX(playerPopup.island.coverX, musicPlayerCard.artMargin + musicPlayerCard.artSize / 2, size) + musicPlayerCard.pageShift
            opacity: musicPlayerCard.pageOpacity
            fades: !musicPlayerCard.turning
            rolls: playerPopup.mapped
            y: playerPopup.flyY(playerPopup.island.coverY, musicPlayerCard.artMargin + musicPlayerCard.artSize / 2, size)
            width: size
            height: size
            radius: playerPopup.island.coverRadius * playerPopup.zoomY + (musicPlayerCard.artRadius - playerPopup.island.coverRadius * playerPopup.zoomY) * playerPopup.flight
            source: Music.player !== null ? Music.player.trackArtUrl : ""
        }

        Equalizer {
            // In its slot, as in the island.
            x: playerPopup.flyX(playerPopup.island.equalizerX, musicPlayerCard.equalizerCenter.x, playerPopup.slotSize) + playerPopup.island.equalizerInset
            y: playerPopup.flyY(playerPopup.island.equalizerY, musicPlayerCard.equalizerCenter.y, playerPopup.slotSize) + Math.round((playerPopup.slotSize - height) / 2)
            scale: playerPopup.zoomY + (1 - playerPopup.zoomY) * playerPopup.flight
            roundness: 1 - playerPopup.flight
            // From the island's tighter bars to the player's, a whole pixel at a time.
            spacing: Math.round(Metrics.spacing.hairline + (Metrics.spacing.small - Metrics.spacing.hairline) * playerPopup.flight)
            playing: Music.playing
            running: playerPopup.mapped && MusicSettings.equalizer
        }

    }

}
