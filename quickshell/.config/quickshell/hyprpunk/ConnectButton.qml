import QtQuick

// The button that answers a Wi-Fi form (Connect, Save, Next): the accent's glass,
// faded until the form is complete, an hourglass while it works.
Rectangle {
    id: button

    required property string label
    property bool available: true
    property bool busy: false

    signal clicked()

    implicitWidth: labelText.implicitWidth + 32
    implicitHeight: 34
    radius: 17
    color: "transparent"
    opacity: available ? 1 : 0.45

    GlassSurface {
        radius: parent.radius
        hovered: hover.hovered
        backgroundColor: Theme.alpha(Theme.primary, hover.hovered && button.available ? 0.95 : 0.8)
    }

    Text {
        id: labelText

        anchors.centerIn: parent
        text: (button.busy ? "󰔟  " : "") + button.label
        color: Theme.base
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Bold
    }

    HoverHandler {
        id: hover

        cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: button.available
        onTapped: {
            bounce.restart();
            button.clicked();
        }
    }

    BounceAnimation {
        id: bounce

        target: button
    }

}
