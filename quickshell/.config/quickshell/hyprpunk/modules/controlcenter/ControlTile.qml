import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

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
        anchors.leftMargin: Metrics.spacing.normal
        anchors.rightMargin: Metrics.spacing.normal
        spacing: Metrics.spacing.normal

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Metrics.radius.card
            color: "transparent"

            // Lit in the accent while on, plain glass while off.
            GlassSurface {
                radius: parent.radius
                hovered: iconHover.hovered
                backgroundColor: tile.active ? Colors.alpha(Colors.primary, iconHover.hovered ? 0.95 : 0.8) : "transparent"
                lit: true

                ColorFade on backgroundColor {
                    token: Motion.color.small
                }

            }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                color: tile.active ? Colors.over(Colors.primary) : Colors.primary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.title
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

            ColorFade on color {
                token: Motion.color.small
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
                    color: Colors.primary
                    elide: Text.ElideRight
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
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
                        color: Colors.secondary
                        elide: Text.ElideRight
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.body
                    }

                    MarqueeText {
                        id: subtitleMarquee

                        width: parent.width
                        visible: parent.scrolling
                        running: parent.scrolling
                        text: tile.subtitle
                        color: Colors.secondary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.body
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
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.title

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: tile.expandRequested()
            }

        }

    }

}
