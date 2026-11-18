import QtQuick
import qs.theme

// A title: a window's, a page's, a block's, a tile's. Capitals in the display font, the
// machine naming its parts. Small by default, for what heads a block: a page or a window
// sets its own size.
Text {
    color: Colors.primary
    font.family: Metrics.displayFont
    font.pixelSize: Metrics.text.small
    font.weight: Font.Bold
    font.capitalization: Font.AllUppercase
}
