import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The background of a panel stuck to the screen's edges. fillPath is the shape,
// rimPath the free edge that gets the glass rim (not the sides against the screen).
// The rim is masked by the fill, so it stays inside like GlassSurface's. In the liquid
// style the fill turns see-through and the rim is LiquidGlass's, kept to the free edge.
Item {
    id: edge

    property color fillColor: "#313244"
    property string fillPath: ""
    property string rimPath: ""
    // For a shape drawn flipped upside down: keeps the brighter rim at the top on screen.
    property bool lightFromBottom: false
    readonly property bool liquid: Session.glassStyle === "liquid"
    // Kept once made, like GlassSurface's liquid rim.
    property bool liquidMade: false

    onLiquidChanged: {
        if (liquid)
            liquidMade = true;

    }
    Component.onCompleted: {
        if (liquid)
            liquidMade = true;

    }

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: edge.fillColor
            fillGradient: edge.liquid ? liquidFill : null
            strokeColor: "transparent"

            PathSvg {
                path: edge.fillPath
            }

        }

    }

    // The liquid style's fill, fading downward like GlassSurface's.
    LinearGradient {
        id: liquidFill

        x1: 0
        y1: edge.lightFromBottom ? edge.height : 0
        x2: 0
        y2: edge.lightFromBottom ? 0 : edge.height

        GradientStop {
            position: 0
            color: Qt.rgba(edge.fillColor.r, edge.fillColor.g, edge.fillColor.b, edge.fillColor.a * 0.6)
        }

        GradientStop {
            position: 1
            color: Qt.rgba(edge.fillColor.r, edge.fillColor.g, edge.fillColor.b, edge.fillColor.a * 0.4)
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
        visible: !edge.liquid
        source: rim
        maskEnabled: true
        maskSource: rimMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // The liquid rim, built like LiquidGlass's with the same blur and thresholds: the
    // light shows where the blurred shape fades. Then only along the free edge, so the
    // sides against the screen stay without one.
    Loader {
        anchors.fill: parent
        active: edge.liquid || edge.liquidMade
        visible: edge.liquid

        sourceComponent: Item {
            Item {
                id: shapeInner

                anchors.fill: parent
                visible: false
                layer.enabled: true

                MultiEffect {
                    anchors.fill: parent
                    source: rimMask
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 3 / 16
                    blurMax: 16
                }

            }

            Rectangle {
                id: rimLight

                anchors.fill: parent
                visible: false
                layer.enabled: true

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, edge.lightFromBottom ? 0.16 : 0.38)
                    }

                    GradientStop {
                        position: edge.lightFromBottom ? 0.55 : 0.45
                        color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, 0.06)
                    }

                    GradientStop {
                        position: 1
                        color: Qt.rgba(205 / 255, 214 / 255, 244 / 255, edge.lightFromBottom ? 0.38 : 0.16)
                    }

                }

            }

            Item {
                id: rimInShape

                anchors.fill: parent
                visible: false
                layer.enabled: true

                MultiEffect {
                    anchors.fill: parent
                    source: rimLight
                    maskEnabled: true
                    maskSource: rimMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

            }

            Item {
                id: softRim

                anchors.fill: parent
                visible: false
                layer.enabled: true

                MultiEffect {
                    anchors.fill: parent
                    source: rimInShape
                    maskEnabled: true
                    maskSource: shapeInner
                    maskInverted: true
                    maskThresholdMin: 0.85
                    maskSpreadAtMin: 0.15
                }

            }

            // A wide band along the free edge, to keep the rim to it.
            Shape {
                id: freeEdgeBand

                anchors.fill: parent
                visible: false
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                layer.enabled: true

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "white"
                    strokeWidth: 16
                    capStyle: ShapePath.FlatCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: edge.rimPath
                    }

                }

            }

            MultiEffect {
                anchors.fill: parent
                source: softRim
                maskEnabled: true
                maskSource: freeEdgeBand
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

        }

    }

}
