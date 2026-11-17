import QtQuick
import qs.theme

// A glyph you click, like a card's close cross or the player's controls: a glass halo
// shows only under the pointer, so it stays discreet. It bounces when clicked, and takes
// the click on press, away from a card's own click under it.
Item {
    id: button

    required property string icon
    property int iconSize: Metrics.text.body
    // In the accent even at rest: a main control, or a switch that's on.
    property bool lit: false
    readonly property bool hovered: hover.hovered
    // Its shape, which the keyboard's ring follows.
    readonly property real radius: height / 2

    signal clicked()

    // Its click, from the pointer or from the keys (KeyboardFocus, with activeFocusOnTab
    // turned on where the keys go through the controls).
    function activate() {
        bounce.restart();
        clicked();
    }

    // A circle twice its glyph, unless it says otherwise.
    implicitWidth: 2 * iconSize
    implicitHeight: implicitWidth
    // Unavailable: faded, like anything that's off.
    opacity: enabled ? 1 : 0.5

    // Brighter while pressed.
    GlassSurface {
        radius: button.radius
        hovered: tap.pressed
        opacity: button.hovered ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.color.small
            }

        }

    }

    Text {
        anchors.centerIn: parent
        text: button.icon
        color: button.lit || button.hovered ? Colors.primary : Colors.secondary
        font.family: Metrics.font
        font.pixelSize: button.iconSize

        ColorFade on color {
            token: Motion.color.small
        }

    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: button.activate()
    }

    BounceAnimation {
        id: bounce

        target: button
    }

}
