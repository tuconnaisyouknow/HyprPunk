import QtQuick

// Plain text in the accent in the shell's font, as the bar writes it.
Text {
    color: Colors.primary
    font.family: Metrics.font
    font.pixelSize: Metrics.pill.label
    font.weight: Font.DemiBold
    verticalAlignment: Text.AlignVCenter
}
