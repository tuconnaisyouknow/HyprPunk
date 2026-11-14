import QtQuick
import qs.theme

// A number animated with one of Motion's tokens: `Anim { token: Motion.leave.small }`.
// Behaviors start it from the current value, so an interrupted move turns back smoothly.
NumberAnimation {
    property var token: Motion.move.normal

    duration: token.duration
    easing.type: token.easing
}
