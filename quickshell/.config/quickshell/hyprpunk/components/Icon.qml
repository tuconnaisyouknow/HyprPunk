import QtQuick
import qs.theme

// An icon from Material Symbols Rounded, written by its name: `Icon { text: "lock" }`.
// Outlined at rest, it fills in while what it stands for is on, chosen or in use
// (filled), and empties again the same way when that ends. An icon that changes into
// another of its family (a level, the player's buttons) goes there (IconMorph).
Item {
    id: icon

    property string text
    // The size of what's drawn, in pixels. Material draws in the middle 20 px of a 24 px
    // square, so the font is a fifth larger for the icon to stand as tall as the text
    // beside it. Its optical size follows the font's.
    property real size: Metrics.text.body
    property bool filled: false
    // How far it's filled, from 0 to 1: it follows filled, and an interrupted fill turns back.
    property real fill: filled ? 1 : 0
    property color color: Colors.primary
    property alias style: face.style
    property alias styleColor: face.styleColor
    property alias horizontalAlignment: face.horizontalAlignment
    readonly property alias font: face.font
    // The icon last asked for, which a change sets off from.
    property string shown

    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight
    baselineOffset: face.baselineOffset
    onTextChanged: {
        const family = Icons.family[text];
        if (morph.item && text !== shown && family !== undefined && family === Icons.family[shown])
            morph.item.go(shown, text);
        else
            morph.item?.stop();
        shown = text;
    }

    Text {
        id: face

        anchors.fill: parent
        // Hidden while the icon is on its way to it.
        visible: !(morph.item?.running ?? false)
        text: icon.text
        color: icon.color
        font.family: Metrics.iconFont
        font.pixelSize: icon.size * 24 / 20
        // Each fill is a font of its own that Qt rasterizes and keeps: in tenths, the fill
        // stays smooth and the fonts few. The grade stays the font's own: off it, a filled
        // icon's patch no longer covers the hollow it fills, and leaves a sliver open. The
        // few icons Material only draws as meant once filled always are: that's their
        // drawing, not a state.
        font.variableAxes: ({
            "FILL": Icons.solid.includes(text) ? 1 : Math.round(icon.fill * 10) / 10,
            "opsz": Math.max(20, Math.min(48, icon.size * 24 / 20)),
            "wght": 400
        })
        // Rasterized by FreeType, unhinted. A filled icon is outlines laid over each other:
        // the distance field leaves holes where they overlap, hinting snaps each edge apart
        // and leaves seams, and the curve renderer frays the edges.
        renderType: Text.NativeRendering
        font.hintingPreference: Font.PreferNoHinting
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Only for the icons that can change into another.
    Loader {
        id: morph

        active: Icons.family[icon.text] !== undefined

        sourceComponent: IconMorph {
            glyph: face
            fill: Math.round(icon.fill * 10) / 10
        }

    }

    Behavior on fill {
        Anim {
            token: Motion.color.small
        }

    }

}
