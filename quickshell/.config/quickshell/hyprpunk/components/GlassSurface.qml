import QtQuick
import qs.config
import qs.theme

// The shell's glass: a frosted fill over the blur, with a rim that catches the light at
// the top and glows faintly at the bottom. It sits behind its parent's content, so the
// parent itself should stay transparent. The rim is GlassRim's, in either style.
Item {
    id: glass

    property real radius: 18
    property bool hovered: false
    // Drawn under the glass, for surfaces with no panel behind them.
    property color backgroundColor: "transparent"
    // Off for panels, which keep their own background and only get the rim.
    property bool tinted: true
    // A text field you can type in: the rim lights up in the accent, since an empty field
    // shows no cursor yet. Only for fields that share the keyboard with something else.
    property bool focused: false
    property real accent: focused ? 1 : 0
    // The liquid style, chosen in the settings: the lock screen clock's glass, with
    // see-through colors and a soft rim instead of the ring.
    readonly property bool liquid: Session.glassStyle === "liquid"
    // How much of the background's color stays, at the top and at the bottom. A dark
    // panel turns see-through, but a light color like the accent of a selection gets a
    // little stronger at the top and fades to its usual self, or it would look grey over
    // the dark glass.
    readonly property bool lightBackground: backgroundColor.hslLightness > 0.4
    property real liquidTop: lightBackground ? 1.15 : 0.6
    property real liquidBottom: lightBackground ? 0.95 : 0.4

    // The rim's color, from the usual pale glass to the accent as the field gets the focus.
    // The accent is only read once it shows, so a new palette leaves every other rim alone.
    function rimColor(alpha, focusedAlpha) {
        if (accent === 0)
            return Colors.alpha(Colors.light, alpha);

        return Qt.rgba(Colors.light.r + (Colors.primary.r - Colors.light.r) * accent, Colors.light.g + (Colors.primary.g - Colors.light.g) * accent, Colors.light.b + (Colors.primary.b - Colors.light.b) * accent, alpha + (focusedAlpha - alpha) * accent);
    }

    anchors.fill: parent
    z: -1

    Behavior on accent {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

    Rectangle {
        anchors.fill: parent
        visible: !glass.liquid
        radius: glass.radius
        color: glass.backgroundColor
    }

    // The background turned to glass, fading downward like the clock's minutes.
    Rectangle {
        anchors.fill: parent
        visible: glass.liquid
        radius: glass.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Colors.alpha(glass.backgroundColor, Math.min(1, glass.backgroundColor.a * glass.liquidTop))
            }

            GradientStop {
                position: 1
                color: Colors.alpha(glass.backgroundColor, Math.min(1, glass.backgroundColor.a * glass.liquidBottom))
            }

        }

    }

    // The frost. A panel's glass has none, except under the pointer on a pill you can
    // click.
    Rectangle {
        anchors.fill: parent
        opacity: glass.tinted || glass.hovered ? 1 : 0
        visible: opacity > 0
        radius: glass.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Colors.alpha(Colors.light, glass.hovered ? 0.17 : 0.11)
            }

            GradientStop {
                position: 1
                color: Colors.alpha(Colors.light, glass.hovered ? 0.09 : 0.04)
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }

        }

    }

    // The rim, a touch thicker while focused.
    GlassRim {
        liquid: glass.liquid
        radius: glass.radius
        rimWidth: glass.liquid ? 3 + glass.accent : 1 + 0.5 * glass.accent
        rimTop: glass.rimColor(0.38, 0.95)
        rimMiddle: glass.rimColor(0.06, 0.6)
        rimBottom: glass.rimColor(0.16, 0.8)
    }

}
