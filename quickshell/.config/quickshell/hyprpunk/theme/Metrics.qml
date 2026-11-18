pragma Singleton

import QtQuick
import Quickshell

// The shell's sizes: its font, the text scale, the spacing grid and the corners. Every
// size comes from here, so the whole shell keeps one rhythm. A value missing here is one
// the design doesn't know about yet: add it with its reason, don't write it by hand.
Singleton {
    // Everything you read: Ioskeley Mono, semi-condensed, with the Nerd Font icons the
    // shell writes in its text. fontsctl.py builds it under this name.
    readonly property string font: "HyprPunk Text"
    // A window's titles and the lock's clock, in capitals: Orbitron Bold, which
    // fontsctl.py builds with digits that all take one width.
    readonly property string displayFont: "HyprPunk Display"
    // How far the bar's pills sit from the screen's sides, in line with the windows'
    // edges (Hyprland's gaps_out), so it isn't on the spacing grid.
    readonly property int barMargin: 10
    // The strip the bar keeps free of windows, its pills centred in it: Hyprland reserves
    // it (monitors.lua, keep both alike), and its gaps_out then sets the windows apart
    // from it like from any edge.
    readonly property int barHeight: 50
    readonly property int barTop: (barHeight - pillHeight) / 2
    // The bar's pills. Every card keeps its pill's round ends as it grows.
    readonly property int pillHeight: 38
    // Room on each side of a pill's content.
    readonly property int pillPadding: spacing.large
    // How far the music's cover and equalizer sit from the island's edges, all around:
    // they hug its round ends, like the cover in a phone's island.
    readonly property int islandMusicInset: spacing.small
    // The island grows while an OSD takes it over, so you notice it. The lock's island
    // takes the same shape, to take over from the bar's without a jump.
    readonly property int islandOsdHeight: pillHeight + spacing.large
    readonly property int islandOsdPadding: spacing.huge
    readonly property real cardRadius: pillHeight / 2
    // A button in a card (GlassButton): shorter than the bar's pills, so a card's
    // buttons never read as more pills.
    readonly property int buttonHeight: 34

    // The text, from the smallest detail to a page's heading.
    readonly property QtObject text: QtObject {
        readonly property int small: 12
        readonly property int body: 13
        readonly property int emphasis: 15
        readonly property int title: 17
        readonly property int heading: 21
    }

    // Gaps and insets, on a 4 px grid so everything lines up.
    readonly property QtObject spacing: QtObject {
        readonly property int hairline: 2
        readonly property int small: 4
        readonly property int normal: 8
        readonly property int large: 12
        readonly property int huge: 16
        readonly property int section: 24
    }

    // Lines that separate or outline.
    readonly property int stroke: 1

    // Corners. What sits inside a rounded shape takes inner(), so the curves stay
    // parallel instead of pinching or bulging at the corners.
    readonly property QtObject radius: QtObject {
        readonly property int small: 4
        readonly property int normal: 12
        readonly property real card: cardRadius
    }

    // The radius of a shape inset by `inset` inside one of radius `outer`.
    function inner(outer, inset) {
        return Math.max(0, outer - inset);
    }

}
