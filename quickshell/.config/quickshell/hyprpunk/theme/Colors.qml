pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The shell's colors: the wallpaper's palette, written by matugen. The primary is the
// accent, the secondary the rest of what you read, in place of the greys. Every file
// takes its colors from here by role, so a new wallpaper recolors the whole shell at once.
Singleton {
    id: colors

    // A new palette lands at once: fading into it re-evaluates every color of the
    // shell on each frame, which dropped it to a few frames a second. While it lands,
    // the fades of single colors stand aside (ColorFade).
    property bool landing: false
    readonly property color crust: palette.crust
    readonly property color base: palette.base
    readonly property color surface0: palette.surface0
    readonly property color surface1: palette.surface1
    readonly property color primary: palette.primary
    readonly property color secondary: palette.secondary
    // The light the glass catches and the selected text in fields, the same on every
    // palette.
    readonly property color light: "#cdd6f4"
    // Colors that mean something, the same on every palette.
    readonly property color blue: palette.blue
    readonly property color green: palette.green
    readonly property color yellow: palette.yellow
    readonly property color peach: palette.peach
    readonly property color red: palette.red

    // Neon emits its light, daydream receives it. In neon, a state of the machine (on,
    // chosen, the current one) is a dark tube glowing at its edge rather than a surface
    // filled with the accent (GlassSurface). A selection that's a pane of glass lights up
    // inward instead, with no halo, like the button that answers, and an amount stays a
    // fill.
    readonly property bool emits: Session.theme === "neon"

    // The cards and pills: the base at 0.9, blurred behind by Hyprland where the shell
    // asks (ScreenShell).
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

    // What's written over something lit in this color: dark on a fill, the light's own
    // color inside a tube, where dark would vanish.
    function over(light) {
        return emits ? light : base;
    }

    // Read before the first frame, so the shell never starts in a color it then
    // replaces, and again whenever wallpaperctl.sh writes a new palette.
    FileView {
        path: Session.stateDir + "/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: {
            colors.landing = true;
            reload();
        }
        onLoaded: colors.landing = false
        onLoadFailed: colors.landing = false

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
