import QtQuick

// The island panels' text field: a glass pill with an icon, what you type, and a hint
// at the right. The search panels, the launcher and the SDDM picker's sudo prompt use
// it. Secret ones hide the letters as little squares, like the login screen.
Rectangle {
    id: field

    property string icon
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property color placeholderColor: Theme.overlay1
    // At the right, e.g. what Enter will do. It never takes more than half the field.
    property string hint: ""
    property bool secret: false
    property bool readOnly: false
    property color textColor: Theme.text
    property string fontFamily: Theme.font
    // The mauve ring while it has the keyboard. Off by default: alone in a panel the
    // field always has it, and the ring would only be noise.
    property bool showsFocus: false

    // Every key, before the field types it: set event.accepted to keep it.
    signal keyPressed(var event)
    // Enter, unless keyPressed took it.
    signal accepted()

    implicitHeight: 44
    radius: height / 2
    color: "transparent"

    GlassSurface {
        radius: parent.radius
        backgroundColor: Theme.field
        focused: field.showsFocus && input.activeFocus
    }

    Text {
        id: iconLabel

        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        text: field.icon
        color: Theme.mauve
        font.family: Theme.font
        font.pixelSize: 16
    }

    TextInput {
        id: input

        anchors.left: iconLabel.right
        anchors.leftMargin: 10
        anchors.right: hintLabel.visible ? hintLabel.left : parent.right
        anchors.rightMargin: hintLabel.visible ? 10 : 16
        anchors.verticalCenter: parent.verticalCenter
        echoMode: field.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: "■"
        readOnly: field.readOnly
        color: field.textColor
        selectionColor: Theme.selection
        selectedTextColor: Theme.text
        font.family: field.fontFamily
        font.pixelSize: field.secret ? 14 : 15
        font.letterSpacing: field.secret ? 3 : 0
        clip: true
        cursorDelegate: Item {
        }
        Keys.onPressed: (event) => {
            return field.keyPressed(event);
        }
        onAccepted: field.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.text === ""
            text: field.placeholder
            color: field.placeholderColor
            font.family: Theme.font
            font.pixelSize: parent.font.pixelSize
        }

        BlockCursor {
            input: input
        }

    }

    Text {
        id: hintLabel

        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: field.hint !== ""
        width: Math.min(implicitWidth, field.width / 2)
        elide: Text.ElideRight
        text: field.hint
        color: Theme.overlay1
        font.family: Theme.font
        font.pixelSize: 12
    }

}
