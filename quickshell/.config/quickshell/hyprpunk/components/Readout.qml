import QtQuick
import qs.theme

// A state read off the machine (on, off, charging, refused): capitals in the text font,
// a size under the words around it, which capitals would outgrow. A name is never a
// readout: it keeps its own case. It decodes as it arrives (Decode), so its color is set
// as its ink.
Text {
    property color ink: Colors.secondary
    property alias wait: decode.wait
    // A name in a state's place (the network you're on, the device connected): as written.
    property bool named: false

    color: decode.running ? "transparent" : ink
    font.family: Metrics.font
    font.pixelSize: named ? Metrics.text.body : Metrics.text.small
    font.capitalization: named ? Font.MixedCase : Font.AllUppercase
    font.letterSpacing: named ? 0 : 1

    Decode {
        id: decode

        // A name isn't the machine's word: it comes as it is.
        live: !parent.named
        color: parent.ink
    }

}
