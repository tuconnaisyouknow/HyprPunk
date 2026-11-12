import QtQuick
import QtQuick.Layouts

// A control center block with an icon toggle: bounces when toggled. A click on the rest
// opens its page when it has one (activate), the icon toggles it (activateAlt).
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

    function activate() {
        if (expandable)
            expandRequested();
        else
            toggle();
    }

    function activateAlt() {
        toggle();
    }

    implicitHeight: 60
    activeFocusOnTab: true

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

            // Accent glass while on, plain glass while off.
            GlassSurface {
                radius: parent.radius
                hovered: iconHover.hovered
                backgroundColor: tile.active ? Theme.alpha(Theme.primary, iconHover.hovered ? 0.95 : 0.8) : "transparent"

                Behavior on backgroundColor {
                    ColorAnimation {
                        duration: 140
                    }

                }

            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Theme.base : Theme.primary
                font.family: Theme.font
                font.pixelSize: 17
                font.weight: Font.Bold
            }

            HoverHandler {
                id: iconHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
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
                    color: Theme.primary
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
                        color: Theme.secondary
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
                        color: Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: tile.activate()
            }

        }

        Text {
            visible: tile.expandable
            text: "󰅂"
            color: Theme.secondary
            font.family: Theme.font
            font.pixelSize: 16

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: tile.expandRequested()
            }

        }

    }

}
