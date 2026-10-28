import QtQuick
import QtQuick.Layouts

// The top of a control center page: a back button, the title, and a toggle if the
// page has one (Wi-Fi, Bluetooth).
RowLayout {
    id: header

    required property string title
    property bool checked: false
    property bool toggleVisible: true

    signal backRequested()
    signal toggled()

    spacing: 10

    Rectangle {
        id: backButton

        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: "transparent"

        GlassSurface {
            radius: parent.radius
            hovered: backHover.hovered
        }

        Text {
            anchors.centerIn: parent
            text: "󰅁"
            color: Theme.mauve
            font.family: Theme.font
            font.pixelSize: 18
        }

        HoverHandler {
            id: backHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
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
        color: Theme.mauve
        font.family: Theme.font
        font.pixelSize: 18
        font.weight: Font.Bold
    }

    ToggleSwitch {
        visible: header.toggleVisible
        checked: header.checked
        onToggled: header.toggled()
    }

}
