import QtQuick
import qs.theme

// A field or a shape shaking its head to say no (Motion.shake). Plays on an offset the
// target adds to where it sits, so it never fights the target's own place.
SequentialAnimation {
    id: shake

    required property QtObject target
    property string offsetProperty: "shakeOffset"

    NumberAnimation {
        target: shake.target
        property: shake.offsetProperty
        to: Motion.shake.swings[0]
        duration: Motion.shake.swingDuration
    }

    NumberAnimation {
        target: shake.target
        property: shake.offsetProperty
        to: Motion.shake.swings[1]
        duration: Motion.shake.swingDuration
    }

    NumberAnimation {
        target: shake.target
        property: shake.offsetProperty
        to: Motion.shake.swings[2]
        duration: Motion.shake.swingDuration
    }

    NumberAnimation {
        target: shake.target
        property: shake.offsetProperty
        to: Motion.shake.swings[3]
        duration: Motion.shake.swingDuration
    }

}
