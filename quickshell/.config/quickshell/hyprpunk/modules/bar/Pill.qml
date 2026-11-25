import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// One of the bar's pills: its glass, with its content in a row. Clipped to its box so
// content never sticks out while it resizes; a plain clip rather than one to the rounded
// shape, which draws the content into a picture the zoom would blur. The content stays
// clear of the round ends anyway.
Rectangle {
    id: pill

    default property alias content: contentRow.data
    property alias contentOpacity: contentRow.opacity
    readonly property alias hovered: pillHover.hovered
    // Opens something on a click (clicked()): it answers the pointer like the control
    // center's blocks (PillZoom).
    property bool clickable: false
    // Answers the pointer by growing and lighting up. Off for the island alone in the bar,
    // which opens under the pointer instead.
    property bool lights: true
    // What a click does, under the pointer, when the pill doesn't say it.
    property string tip: ""
    // The pointer is on the pill's spot in the card that covers it, which takes the
    // pointer from the pill: it stays lit, so the card folds back onto the pill as
    // you'll see it.
    property bool spotHovered: false
    readonly property bool lit: clickable && lights && (hovered || spotHovered)
    // A card grown out of it is drawn over it: it hides, the card's glass would let it
    // through, and leaves the blur to the card. Both blurring the same place made it
    // darker under the card, until the card had folded back.
    property bool covered: false
    // Where that card shows the pill's content meanwhile (PillContent): the content moves
    // there, so what you see as the card grows out and folds back is still the pill's own.
    property Item carrier: null
    // Blurred behind by its screen's own window for now, like a card: the bar-sized blur
    // window shows its changes a frame late, and a pill resizing fast (the island opening)
    // left its blur's old shape showing behind it.
    property bool blurredAsCard: false
    // How far its zoom draws it past its place in the row (PillZoom).
    readonly property real spreadX: pillZoom.spreadX
    readonly property real spreadY: pillZoom.spreadY
    property int spacing: Metrics.spacing.normal
    // On each side.
    property int horizontalPadding: Metrics.pillPadding
    // The panels' card: base at 0.9, blurred behind (BlurShape). Drawn by the glass
    // rather than the pill, so the liquid style can make it see-through.
    readonly property color baseColor: Colors.panel

    implicitWidth: contentRow.implicitWidth + 2 * horizontalPadding
    implicitHeight: Metrics.pillHeight
    radius: height / 2
    color: "transparent"
    opacity: covered ? 0 : 1
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

    BlurShape {
        radius: pill.radius
        shown: !pill.covered && !pill.blurredAsCard
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

    // Below the pill, the bar being at the top.
    ToolTipArea {
        visible: pill.tip !== ""
        text: pill.tip
    }

    RowLayout {
        id: contentRow

        parent: pill.covered && pill.carrier !== null ? pill.carrier : pill
        anchors.centerIn: parent
        spacing: pill.spacing
    }

}
