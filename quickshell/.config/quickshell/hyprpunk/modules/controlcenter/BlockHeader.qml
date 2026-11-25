import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// The header of a main-page block that has a page of its own: its title, a detail on the
// right and an arrow lit while you're on the block. The keyboard's way into the page
// (KeyboardFocus activates it), next to the block's own controls.
RowLayout {
    id: header

    // The block it heads, which bounces as its page opens.
    required property Item block
    property string title
    property string detail

    signal activated()

    function activate() {
        block.bounce();
        activated();
    }

    Layout.fillWidth: true
    activeFocusOnTab: true

    Heading {
        text: header.title
    }

    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: header.detail
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
    }

    Icon {
        text: "keyboard_arrow_right"
        color: header.block.hovered ? Colors.primary : Colors.secondary
        size: Metrics.text.emphasis

        ColorFade on color {
            token: Motion.color.small
        }

    }

}
