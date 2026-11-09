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
    // Opens something on a click (clicked()): it answers the pointer like the control
    // center's blocks (PillZoom).
    property bool clickable: false
    // The pointer is on the pill's spot in the card that covers it, which takes the
    // pointer from the pill: it stays lit, so the card folds back onto the pill as
    // you'll see it.
    property bool spotHovered: false
    readonly property bool lit: clickable && (hovered || spotHovered)
    // How far its zoom draws it past its place in the row (PillZoom).
    readonly property real spreadX: pillZoom.spreadX
    readonly property real spreadY: pillZoom.spreadY
    property int spacing: 10
    property int horizontalPadding: 20
    // The panels' card: base at 0.9, blurred by the shell's layer rule. Drawn by the glass
    // rather than the pill, so the liquid style can make it see-through.
    readonly property color baseColor: Theme.panel

    implicitWidth: contentRow.implicitWidth + horizontalPadding
    implicitHeight: Theme.pillHeight
    radius: height / 2
    color: "transparent"
    clip: true
    signal clicked()

    transform: PillZoom {
        id: pillZoom

        pill: pill
        active: pill.lit
        pressed: pillTap.pressed
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

    TapHandler {
        id: pillTap

        enabled: pill.clickable
        cursorShape: Qt.PointingHandCursor
        // Pressed as long as you like: it squeezes, and opens on release.
        longPressThreshold: 0
        onTapped: pill.clicked()
    }

    RowLayout {
        id: contentRow

        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
