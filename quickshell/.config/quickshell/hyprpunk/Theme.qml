pragma Singleton

import QtQuick
import Quickshell

// The shell's colors and font, Catppuccin Mocha with mauve as the accent. Every file
// takes them from here, so a color changes everywhere at once.
Singleton {
    readonly property string font: "JetBrainsMono Nerd Font"

    readonly property color crust: "#11111b"
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color overlay2: "#9399b2"
    readonly property color subtext1: "#bac2de"
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
