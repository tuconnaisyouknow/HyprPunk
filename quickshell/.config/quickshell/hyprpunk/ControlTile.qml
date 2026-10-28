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

            // Mauve glass while on, plain glass while off. As liquid glass it keeps more
            // of its mauve, or it would turn grey on the dark panel.
            GlassSurface {
                radius: parent.radius
                hovered: iconHover.hovered
                liquidTop: 0.85
                liquidBottom: 0.6
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

                // Cut with an ellipsis, scrolling round under the pointer when it
                // does not fit.
                Item {
                    readonly property bool scrolling: tile.hovered && subtitleMarquee.overflowing

                    width: parent.width
                    height: subtitleText.implicitHeight
                    visible: tile.subtitle !== ""

                    Text {
                        id: subtitleText

                        width: parent.width
                        visible: !parent.scrolling
                        text: tile.subtitle
                        color: "#b4befe"
                        elide: Text.ElideRight
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

                    MarqueeText {
                        id: subtitleMarquee

                        width: parent.width
                        visible: parent.scrolling
                        running: parent.scrolling
                        text: tile.subtitle
                        color: "#b4befe"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                    }

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
