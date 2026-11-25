import QtQuick
import qs.theme

// An icon from Material Symbols Rounded, written by its name: `Icon { text: "lock" }`.
// Outlined at rest, it fills in while what it stands for is on, chosen or in use
// (filled), and empties again the same way when that ends.
Text {
    id: icon

    // The size of what's drawn, in pixels. Material draws in the middle 20 px of a 24 px
    // square, so the font is a fifth larger for the icon to stand as tall as the text
    // beside it. Its optical size follows the font's.
    property real size: Metrics.text.body
    property bool filled: false
    // How far it's filled, from 0 to 1: it follows filled, and an interrupted fill turns back.
    property real fill: filled ? 1 : 0

    color: Colors.primary
    font.family: Metrics.iconFont
    font.pixelSize: size * 24 / 20
    // Each fill is a font of its own that Qt rasterizes and keeps: in tenths, the fill
    // stays smooth and the fonts few. The grade stays the font's own: off it, a filled
    // icon's patch no longer covers the hollow it fills, and leaves a sliver open.
    font.variableAxes: ({
        "FILL": Math.round(fill * 10) / 10,
        "opsz": Math.max(20, Math.min(48, size * 24 / 20)),
        "wght": 400
    })
    // Rasterized by FreeType, unhinted. A filled icon is outlines laid over each other:
    // the distance field leaves holes where they overlap, hinting snaps each edge apart
    // and leaves seams, and the curve renderer frays the edges.
    renderType: Text.NativeRendering
    font.hintingPreference: Font.PreferNoHinting
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on fill {
        Anim {
            token: Motion.color.small
        }

    }

}
