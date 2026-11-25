import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// A row in the control center's lists (networks, devices, outputs): icon, title,
// an optional subtitle and something on the right.
ControlBlock {
    id: row

    required property string icon
    required property string title
    property string subtitle: ""
    property string trailing: ""
    property bool highlighted: false
    // A round info button at the end, for a saved network or a paired device.
    property bool detailsAvailable: false

    signal clicked()
    signal detailsRequested()

    function activate() {
        bounce();
        clicked();
    }

    function activateAlt() {
        if (!detailsAvailable)
            return ;

        detailsBounce.restart();
        detailsRequested();
    }

    implicitHeight: 48
    radius: Metrics.radius.normal
    activeFocusOnTab: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Metrics.spacing.large
        anchors.rightMargin: row.detailsAvailable ? 8 : 14
        spacing: Metrics.spacing.large

        Icon {
            text: row.icon
            filled: row.highlighted
            color: row.highlighted ? Colors.primary : Colors.secondary
            size: Metrics.text.title
        }

        Column {
            Layout.fillWidth: true
            spacing: 1

            Text {
                width: parent.width
                text: row.title
                color: Colors.primary
                elide: Text.ElideRight
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
                font.weight: row.highlighted ? Font.Bold : Font.Medium
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: row.subtitle
                color: Colors.secondary
                elide: Text.ElideRight
                font.family: Metrics.font
                font.pixelSize: Metrics.text.body
            }

        }

        Icon {
            visible: text !== ""
            text: row.trailing
            color: Colors.secondary
            size: Metrics.text.emphasis
        }

        // Plain glyph with a glass halo on hover, like the player's controls.
        Item {
            id: detailsButton

            visible: row.detailsAvailable
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30

            GlassSurface {
                radius: width / 2
                hovered: detailsArea.pressed
                opacity: detailsArea.containsMouse ? 1 : 0

                Behavior on opacity {
                    Anim {
                        token: Motion.color.small
                    }

                }

            }

            Icon {
                anchors.centerIn: parent
                text: "info"
                color: detailsArea.containsMouse ? Colors.primary : Colors.secondary
                size: Metrics.text.title
            }

            // A MouseArea takes the click from the row.
            MouseArea {
                id: detailsArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.activateAlt()
            }

            BounceAnimation {
                id: detailsBounce

                target: detailsButton
            }

        }

    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: row.activate()
    }

}
