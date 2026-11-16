import QtQuick
import qs.theme

// A color that fades when its state changes (hovered, chosen, focused), with one of
// Motion's tokens: `ColorFade on color { token: Motion.color.small }`.
// A new palette isn't a state: it lands at once everywhere, so it passes straight through.
Behavior {
    property alias token: fade.token

    enabled: !Colors.landing

    ColorAnimation {
        id: fade

        property var token: Motion.color.normal

        duration: token.duration
        easing.type: token.easing
    }

}
