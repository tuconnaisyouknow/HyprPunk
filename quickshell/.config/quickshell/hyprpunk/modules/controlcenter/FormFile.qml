import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.theme

// A labelled file picker for the control center's forms, like NetworkManager's
// certificate buttons. Shows the file's name or "(None)", and opens the shell's file
// chooser, in the folder of the file already chosen.
ColumnLayout {
    id: file

    required property string label
    property string path: ""
    property string dialogTitle: label
    // [{ "name", "globs" }], all files offered after them.
    property var filters: []

    spacing: 5

    Text {
        text: file.label
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.body
        font.weight: Font.Bold
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        implicitHeight: 34
        function activate() {
            boxBounce.restart();
            FileChooser.ask({
                "title": file.dialogTitle,
                "folder": file.path !== "" ? file.path.slice(0, file.path.lastIndexOf("/")) || "/" : Quickshell.env("HOME"),
                "filters": file.filters.concat([{
                    "name": "All files",
                    "globs": ["*"]
                }]),
                "filter": 0
            }, (paths) => {
                return file.path = paths[0];
            });
        }

        function activateAlt() {
            file.path = "";
        }

        radius: Metrics.radius.normal
        color: Colors.alpha(Colors.crust, boxHover.hovered ? 0.6 : 0.45)
        opacity: file.enabled ? 1 : 0.45
        activeFocusOnTab: true

        Text {
            anchors.left: parent.left
            anchors.right: clear.visible ? clear.left : icon.left
            anchors.leftMargin: Metrics.spacing.large
            anchors.rightMargin: Metrics.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            text: file.path !== "" ? file.path.split("/").pop() : "(None)"
            color: file.path !== "" ? Colors.primary : Colors.alpha(Colors.secondary, 0.5)
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
        }

        // Back to "(None)".
        Icon {
            id: clear

            anchors.right: icon.left
            anchors.rightMargin: Metrics.spacing.normal
            anchors.verticalCenter: parent.verticalCenter
            visible: file.path !== ""
            text: "close"
            color: clearHover.hovered ? Colors.primary : Colors.secondary
            size: Metrics.text.body

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: box.activateAlt()
            }

        }

        Icon {
            id: icon

            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            text: "folder"
            color: Colors.secondary
            size: Metrics.text.emphasis
        }

        HoverHandler {
            id: boxHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: box.activate()
        }

        BounceAnimation {
            id: boxBounce

            target: box
        }

        ColorFade on color {
            token: Motion.color.small
        }

    }

}
