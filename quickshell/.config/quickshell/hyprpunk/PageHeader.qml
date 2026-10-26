import QtQuick
import QtQuick.Layouts

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
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
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
        color: "#cba6f7"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 18
        font.weight: Font.Bold
    }

    ToggleSwitch {
        visible: header.toggleVisible
        checked: header.checked
        onToggled: header.toggled()
    }

}
