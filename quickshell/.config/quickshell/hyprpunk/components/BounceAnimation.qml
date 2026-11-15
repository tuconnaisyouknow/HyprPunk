import QtQuick
import qs.theme

// The little bounce of the control center's buttons: squeezed a few pixels, then
// springing back a touch too far. Plays on the target's scale (or anything like it).
SequentialAnimation {
    id: bounce

    required property Item target
    property string scaleProperty: "scale"
    readonly property real squeeze: Motion.squeeze(target.width)

    NumberAnimation {
        target: bounce.target
        property: bounce.scaleProperty
        to: bounce.squeeze
        duration: Motion.bounce.pressDuration
        easing.type: Motion.bounce.pressEasing
    }

    NumberAnimation {
        target: bounce.target
        property: bounce.scaleProperty
        to: 1
        duration: Motion.bounce.releaseDuration
        easing.type: Motion.bounce.releaseEasing
        easing.overshoot: Motion.bounce.overshoot
    }

}
