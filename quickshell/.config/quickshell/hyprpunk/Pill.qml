import QtQuick
import QtQuick.Layouts

// One of the bar's pills: its glass, with its content in a row. Clipped to its box so
// content never sticks out while it resizes; a plain clip rather than one to the rounded
// shape, which draws the content into a picture the zoom would blur. The content stays
// clear of the round ends anyway.
Rectangle {
    id: pill

    default property alias content: contentRow.data
    property alias contentOpacity: contentRow.opacity
    // Its glass alone, for content that goes into another pill's shape (the island's
    // OSD, beside a card).
    property alias glassOpacity: glass.opacity
    readonly property alias hovered: pillHover.hovered
    // Opens something on a click: it answers the pointer like the control center's
    // blocks, unless its card covers it, so the card grows from and folds back to its
    // resting size.
    property bool clickable: false
    readonly property bool lit: clickable && hovered && opacity > 0
    property int spacing: 10
    property int horizontalPadding: 20
    // The panels' card: base at 0.9, blurred by the shell's layer rule. Drawn by the glass
    // rather than the pill, so the liquid style can make it see-through.
    readonly property color baseColor: Theme.panel

    implicitWidth: contentRow.implicitWidth + horizontalPadding
    implicitHeight: 38
    radius: height / 2
    color: "transparent"
    clip: true
    transform: PillHoverScale {
        pill: pill
        active: pill.lit
    }

    GlassSurface {
        id: glass

        radius: pill.radius
        tinted: false
        hovered: pill.lit
        backgroundColor: pill.baseColor
    }

    HoverHandler {
        id: pillHover
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
