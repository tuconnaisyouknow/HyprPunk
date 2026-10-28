import QtQuick
import QtQuick.Shapes

// The "liquid glass" look: a frosted fill over the blur, with a rim that catches the
// light at the top and glows faintly at the bottom. It sits behind its parent's
// content, so the parent itself should stay transparent.
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
        radius: glass.radius
        color: glass.backgroundColor
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

}
