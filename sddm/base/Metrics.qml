pragma Singleton

import QtQuick

// The login screen's sizes: the shell's own (its theme/Metrics.qml), for what the two
// share, so the bar you log in under is the one you find behind it. Keep both alike.
QtObject {
    // Ioskeley Mono, as fontsctl.py builds it for the shell. sddm.sh copies it next to
    // the theme, and Main.qml loads it.
    readonly property string font: "HyprPunk Text"
    // The icons: Material Symbols Rounded, installed for the whole system.
    readonly property string iconFont: "Material Symbols Rounded"
    // The clock, in capitals: Orbitron Bold, built with digits that all take one width.
    readonly property string displayFont: "HyprPunk Display"
    // How far the pills sit from the screen's sides, and the desktop's strip kept free of
    // windows: the pills sit where the shell's do, as far from the top as from the
    // windows under the strip.
    readonly property int barMargin: 10
    readonly property int barHeight: 52
    readonly property int barTop: (barHeight + barMargin - pillHeight) / 2
    readonly property int pillHeight: 46
    // Room on each side of a pill's content.
    readonly property int pillPadding: spacing.large
    readonly property QtObject text: QtObject {
        readonly property int body: 13
        readonly property int title: 17
    }
    // What the pills hold, grown with them from 42 px, as in the shell: its names and
    // icons, and the words the island shows.
    readonly property QtObject pill: QtObject {
        readonly property real scale: pillHeight / 42
        readonly property int label: Math.round(text.title * scale)
        readonly property int chipLabel: Math.round(text.body * scale)
    }
    // Gaps and insets, on a 4 px grid.
    readonly property QtObject spacing: QtObject {
        readonly property int normal: 8
        readonly property int large: 12
    }
}
