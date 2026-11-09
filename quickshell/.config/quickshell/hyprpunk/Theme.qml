pragma Singleton

import QtQuick
import Quickshell

// The shell's colors, font, pill and card sizes and card timings, Catppuccin Mocha with
// mauve as the accent and lavender as the secondary one, in place of the greys. Every
// file takes them from here, so a color changes everywhere at once.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"
    // How far the bar's pills sit from the screen's sides, in line with the windows'
    // edges (Hyprland's gaps_out).
    readonly property int barMargin: 10
    // The bar's pills, and the corners of every card and the blocks inside it: a card
    // keeps its pill's round ends as it grows, and what it holds shares them.
    readonly property int pillHeight: 38
    readonly property real cardRadius: pillHeight / 2
    // How long the pointer rests on the workspaces before their preview opens (sweeping
    // across the bar doesn't flash it), how long it waits once the pointer has left, and
    // how long every card grown out of a pill takes to unfold or fold.
    readonly property int cardOpenDelay: 350
    readonly property int cardCloseDelay: 220
    readonly property int cardFold: 280
    // How far a card's shape grows past its size as it finishes growing (CardSettle).
    readonly property int cardSettle: 8
    // How long the music wave takes to settle into the floor or rise from it, around the
    // lock screen.
    readonly property int waveSettle: 450

    readonly property color crust: "#11111b"
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color text: "#cdd6f4"
    readonly property color lavender: "#b4befe"
    readonly property color mauve: "#cba6f7"
    readonly property color blue: "#89b4fa"
    readonly property color green: "#a6e3a1"
    readonly property color yellow: "#f9e2af"
    readonly property color peach: "#fab387"
    readonly property color red: "#f38ba8"

    // The cards and pills: the base at 0.9, blurred behind by Hyprland's layer rules.
    readonly property color panel: alpha(base, 0.9)
    // Search and password fields, a little see-through inside the card.
    readonly property color field: alpha(base, 0.6)
    // Recessed boxes inside the glass (the forms' inputs).
    readonly property color recessed: alpha(crust, 0.45)
    // Selected text in the fields.
    readonly property color selection: alpha(mauve, 0.35)

    // A color with its alpha replaced, for the see-through variants above and the like.
    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
}
