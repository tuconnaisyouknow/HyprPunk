import QtQuick
import QtQuick.Effects

// Text cut out of glass, like the pills: see-through over the blur behind it, with the
// glass rim along the edges of its glyphs. The lock screen draws its minutes with it.
Item {
    id: glass

    property alias text: label.text
    property alias font: label.font

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // The glyphs in white, for the masks.
    Item {
        id: glyphs

        anchors.fill: parent
        visible: false
        layer.enabled: true

        Text {
            id: label

            color: "white"
        }

    }

    // The glyphs blurred a little: what stays opaque is their inside,
    // without the edges.
    Item {
        id: glyphsInner

        anchors.fill: parent
        visible: false
        layer.enabled: true

        MultiEffect {
            anchors.fill: parent
            source: glyphs
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 0.08
            blurMax: 16
        }

    }

    // The base, translucent: the blurred background shows through.
    Rectangle {
        id: fillLight

        anchors.fill: parent
        visible: false
        layer.enabled: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.primary, 0.5)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.primary, 0.32)
            }

        }

    }

    // GlassSurface's rim.
    Rectangle {
        id: rimLight

        anchors.fill: parent
        visible: false
        layer.enabled: true

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.text, 0.38)
            }

            GradientStop {
                position: 0.45
                color: Theme.alpha(Theme.text, 0.06)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.text, 0.16)
            }

        }

    }

    // The rim's light inside the glyphs only.
    Item {
        id: rimInGlyphs

        anchors.fill: parent
        visible: false
        layer.enabled: true

        MultiEffect {
            anchors.fill: parent
            source: rimLight
            maskEnabled: true
            maskSource: glyphs
            // Keeps the glyphs' smooth edges: alpha eases from 0 to 1 rather than
            // being cut at a threshold (smoothstep from min·(1+spread)−spread
            // to min·(1+spread)).
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

    }

    MultiEffect {
        anchors.fill: parent
        source: fillLight
        maskEnabled: true
        maskSource: glyphs
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }

    // The rim: where the blurred glyphs fade, along their edges.
    MultiEffect {
        anchors.fill: parent
        source: rimInGlyphs
        maskEnabled: true
        maskSource: glyphsInner
        maskInverted: true
        maskThresholdMin: 0.85
        maskSpreadAtMin: 0.15
    }

}
