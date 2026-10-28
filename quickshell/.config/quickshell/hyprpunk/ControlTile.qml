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
                backgroundColor: tile.active ? Theme.alpha(Theme.mauve, iconHover.hovered ? 0.95 : 0.8) : "transparent"

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Theme.base : Theme.mauve
                font.family: Theme.font
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
                    color: Theme.mauve
                    elide: Text.ElideRight
                    font.family: Theme.font
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
                        color: Theme.lavender
                        elide: Text.ElideRight
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    MarqueeText {
                        id: subtitleMarquee

                        width: parent.width
                        visible: parent.scrolling
                        running: parent.scrolling
                        text: tile.subtitle
                        color: Theme.lavender
                        font.family: Theme.font
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
            color: Theme.lavender
            font.family: Theme.font
            font.pixelSize: 16

            TapHandler {
                onTapped: tile.expandRequested()
            }

        }

    }

}
