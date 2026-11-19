pragma Singleton

import QtQuick

// The login screen's colors, by the shell's roles (its theme/Colors.qml): the wallpaper's
// palette, which wallpaperctl.sh has written where theme.conf.user points. SDDM reads it
// over theme.conf and its Catppuccin Mocha. The primary is the accent, the secondary the rest of what you
// read.
QtObject {
    readonly property color crust: config.crust
    readonly property color base: config.base
    readonly property color primary: config.primary
    readonly property color secondary: config.secondary
    readonly property color red: config.red
    // The light the glass catches, the same on every palette.
    readonly property color light: "#cdd6f4"
    // Neon emits its light, daydream receives it: what's lit is a dark tube glowing at
    // its edge in neon, a shape filled with its color in daydream (Light).
    readonly property bool emits: config.theme === "neon"
    // The pills: the base at 0.9, over the video blurred behind them (Pill).
    readonly property color panel: alpha(base, 0.9)

    // A color with its alpha replaced.
    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }

    // What's written over something lit in this color: dark on a fill, the light's own
    // color inside a tube, where dark would vanish.
    function over(light) {
        return emits ? light : base;
    }

}
