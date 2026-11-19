import QtQuick
import qs.theme

// The shell's button, a glass pill holding its words: in the accent for the one that
// answers (Open, Share, a notification's action), lit while it's on (a filter in use).
// It bounces when clicked, and takes the click on press, away from a card's own click
// under it.
Item {
    id: button

    property string icon: ""
    property string label: ""
    property bool accent: false
    property bool active: false
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

    implicitWidth: content.implicitWidth + 2 * Metrics.spacing.huge
    implicitHeight: Metrics.buttonHeight
    // Unavailable: the secondary at half opacity, like anything that's off.
    opacity: enabled ? 1 : 0.5

    GlassSurface {
        radius: button.radius
        hovered: button.hovered || button.active
        backgroundColor: Colors.alpha(Colors.primary, !button.accent ? 0 : button.hovered ? 0.95 : 0.8)
        lit: true
        // The answer already picked for you: lit like a selection, not like something on.
        inward: true

        // Chosen or let go, in the accent or not.
        ColorFade on backgroundColor {
            token: Motion.color.small
        }

    }

    IconText {
        id: content

        anchors.centerIn: parent
        width: Math.min(implicitWidth, button.width - 2 * Metrics.spacing.large)
        icon: button.icon
        // With no icon, the gap would push the words off centre.
        gap: button.icon !== "" ? font.pixelSize / 2 : 0
        text: button.label
        elide: Text.ElideRight
        color: button.accent ? Colors.over(Colors.primary) : button.active ? Colors.primary : Colors.secondary
        font.pixelSize: Metrics.text.emphasis
        font.weight: button.accent ? Font.Bold : Font.Normal
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: button.activate()
    }

    BounceAnimation {
        id: bounce

        target: button
    }

}
