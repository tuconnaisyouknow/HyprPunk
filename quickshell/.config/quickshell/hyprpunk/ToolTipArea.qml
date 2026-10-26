import QtQuick
import Quickshell

Item {
    id: area

    required property string text
    property bool delayedVisible: false
    property bool above: false

    anchors.fill: parent

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                showDelay.restart();
            } else {
                showDelay.stop();
                area.delayedVisible = false;
            }
        }
    }

    Timer {
        id: showDelay

        interval: 500
        onTriggered: area.delayedVisible = true
    }

    PopupWindow {
        id: popup

        visible: area.delayedVisible && area.text !== ""
        implicitWidth: background.implicitWidth
        implicitHeight: background.implicitHeight
        color: "transparent"
        grabFocus: false

        anchor {
            item: area
            edges: area.above ? Edges.Top : Edges.Bottom | Edges.Left
            gravity: area.above ? Edges.Top : Edges.Bottom | Edges.Right
            adjustment: PopupAdjustment.SlideX
            margins.top: area.above ? -23 : 34
        }

        Rectangle {
            id: background

            anchors.fill: parent
            implicitWidth: tooltipText.implicitWidth + 18
            implicitHeight: tooltipText.implicitHeight + 10
            radius: 7
            color: "#313244"

            Text {
                id: tooltipText

                anchors.centerIn: parent
                text: area.text
                color: "#cba6f7"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.weight: Font.Medium
            }

        }

        // An empty input region makes the tooltip completely click-through.
        mask: Region {
        }

    }

}
