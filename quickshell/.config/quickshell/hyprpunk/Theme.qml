pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shell's colors, font, pill and card sizes and card timings. The colors are the
// wallpaper's palette, written by matugen: the primary is the accent, the secondary the
// rest of what you read, in place of the greys. Every file takes them from here, so a
// new wallpaper recolors the whole shell at once.
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

    // A new palette lands at once: fading into it re-evaluates every color of the
    // shell on each frame, which dropped it to a few frames a second.
    readonly property color crust: palette.crust
    readonly property color base: palette.base
    readonly property color surface0: palette.surface0
    readonly property color surface1: palette.surface1
    readonly property color primary: palette.primary
    readonly property color secondary: palette.secondary
    // The glass's reflections and the selected text in fields, the same on every palette.
    readonly property color text: "#cdd6f4"
    // Colors that mean something, the same on every palette.
    readonly property color blue: palette.blue
    readonly property color green: palette.green
    readonly property color yellow: palette.yellow
    readonly property color peach: palette.peach
    readonly property color red: palette.red

    // The cards and pills: the base at 0.9, blurred behind by Hyprland's layer rules.
    readonly property color panel: alpha(base, 0.9)
    // Search and password fields, a little see-through inside the card.
    readonly property color field: alpha(base, 0.6)
    // Recessed boxes inside the glass (the forms' inputs).
    readonly property color recessed: alpha(crust, 0.45)
    // Selected text in the fields.
    readonly property color selection: alpha(primary, 0.35)

    // A color with its alpha replaced, for the see-through variants above and the like.
    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }

    // Read before the first frame, so the shell never starts in a color it then
    // replaces, and again whenever wallpaperctl.sh writes a new palette.
    FileView {
        path: Session.stateDir + "/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: palette

            // Catppuccin Mocha, until the first palette is written.
            property string crust: "#11111b"
            property string base: "#1e1e2e"
            property string surface0: "#313244"
            property string surface1: "#45475a"
            property string primary: "#cba6f7"
            property string secondary: "#b4befe"
            property string blue: "#89b4fa"
            property string green: "#a6e3a1"
            property string yellow: "#f9e2af"
            property string peach: "#fab387"
            property string red: "#f38ba8"
        }

    }

}
