import QtQuick
import QtQuick.Layouts

// A text field for the control center's forms and the Wi-Fi password, sunk into the
// glass, with its label above when it has one. Secret ones hide what you type.
ColumnLayout {
    id: field

    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    property bool secret: false
    // Shown in clear by a "Show password" check.
    property bool revealed: false
    property string tooltip: ""
    // Escape gives up (escaped()) instead of reaching the page.
    property bool escapable: false
    readonly property alias input: input

    signal accepted()
    signal escaped()

    spacing: 5

    Text {
        visible: field.label !== ""
        text: field.label
        color: Theme.lavender
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Bold
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 12
        color: Theme.recessed
        opacity: field.enabled ? 1 : 0.45
        // A mauve ring while you can type in it, like the glass fields.
        border.width: 1.5
        border.color: Theme.alpha(Theme.mauve, input.activeFocus ? 0.85 : 0)

        Behavior on border.color {
            ColorAnimation {
                duration: 160
            }

        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
            passwordCharacter: "■"
            color: Theme.mauve
            selectionColor: Theme.selection
            selectedTextColor: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.letterSpacing: field.secret && !field.revealed ? 3 : 0
            clip: true
            cursorDelegate: Item {
            }
            onAccepted: field.accepted()
            Keys.onEscapePressed: (event) => {
                event.accepted = field.escapable;
                if (field.escapable)
                    field.escaped();

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: field.placeholder
                color: Theme.overlay0
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
