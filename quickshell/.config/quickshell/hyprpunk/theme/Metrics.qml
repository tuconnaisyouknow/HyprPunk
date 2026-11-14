pragma Singleton

import QtQuick
import Quickshell

// The shell's sizes: its font, the text scale, the spacing grid and the corners. Every
// size comes from here, so the whole shell keeps one rhythm. A value missing here is one
// the design doesn't know about yet: add it with its reason, don't write it by hand.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"
    // How far the bar's pills sit from the screen's sides, in line with the windows'
    // edges (Hyprland's gaps_out), so it isn't on the spacing grid.
    readonly property int barMargin: 10
    // The bar's pills. Every card keeps its pill's round ends as it grows.
    readonly property int pillHeight: 38
    readonly property real cardRadius: pillHeight / 2

    // The text, from the smallest detail to a page's heading.
    readonly property QtObject text: QtObject {
        readonly property int small: 11
        readonly property int body: 12
        readonly property int emphasis: 14
        readonly property int title: 16
        readonly property int heading: 20
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
