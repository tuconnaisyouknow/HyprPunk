import QtQuick
import QtQuick.Effects

// The piece of the video under this item, blurred, for the glass over it to show: Hyprland
// blurs what's behind the shell's glass, and SDDM has no one to ask. Only that piece is
// blurred, with the blur's reach around it so its edges are right. Place it in the item
// the screen is drawn in, from the same corner.
ShaderEffectSource {
    id: blur

    required property Item video
    // How many of the video's pixels one of this item's covers.
    required property real zoom
    property alias blurMax: effect.blurMax
    property alias brightness: effect.brightness
    property alias saturation: effect.saturation
    readonly property real reach: effect.blurMax

    sourceItem: effect
    sourceRect: Qt.rect(reach, reach, width, height)
    visible: false

    ShaderEffectSource {
        id: piece

        width: blur.width + 2 * blur.reach
        height: blur.height + 2 * blur.reach
        sourceItem: blur.video
        sourceRect: Qt.rect((blur.x - blur.reach) * blur.zoom, (blur.y - blur.reach) * blur.zoom, width * blur.zoom, height * blur.zoom)
        visible: false
    }

    MultiEffect {
        id: effect

        width: piece.width
        height: piece.height
        source: piece
        visible: false
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
    }

}
