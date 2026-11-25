import QtQuick

// An icon from Material Symbols Rounded, written by its name and outlined, drawn like the
// shell's (its components/Icon.qml). Keep both alike.
Text {
    // The size of what's drawn: Material draws in the middle 20 px of a 24 px square
    property real size: Metrics.text.title

    color: Colors.primary
    font.family: Metrics.iconFont
    font.pixelSize: size * 24 / 20
    font.variableAxes: ({
        "FILL": 0,
        "opsz": Math.max(20, Math.min(48, size * 24 / 20)),
        "wght": 400
    })
    // Rasterized by FreeType, unhinted: the distance field and hinting leave seams where
    // a filled icon's outlines overlap
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferNoHinting
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
