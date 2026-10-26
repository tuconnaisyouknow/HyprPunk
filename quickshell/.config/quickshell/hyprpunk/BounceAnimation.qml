import QtQuick

// Press bounce of the control center's buttons: squeezed by a few pixels, then springing
// back past its size. Animates the target's scale, or another scale-like property.
SequentialAnimation {
    id: bounce

    required property Item target
    property string scaleProperty: "scale"
    // The same few pixels for every size, at most 10% for the small buttons.
    readonly property real squeeze: Math.max(0.9, 1 - 8 / Math.max(target.width, 1))

    NumberAnimation {
        target: bounce.target
        property: bounce.scaleProperty
        to: bounce.squeeze
        duration: 90
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        target: bounce.target
        property: bounce.scaleProperty
        to: 1
        duration: 450
        easing.type: Easing.OutBack
        easing.overshoot: 4
    }

}
