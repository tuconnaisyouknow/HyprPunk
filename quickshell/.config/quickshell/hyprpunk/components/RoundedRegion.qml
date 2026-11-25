import QtQuick
import Quickshell

// The blur behind a glass with round corners (a pill, a card), on the pixels the glass
// covers: a row of pixels is in when the glass covers its middle. Quickshell's own radius
// builds its corners from Qt's ellipses, which stop short of the glass at the top and
// spill past it at the bottom: the round ends looked uneven, the sharp wallpaper showing
// through the glass on one side and blur stepping out of it on the other.
// Each round row is a region of its own, the straight part in between one more.
Region {
    id: region

    // The glass's box, in the window, and the radius of its corners.
    property rect box: Qt.rect(0, 0, 0, 0)
    property real cornerRadius: 0
    // On whole pixels, which is all a region can hold.
    readonly property int left: Math.round(box.x)
    readonly property int top: Math.round(box.y)
    readonly property int right: Math.round(box.x + box.width)
    readonly property int bottom: Math.round(box.y + box.height)
    readonly property real usedRadius: Math.max(0, Math.min(cornerRadius, (right - left) / 2, (bottom - top) / 2))
    // How many rows each end of the corners spans.
    readonly property int roundRows: Math.ceil(usedRadius)

    // How far the glass's edge is from the box's side on a round row, counted from the
    // top or the bottom: its first pixel is the first whose middle is in the glass.
    function inset(row) {
        const fromCenter = usedRadius - (row + 0.5);
        if (fromCenter <= 0)
            return 0;

        return Math.round(usedRadius - Math.sqrt(usedRadius * usedRadius - fromCenter * fromCenter));
    }

    x: left
    y: top + roundRows
    width: right - left
    height: Math.max(0, bottom - top - 2 * roundRows)
    regions: region.rows.instances

    // One per round row, the top ones then the bottom ones. Kept by their place while the
    // radius changes, so a card's corners easing to their size only add or drop rows.
    // A property rather than a child: a region only holds regions.
    readonly property Variants rows: Variants {
        model: Array.from({
            "length": 2 * region.roundRows
        }, (_, index) => {
            return index;
        })

        Region {
            required property int modelData
            readonly property bool fromTop: modelData < region.roundRows
            readonly property int row: fromTop ? modelData : modelData - region.roundRows
            readonly property int edge: region.inset(row)

            x: region.left + edge
            y: fromTop ? region.top + row : region.bottom - 1 - row
            width: Math.max(0, region.right - region.left - 2 * edge)
            height: 1
        }

    }

}
