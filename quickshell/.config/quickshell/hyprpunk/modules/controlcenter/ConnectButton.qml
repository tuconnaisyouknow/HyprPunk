import QtQuick
import qs.components
import qs.theme

// The button that answers a Wi-Fi form (Connect, Save, Next): the accent's glass,
// faded until the form is complete, an hourglass while it works.
Rectangle {
    id: button

    required property string label
    property bool available: true
    property bool busy: false

    signal clicked()

    function activate() {
        if (!available)
            return ;

        bounce.restart();
        clicked();
    }

    implicitWidth: content.implicitWidth + 32
    implicitHeight: 34
    radius: height / 2
    color: "transparent"
    opacity: available ? 1 : 0.45
    activeFocusOnTab: true

    GlassSurface {
        radius: parent.radius
        hovered: hover.hovered
        backgroundColor: Colors.alpha(Colors.primary, hover.hovered && button.available ? 0.95 : 0.8)
        lit: true
        // The answer already picked for you: lit like a selection, not like something on.
        inward: true
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Metrics.spacing.normal

        Icon {
            visible: button.busy
            anchors.verticalCenter: parent.verticalCenter
            text: "hourglass"
            color: labelText.color
            size: Metrics.text.emphasis
        }

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            text: button.label
            color: Colors.over(Colors.primary)
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.Bold
        }

    }

    HoverHandler {
        id: hover

        cursorShape: button.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        enabled: button.available
        onTapped: button.activate()
    }

    BounceAnimation {
        id: bounce

        target: button
    }

}
