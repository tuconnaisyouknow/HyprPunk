import QtQuick
import qs.theme

// A title: a window's, a page's, a block's, a tile's. Capitals in the display font, the
// machine naming its parts. Small by default, for what heads a block: a page or a window
// sets its own size. It decodes as it arrives (Decode), so its color is set as its ink.
Text {
    property color ink: Colors.primary

    color: decode.running ? "transparent" : ink
    font.family: Metrics.displayFont
    font.pixelSize: Metrics.text.small
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase

    Decode {
        id: decode

        color: parent.ink
    }

}
