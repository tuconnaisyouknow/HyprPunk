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
    // How far the pills sit from the screen's sides, and the strip they're centred in.
    readonly property int barMargin: 10
    readonly property int barHeight: 50
    readonly property int barTop: (barHeight - pillHeight) / 2
    readonly property int pillHeight: 38
    // Room on each side of a pill's content.
    readonly property int pillPadding: spacing.large
    readonly property QtObject text: QtObject {
        readonly property int body: 13
        readonly property int title: 17
    }
    // Gaps and insets, on a 4 px grid.
    readonly property QtObject spacing: QtObject {
        readonly property int normal: 8
        readonly property int large: 12
    }
}
