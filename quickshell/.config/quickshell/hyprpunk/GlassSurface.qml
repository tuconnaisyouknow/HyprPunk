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

    anchors.fill: parent
    z: -1

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
                    color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.38)
                }

                GradientStop {
                    position: 0.45
                    color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.06)
                }

                GradientStop {
                    position: 1
                    color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.16)
                }

            }

            PathRectangle {
                width: glass.width
                height: glass.height
                radius: glass.radius
            }

            PathRectangle {
                x: 1
                y: 1
                width: Math.max(0, glass.width - 2)
                height: Math.max(0, glass.height - 2)
                radius: Math.max(0, glass.radius - 1)
            }

        }

    }

}
