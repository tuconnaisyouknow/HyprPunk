import QtQuick
import QtQuick.Layouts

// A control center block with an icon toggle: bounces when toggled.
ControlBlock {
    id: tile

    required property string icon
    required property string title
    property string subtitle: ""
    property bool active: false
    property bool expandable: false

    signal toggled()
    signal expandRequested()

    function toggle() {
        bounce();
        toggled();
    }

    implicitHeight: 60

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 18
            color: "transparent"

            // Mauve glass while on, plain glass while off.
            GlassSurface {
                radius: parent.radius
                hovered: iconHover.hovered
                backgroundColor: tile.active ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, iconHover.hovered ? 0.95 : 0.8) : "transparent"

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? "#1e1e2e" : "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 17
                font.weight: Font.Bold
            }

            HoverHandler {
                id: iconHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: tile.toggle()
            }

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }

            }

        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: tile.title
                    color: "#cba6f7"
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: tile.subtitle
                    color: "#b4befe"
                    elide: Text.ElideRight
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: tile.expandable ? tile.expandRequested() : tile.toggle()
            }

        }

        Text {
            visible: tile.expandable
            text: "󰅂"
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16

            TapHandler {
                onTapped: tile.expandRequested()
            }

        }

    }

}
