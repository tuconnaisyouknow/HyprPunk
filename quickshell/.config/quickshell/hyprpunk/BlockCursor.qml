import QtQuick

// Cursor of the shell's prompts, copied from the high-above-the-noise SDDM theme: a
// blinking mauve block. Placed inside its input, whose own cursor is hidden with
// `cursorDelegate: Item {}`; shown only once typing has started, so the placeholder
// stays clear.
Rectangle {
    id: cursor

    required property TextInput input

    x: input.cursorRectangle.x
    y: input.cursorRectangle.y
    width: 8
    height: input.cursorRectangle.height
    color: "#cba6f7"
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
