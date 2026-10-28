import QtQuick

// The blinking mauve block cursor of the shell's prompts, borrowed from the SDDM theme.
// Put it inside the input and hide the input's own cursor (`cursorDelegate: Item {}`).
// It only shows once you start typing, so the placeholder stays readable. A field alone
// in its panel obviously has the keyboard; one sharing it gets a mauve ring instead
// (GlassField's showsFocus).
Rectangle {
    id: cursor

    required property TextInput input

    x: input.cursorRectangle.x
    y: input.cursorRectangle.y
    width: 8
    height: input.cursorRectangle.height
    color: Theme.mauve
    visible: input.activeFocus && !input.readOnly && input.text !== ""

    SequentialAnimation {
        loops: Animation.Infinite
        running: cursor.visible

        NumberAnimation {
            target: cursor
            property: "opacity"
            from: 1
            to: 0.1
            duration: 400
        }

        NumberAnimation {
            target: cursor
            property: "opacity"
            from: 0.1
            to: 1
            duration: 400
        }

    }

}
