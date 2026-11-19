import QtQuick

// The shell's glass (its components/GlassSurface.qml): a fill with a rim that catches the
// light at the top and glows faintly at the bottom, in the style you picked in the
// settings: the classic one's crisp ring, or liquid, see-through with a soft rim. It sits
// behind its parent's content. The rim is the shell's own shader, which sddm.sh copies
// next to the theme.
// A lit surface is one whose background is a light. Daydream fills it with that color.
// Neon emits it instead: the fill thins to a tint, and the rim and a halo around it take
// the color.
Item {
    id: glass

    property real radius: height / 2
    // Under the pointer, on a pill you can click: frosted.
    property bool hovered: false
    property color backgroundColor: "transparent"
    property bool lit: false
    readonly property bool emits: lit && Colors.emits
    readonly property bool liquid: config.glass === "liquid"
    // The background as drawn: whole, or the tint left inside a tube.
    readonly property color fill: emits ? Colors.alpha(backgroundColor, backgroundColor.a * 0.16) : backgroundColor
    // The halo of what emits, and the room the rim keeps around the shape for it.
    readonly property real reach: emits ? 8 : 0

    // The rim's color: the pale glass, or the light a surface emits.
    function rimColor(alpha, emittedAlpha) {
        return emits ? Colors.alpha(backgroundColor, emittedAlpha) : Colors.alpha(Colors.light, alpha);
    }

    anchors.fill: parent
    z: -1

    Rectangle {
        anchors.fill: parent
        visible: !glass.liquid
        radius: glass.radius
        color: glass.fill
    }

    // The background turned to glass, fading downward.
    Rectangle {
        anchors.fill: parent
        visible: glass.liquid
        radius: glass.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Colors.alpha(glass.fill, glass.fill.a * 0.6)
            }

            GradientStop {
                position: 1
                color: Colors.alpha(glass.fill, glass.fill.a * 0.4)
            }

        }

    }

    // The frost, under the pointer only.
    Rectangle {
        anchors.fill: parent
        opacity: glass.hovered ? 1 : 0
        visible: opacity > 0
        radius: glass.radius

        gradient: Gradient {
            GradientStop {
                position: 0
                color: Colors.alpha(Colors.light, 0.17)
            }

            GradientStop {
                position: 1
                color: Colors.alpha(Colors.light, 0.09)
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.color.duration
                easing.type: Motion.color.easing
            }

        }

    }

    // The rim, a touch thicker while emitting, with the halo of what emits.
    ShaderEffect {
        readonly property size size: Qt.size(glass.width, glass.height)
        readonly property real radius: glass.radius
        readonly property real rimWidth: (glass.liquid ? 3 : 1) + (glass.emits ? (glass.liquid ? 1 : 0.5) : 0)
        readonly property real soft: glass.liquid ? 1 : 0
        readonly property color rimTop: glass.rimColor(0.38, 0.95)
        readonly property color rimMiddle: glass.rimColor(0.06, 0.6)
        readonly property color rimBottom: glass.rimColor(0.16, 0.8)
        readonly property color glow: glass.emits ? Colors.alpha(glass.backgroundColor, 0.55 * glass.backgroundColor.a) : "transparent"
        readonly property real reach: glass.reach
        readonly property real margin: glass.reach

        anchors.fill: parent
        anchors.margins: -glass.reach
        fragmentShader: "glassrim.frag.qsb"
    }

}
