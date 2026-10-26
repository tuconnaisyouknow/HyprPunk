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

    Rectangle {
        id: toggleSwitch

        visible: header.toggleVisible
        implicitWidth: 46
        implicitHeight: 24
        radius: 8
        color: "transparent"

        // Mauve glass while on, plain glass while off.
        GlassSurface {
            radius: parent.radius
            hovered: switchHover.hovered
            backgroundColor: header.checked ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, switchHover.hovered ? 0.95 : 0.8) : "transparent"

            Behavior on backgroundColor {
                ColorAnimation {
                    duration: 160
                }

            }

        }

        Rectangle {
            x: header.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 6
            color: "#1e1e2e"

            Behavior on x {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }

            }

        }

        HoverHandler {
            id: switchHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                switchBounce.restart();
                header.toggled();
            }
        }

        BounceAnimation {
            id: switchBounce

            target: toggleSwitch
        }

    }

}
