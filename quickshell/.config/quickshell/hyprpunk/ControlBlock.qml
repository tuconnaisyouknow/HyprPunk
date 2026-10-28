import QtQuick

// A glass block of the control center. It grows a little under the pointer and
// bounces when pressed (call bounce()).
Item {
    id: block

    property real radius: 18
    readonly property alias hovered: blockHover.hovered
    // The same few pixels for every block, whatever its size.
    property real zoom: hovered ? 1 + 6 / Math.max(width, 1) : 1
    property real pressScale: 1

    function bounce() {
        bounceAnimation.restart();
    }

    scale: zoom * pressScale
    // Grows over its neighbours.
    z: hovered ? 1 : 0

    GlassSurface {
        radius: block.radius
        hovered: block.hovered
    }

    HoverHandler {
        id: blockHover
    }

    BounceAnimation {
        id: bounceAnimation

        target: block
        scaleProperty: "pressScale"
    }

    Behavior on zoom {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }

    }

}
