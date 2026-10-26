import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Background of a panel glued to screen edges, with the glass rim of the
// other cards: fillPath (closed) is filled, and the rim is stroked along
// rimPath only (the free edge, not the sides against the screen), masked by
// the fill so it stays inside like GlassSurface's 1px ring.
Item {
    id: edge

    property color fillColor: "#313244"
    property string fillPath: ""
    property string rimPath: ""
    // For a shape drawn flipped upside down: keeps the brighter rim at the top on screen.
    property bool lightFromBottom: false

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: edge.fillColor
            strokeColor: "transparent"

            PathSvg {
                path: edge.fillPath
            }

        }

    }

    Shape {
        id: rimMask

        anchors.fill: parent
        visible: false
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: "white"
            strokeColor: "transparent"

            PathSvg {
                path: edge.fillPath
            }

        }

    }

    Shape {
        id: rim

        anchors.fill: parent
        visible: false
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: "transparent"
            // Centred on the edge: the outer half is cut by the mask.
            strokeWidth: 2
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.RoundJoin

            strokeGradient: LinearGradient {
                x1: 0
                y1: edge.lightFromBottom ? edge.height : 0
                x2: 0
                y2: edge.lightFromBottom ? 0 : edge.height

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

            PathSvg {
                path: edge.rimPath
            }

        }

    }

    MultiEffect {
        anchors.fill: parent
        source: rim
        maskEnabled: true
        maskSource: rimMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

}
