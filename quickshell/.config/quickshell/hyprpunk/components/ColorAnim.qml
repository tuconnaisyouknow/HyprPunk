import QtQuick
import qs.theme

// A color animated with one of Motion's tokens: `ColorAnim { token: Motion.color.small }`.
ColorAnimation {
    property var token: Motion.color.normal

    duration: token.duration
    easing.type: token.easing
}
