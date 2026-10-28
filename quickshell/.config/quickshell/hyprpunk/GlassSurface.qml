import QtQuick
import QtQuick.Shapes

// The shell's glass: a frosted fill over the blur, with a rim that catches the light at
// the top and glows faintly at the bottom. It sits behind its parent's content, so the
// parent itself should stay transparent. In the liquid style the rim is LiquidGlass's.
Item {
    id: glass

    property real radius: 18
    property bool hovered: false
    // Drawn under the glass, for surfaces with no panel behind them.
    property color backgroundColor: "transparent"
    // Off for panels, which keep their own background and only get the rim.
    property bool tinted: true
    // A text field you can type in: the rim lights up in mauve, since an empty field
    // shows no cursor yet.
    property bool focused: false
    property real accent: focused ? 1 : 0
    // The liquid style, chosen in the control center: the lock screen clock's glass, with
    // see-through colors and a soft rim instead of the ring.
    readonly property bool liquid: Session.glassStyle === "liquid"
    // The soft rim is kept once made, only hidden in the classic style. Building every
    // surface's rim again at each switch made one frame stutter.
    property bool liquidMade: false
    // How much of the background's color stays, at the top and at the bottom. A dark
    // panel turns see-through, but a light color like the mauve of a selection gets a
    // little stronger at the top and fades to its usual self, or it would look grey over
    // the dark glass.
    readonly property bool lightBackground: backgroundColor.hslLightness > 0.4
    property real liquidTop: lightBackground ? 1.15 : 0.6
    property real liquidBottom: lightBackground ? 0.95 : 0.4

    // The rim's color, from the usual pale glass to mauve as the field gets the focus.
    function rimColor(alpha, focusedAlpha) {
        return Qt.rgba((205 + (203 - 205) * accent) / 255, (214 + (166 - 214) * accent) / 255, (244 + (247 - 244) * accent) / 255, alpha + (focusedAlpha - alpha) * accent);
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
                color: Qt.rgba(glass.backgroundColor.r, glass.backgroundColor.g, glass.backgroundColor.b, Math.min(1, glass.backgroundColor.a * glass.liquidTop))
            }

            GradientStop {
                position: 1
                color: Qt.rgba(glass.backgroundColor.r, glass.backgroundColor.g, glass.backgroundColor.b, Math.min(1, glass.backgroundColor.a * glass.liquidBottom))
            }

        }

    }

    Rectangle {
        anchors.fill: parent
        visible: glass.tinted
        radius: glass.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, glass.hovered ? 0.17 : 0.11)
            }

            GradientStop {
                position: 1
                color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, glass.hovered ? 0.09 : 0.04)
            }

        }

    }

    Shape {
        anchors.fill: parent
        visible: !glass.liquid
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            // The two rectangles cut a 1px ring.
            fillRule: ShapePath.OddEvenFill

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: glass.height

                GradientStop {
                    position: 0
                    color: glass.rimColor(0.38, 0.95)
                }

                GradientStop {
                    position: 0.45
                    color: glass.rimColor(0.06, 0.6)
                }

                GradientStop {
                    position: 1
                    color: glass.rimColor(0.16, 0.8)
                }

            }

            PathRectangle {
                width: glass.width
                height: glass.height
                radius: glass.radius
            }

            // A touch thicker while focused.
            PathRectangle {
                x: 1 + 0.5 * glass.accent
                y: 1 + 0.5 * glass.accent
                width: Math.max(0, glass.width - 2 - glass.accent)
                height: Math.max(0, glass.height - 2 - glass.accent)
                radius: Math.max(0, glass.radius - 1 - 0.5 * glass.accent)
            }

        }

    }

    onLiquidChanged: {
        if (liquid)
            liquidMade = true;

    }
    Component.onCompleted: {
        if (liquid)
            liquidMade = true;

    }

    Loader {
        anchors.fill: parent
        active: glass.liquid || glass.liquidMade
        visible: glass.liquid

        sourceComponent: LiquidGlass {
            radius: glass.radius
            rimWidth: 3 + glass.accent
            rimTop: glass.rimColor(0.38, 0.95)
            rimMiddle: glass.rimColor(0.06, 0.6)
            rimBottom: glass.rimColor(0.16, 0.8)
        }

    }

}
