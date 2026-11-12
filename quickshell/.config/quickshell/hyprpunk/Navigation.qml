pragma Singleton

import QtQuick
import Quickshell

// What the keys mean wherever you move through the shell with the keyboard, so every
// panel answers them the same way: Enter or Space for OK, Backspace to go back, the
// arrows or the Vim keys to move. Where moving is only up and down, right is OK too
// and left goes back.
Singleton {
    function plain(event) {
        return !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
    }

    function accepts(event) {
        return plain(event) && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key);
    }

    // Held down, Backspace only clears a field: going back takes a fresh press.
    function backs(event) {
        return plain(event) && event.key === Qt.Key_Backspace && !event.isAutoRepeat;
    }

    // [dx, dy] for the arrows and the Vim keys (h/j/k/l, or j/k/l/m on AZERTY), null
    // otherwise. A text field types the letters before they get here.
    function direction(event) {
        if (!plain(event))
            return null;

        const keys = Session.keyboardLayout === "fr" ? [Qt.Key_J, Qt.Key_M, Qt.Key_K, Qt.Key_L] : [Qt.Key_H, Qt.Key_L, Qt.Key_J, Qt.Key_K];
        const arrows = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Down, Qt.Key_Up];
        const moves = [[-1, 0], [1, 0], [0, 1], [0, -1]];
        const index = Math.max(keys.indexOf(event.key), arrows.indexOf(event.key));
        return index >= 0 ? moves[index] : null;
    }
}
