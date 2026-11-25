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
    // Its state, read out in capitals.
    property string subtitle: ""
    // What it's connected to (a network, a device), shown in the state's place, as written.
    property string name: ""
    readonly property string detail: name !== "" ? name : subtitle
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
                backgroundColor: Colors.alpha(Colors.primary, !tile.active ? 0 : iconHover.hovered ? 0.95 : 0.8)
                lit: true

                ColorFade on backgroundColor {
                    token: Motion.color.small
                }

            }

            Icon {
                anchors.centerIn: parent
                text: tile.icon
                filled: tile.active
                color: tile.active ? Colors.over(Colors.primary) : Colors.primary
                size: Metrics.text.title
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

                Heading {
                    width: parent.width
                    text: tile.title
                    elide: Text.ElideRight
                }

                // Cut with an ellipsis, scrolling round under the pointer when it
                // does not fit.
                Item {
                    readonly property bool scrolling: tile.hovered && subtitleMarquee.overflowing

                    width: parent.width
                    height: subtitleText.implicitHeight
                    visible: tile.detail !== ""

                    Readout {
                        id: subtitleText

                        width: parent.width
                        visible: !parent.scrolling
                        named: tile.name !== ""
                        text: tile.detail
                        elide: Text.ElideRight
                    }

                    MarqueeText {
                        id: subtitleMarquee

                        width: parent.width
                        visible: parent.scrolling
                        running: parent.scrolling
                        text: tile.detail
                        color: Colors.secondary
                        font: subtitleText.font
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

        Icon {
            visible: tile.expandable
            text: "keyboard_arrow_right"
            color: Colors.secondary
            size: Metrics.text.title

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: tile.expandRequested()
            }

        }

    }

}
