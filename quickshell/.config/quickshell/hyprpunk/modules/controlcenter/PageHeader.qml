import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// The top of a control center page: a back button, the title, and a toggle if the
// page has one (Wi-Fi, Bluetooth).
RowLayout {
    id: header

    required property string title
    property bool checked: false
    property bool toggleVisible: true

    signal backRequested()
    signal toggled()

    spacing: Metrics.spacing.normal

    Rectangle {
        id: backButton

        implicitWidth: 34
        implicitHeight: 34
        radius: height / 2
        color: "transparent"

        GlassSurface {
            radius: parent.radius
            hovered: backHover.hovered
        }

        Text {
            anchors.centerIn: parent
            text: "󰅁"
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.title
        }

        HoverHandler {
            id: backHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                backBounce.restart();
                header.backRequested();
            }
        }

        BounceAnimation {
            id: backBounce

            target: backButton
        }

    }

    Text {
        Layout.fillWidth: true
        text: header.title
        color: Colors.primary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.title
        font.weight: Font.Bold
    }

    ToggleSwitch {
        visible: header.toggleVisible
        checked: header.checked
        onToggled: header.toggled()
    }

}
