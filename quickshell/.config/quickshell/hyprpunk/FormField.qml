import QtQuick
import QtQuick.Layouts

// Labelled text field of the control center's forms, recessed in the glass card like
// the Wi-Fi password; secret fields hide their letters like the sudo field.
ColumnLayout {
    id: field

    required property string label
    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    // Shown in clear by a "Show password" check.
    property bool revealed: false
    property string tooltip: ""
    readonly property alias input: input

    signal accepted()

    spacing: 5

    Text {
        text: field.label
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: Qt.rgba(17 / 255, 17 / 255, 27 / 255, 0.45)
        opacity: field.enabled ? 1 : 0.45

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "■"
            color: "#cba6f7"
            selectionColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.35)
            selectedTextColor: "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            font.letterSpacing: field.secret && !field.revealed ? 3 : 0
            clip: true
            cursorDelegate: Item {
            }
            onAccepted: field.accepted()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: field.placeholder
                color: "#6c7086"
                font.family: parent.font.family
                font.pixelSize: parent.font.pixelSize
            }

            BlockCursor {
                input: input
            }

        }

        HoverHandler {
            cursorShape: Qt.IBeamCursor
        }

        ToolTipArea {
            visible: field.tooltip !== ""
            text: field.tooltip
        }

    }

}
