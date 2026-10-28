import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// A labelled file picker for the control center's forms, like NetworkManager's
// certificate buttons. Shows the file's name or "(None)", and opens zenity to choose.
ColumnLayout {
    id: file

    required property string label
    property string path: ""
    property string dialogTitle: label
    // zenity filters: "Name | *.pem *.crt".
    property var filters: []
    readonly property bool choosing: chooser.running

    spacing: 5

    Text {
        text: file.label
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Rectangle {
        id: box

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: Qt.rgba(17 / 255, 17 / 255, 27 / 255, boxHover.hovered ? 0.6 : 0.45)
        opacity: file.enabled ? 1 : 0.45

        Text {
            anchors.left: parent.left
            anchors.right: clear.visible ? clear.left : icon.left
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            text: file.path !== "" ? file.path.split("/").pop() : "(None)"
            color: file.path !== "" ? "#cba6f7" : "#6c7086"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        // Back to "(None)".
        Text {
            id: clear

            anchors.right: icon.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: file.path !== ""
            text: ""
            color: clearHover.hovered ? "#cba6f7" : "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: file.path = ""
            }

        }

        Text {
            id: icon

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: file.choosing ? "󰔟" : "󰉋"
            color: "#b4befe"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }

        HoverHandler {
            id: boxHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                boxBounce.restart();
                if (!chooser.running)
                    chooser.running = true;

            }
        }

        BounceAnimation {
            id: boxBounce

            target: box
        }

        Behavior on color {
            ColorAnimation {
                duration: 120
            }

        }

    }

    Process {
        id: chooser

        // The current locale, not the one the shell was started with.
        environment: Session.localeEnvironment

        command: {
            const command = ["zenity", "--file-selection", "--title=" + file.dialogTitle];
            if (file.path !== "")
                command.push("--filename=" + file.path);

            for (const filter of file.filters.concat(["All files | *"]))
                command.push("--file-filter=" + filter);
            return command;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const chosen = text.trim();
                if (chosen !== "")
                    file.path = chosen;

            }
        }

    }

}
