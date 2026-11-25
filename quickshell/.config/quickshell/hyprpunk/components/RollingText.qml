import QtQuick
import qs.theme

// Text whose characters roll like a counter's: one that changes leaves upward as the next
// rises from below in its place, the rightmost first and each one to its left a moment
// later, like a carry. The time is written with it everywhere, and the counts that move
// a step at a time (the battery, the volume); it takes Label's look.
Item {
    id: rolling

    property string text
    property alias font: sizer.font
    property alias color: sizer.color
    // Off, a new text takes its place at once.
    property bool animated: true
    // How long it waits before rolling, after another text it carries from.
    property int wait: 0
    // Its first text is there from the start: only a change rolls.
    property bool settled: false
    // A number that goes down as well as up: it rolls the other way when it drops. The time
    // only moves on, even past midnight, so it always rises.
    property bool bothWays: false

    // Brings each cell to its new character, counted from the right: a longer text grows
    // on the left, and a cell left empty folds to nothing.
    function update() {
        let written = "";
        for (let k = 0; k < cells.count; k++)
            written = (repeater.itemAt(k)?.glyph ?? "") + written;
        const way = bothWays && parseFloat(text) < parseFloat(written) ? -1 : 1;
        while (cells.count < text.length)
            cells.append({});
        let rank = 0;
        for (let k = 0; k < cells.count; k++) {
            const cell = repeater.itemAt(k);
            const at = text.length - 1 - k;
            const glyph = at >= 0 ? text[at] : "";
            if (cell !== null && cell.glyph !== glyph)
                cell.roll(glyph, settled && animated ? wait + rank++ * Motion.stagger : -1, way);

        }
    }

    // The digits from their top to the baseline, in the line.
    readonly property real inkTop: sizer.baselineOffset + digitInk.tightBoundingRect.y
    readonly property real inkHeight: digitInk.tightBoundingRect.height

    // Its cells' widths summed rather than the row's, which a row only learns when it
    // lays out before a frame: the island around it would be drawn empty a frame (a
    // circle where the lock first shows it), then ease out to the time's width.
    implicitWidth: {
        let width = 0;
        for (let k = 0; k < repeater.count; k++)
            width += repeater.itemAt(k)?.width ?? 0;
        return width;
    }
    implicitHeight: sizer.implicitHeight
    baselineOffset: sizer.baselineOffset
    onTextChanged: update()
    Component.onCompleted: {
        update();
        settled = true;
    }

    // The look, and one line's height and baseline.
    Label {
        id: sizer

        visible: false
        text: "0"
    }

    TextMetrics {
        id: digitInk

        text: "0123456789"
        font: sizer.font
    }

    // Its cells never go: one emptied by a shorter text is nothing wide.
    ListModel {
        id: cells
    }

    Row {
        layoutDirection: Qt.RightToLeft

        Repeater {
            id: repeater

            model: cells

            Item {
                id: cell

                property string glyph
                property string previous
                // 0 with the old character in place, 1 with the new one.
                property real progress: 1
                // 1 when the new one rises from below, -1 when it falls from above.
                property int way: 1

                // What's showing leaves: the old character if the roll hasn't started yet,
                // the one on its way otherwise.
                function roll(next, after, way) {
                    if (progress > 0)
                        previous = glyph;

                    glyph = next;
                    cell.way = way;
                    turn.stop();
                    if (after < 0) {
                        progress = 1;
                    } else {
                        progress = 0;
                        delay.duration = after;
                        turn.start();
                    }
                }

                // Goes from one character's width to the other's, never past either.
                width: was.implicitWidth + (now.implicitWidth - was.implicitWidth) * Math.min(1, progress)
                height: rolling.implicitHeight

                // The window they pass through: the digits' ink, and a little room for the new
                // one to land past its place. The line itself is far taller than the digits,
                // which would be seen floating outside it.
                Item {
                    id: window

                    readonly property real margin: Math.ceil(rolling.inkHeight / 10)

                    y: rolling.inkTop - margin
                    width: parent.width
                    height: rolling.inkHeight + 2 * margin
                    clip: turn.running

                    Text {
                        id: was

                        y: -window.y - window.height * cell.progress * cell.way
                        visible: cell.progress < 1
                        text: cell.previous
                        font: rolling.font
                        color: rolling.color
                    }

                    Text {
                        id: now

                        y: -window.y + window.height * (1 - cell.progress) * cell.way
                        text: cell.glyph
                        font: rolling.font
                        color: rolling.color
                    }

                }

                SequentialAnimation {
                    id: turn

                    PauseAnimation {
                        id: delay
                    }

                    Anim {
                        target: cell
                        property: "progress"
                        to: 1
                        token: Motion.roll
                    }

                }

            }

        }

    }

}
