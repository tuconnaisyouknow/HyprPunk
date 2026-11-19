import QtQuick
import QtQuick.Layouts

// One of the bar's pills, as the shell draws them: its glass, with its content in a row,
// over the video blurred behind it. Hyprland blurs what's behind the shell's glass: here
// the pill shows its own piece of the blurred video (backdrop.frag).
Rectangle {
    id: pill

    default property alias content: contentRow.data
    // What's drawn under the content, over the glass: a light.
    property alias underlay: underlay.data
    // The video blurred, the whole bar's strip of it, laid out from the same corner as
    // the pill's parent.
    required property Item backdrop
    readonly property alias hovered: pillHover.hovered
    // Does something on a click (clicked()): it answers the pointer, growing a few pixels
    // under it and squeezing while pressed.
    property bool clickable: false
    readonly property bool lit: clickable && hovered
    property int spacing: Metrics.spacing.normal
    // How far above its place it is, as it comes.
    property real lift: 0

    signal clicked()

    implicitWidth: contentRow.implicitWidth + 2 * Metrics.pillPadding
    implicitHeight: Metrics.pillHeight
    width: implicitWidth
    height: implicitHeight
    y: Metrics.barTop - lift
    radius: height / 2
    color: "transparent"
    // Content never sticks out while the pill resizes.
    clip: true

    transform: Scale {
        id: zoom

        property real grown: pill.lit ? 1 + 6 / Math.max(pill.width, 1) : 1
        property real squeezed: pillTap.pressed ? Motion.squeeze(pill.width) : 1

        origin.x: pill.width / 2
        origin.y: pill.height / 2
        xScale: grown * squeezed
        yScale: grown * squeezed

        Behavior on grown {
            NumberAnimation {
                duration: Motion.move.duration
                easing.type: Motion.move.easing
            }

        }

        // Springing back a touch too far on release.
        Behavior on squeezed {
            NumberAnimation {
                duration: pillTap.pressed ? Motion.bounce.pressDuration : Motion.bounce.releaseDuration
                easing.type: pillTap.pressed ? Motion.bounce.pressEasing : Motion.bounce.releaseEasing
                easing.overshoot: Motion.bounce.overshoot
            }

        }

    }

    ShaderEffect {
        readonly property size size: Qt.size(width, height)
        readonly property real radius: pill.radius
        // Where the pill is in the blurred strip, as shares of it.
        readonly property vector4d place: Qt.vector4d(pill.x / pill.backdrop.width, pill.y / pill.backdrop.height, pill.width / pill.backdrop.width, pill.height / pill.backdrop.height)
        readonly property var source: pill.backdrop

        anchors.fill: parent
        z: -2
        fragmentShader: "backdrop.frag.qsb"
    }

    GlassSurface {
        radius: pill.radius
        hovered: pill.lit
        backgroundColor: Colors.panel
    }

    Item {
        id: underlay

        anchors.fill: parent
    }

    HoverHandler {
        id: pillHover
    }

    TapHandler {
        id: pillTap

        enabled: pill.clickable
        cursorShape: Qt.PointingHandCursor
        // Pressed as long as you like: it squeezes, and answers on release.
        longPressThreshold: 0
        onTapped: pill.clicked()
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
