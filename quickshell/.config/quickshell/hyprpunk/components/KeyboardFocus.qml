import QtQuick
import qs.theme

// The keyboard focus of the control center and the settings window: which control the
// keys act on, how they move to another, and the accent ring around it. A control takes
// part by turning on activeFocusOnTab and giving activate() (its click) and, when it has
// a small second button, activateAlt(). Fields draw their own ring (drawsFocus).
// The page is made of columns: up and down never leave one, left and right follow the
// row you're on, then cross to the next column, where you left it. A control hidden
// while it has the keyboard hands it back to the last one you were on that's still there.
Item {
    id: keyboardFocus

    // The page shown, whose controls the keys move through.
    property Item page: null
    // Its columns, from left to right. A page that names none is one column.
    property var columns: []
    // What has the keyboard while no control does.
    property Item home: null
    // You've moved with the keys since the panel opened: a new page then hands its
    // control the keyboard at once, the one you left it on or its first.
    property bool navigating: false
    // The controls you were on in each page and each column, the latest first.
    property var memory: new Map()
    // The control with the keyboard, null while the page itself has it. One you can't
    // see doesn't count: Qt leaves the keyboard to what gets hidden.
    readonly property Item current: {
        const item = Window.activeFocusItem;
        return item !== null && item.activeFocusOnTab && item.visible && contains(item) ? item : null;
    }

    onCurrentChanged: {
        if (current !== null) {
            remember(page, current);
            remember(columnOf(current), current);
            return ;
        }
        // Hidden with the keyboard still on it (a prompt you gave up): the keys go back
        // to where you were.
        const item = Window.activeFocusItem;
        if (item !== null && !item.visible && contains(item))
            Qt.callLater(settle);

    }

    function remember(scope, item) {
        memory.set(scope, [item].concat((memory.get(scope) || []).filter((other) => {
            return other !== item;
        })));
    }

    function within(item, ancestor) {
        for (let parent = item; parent !== null; parent = parent.parent) {
            if (parent === ancestor)
                return true;

        }
        return false;
    }

    function contains(item) {
        return within(item, page);
    }

    // The column a control is in: the page itself for one outside them all.
    function columnOf(item) {
        return columns.find((column) => {
            return within(item, column);
        }) || page;
    }

    // The controls of the page, or of one of its columns.
    function controls(scope) {
        const found = [];
        const walk = (item) => {
            for (const child of item.children) {
                if (!child.visible || !child.enabled)
                    continue;

                if (child.activeFocusOnTab)
                    found.push(child);

                walk(child);
            }
        };
        if (scope !== null)
            walk(scope);

        return found;
    }

    function rect(item) {
        return item.mapToItem(page, 0, 0, item.width, item.height);
    }

    // In reading order, one column after the other, for Tab and the first key.
    function ordered(scope) {
        return controls(scope).map((item) => {
            return {
                "item": item,
                "column": columns.indexOf(columnOf(item)),
                "rect": rect(item)
            };
        }).sort((a, b) => {
            return (a.column - b.column) || (a.rect.y - b.rect.y) || (a.rect.x - b.rect.x);
        }).map((entry) => {
            return entry.item;
        });
    }

    // The control of the column next that way. Those whose centre lies past the current
    // one's edge are that way: one beside it isn't above it for being a pixel taller.
    // The closest of them sets the row to land on, and the one of that row most in line
    // with the current one takes the keys, so down from a tile goes to the one under
    // it. Those centred under it are all in line, and the first of them wins: down from a
    // header onto a row of icons lands on the first. Left and right, only the controls
    // level with the current one count. Level means overlapping: entries stacked edge to
    // edge, like a menu's, would otherwise make one row, and up would skip one.
    function neighbour(dx, dy) {
        const sign = dx + dy;
        const span = (r, horizontal) => {
            return horizontal ? [r.x, r.x + r.width] : [r.y, r.y + r.height];
        };
        const gap = (a, b) => {
            return Math.max(0, Math.max(a[0], b[0]) - Math.min(a[1], b[1]));
        };
        const overlap = (a, b) => {
            return Math.min(a[1], b[1]) > Math.max(a[0], b[0]);
        };
        const middle = (s) => {
            return (s[0] + s[1]) / 2;
        };
        const from = rect(current);
        const fromAlong = span(from, dx !== 0);
        const fromAcross = span(from, dx === 0);
        const past = controls(columnOf(current)).filter((item) => {
            return item !== current;
        }).map((item) => {
            const along = span(rect(item), dx !== 0);
            const across = span(rect(item), dx === 0);
            return {
                "item": item,
                "along": along,
                "across": across,
                "distance": (middle(along) - fromAlong[sign > 0 ? 1 : 0]) * sign,
                "gap": gap(across, fromAcross),
                "offset": gap([middle(across), middle(across)], fromAcross)
            };
        }).filter((entry) => {
            return entry.distance > 0 && (dx === 0 || overlap(entry.across, fromAcross));
        });
        if (past.length === 0)
            return null;

        const closest = past.reduce((a, b) => {
            return b.distance < a.distance ? b : a;
        });
        return past.filter((entry) => {
            return overlap(entry.along, closest.along);
        }).reduce((a, b) => {
            return ((b.gap - a.gap) || (b.offset - a.offset)) < 0 ? b : a;
        }).item;
    }

    // The control with the keyboard has another level with it, so left and right have
    // somewhere to go.
    function inRow() {
        return current !== null && (neighbour(-1, 0) !== null || neighbour(1, 0) !== null);
    }

    // The closest column that way with a control to land on.
    function nextColumn(dx) {
        const centre = (column) => {
            return column.mapToItem(page, column.width / 2, 0).x;
        };
        const from = columnOf(current);
        let best = null;
        let bestAlong = Infinity;
        for (const column of columns) {
            const along = column === from ? 0 : (centre(column) - centre(from)) * dx;
            if (along > 0 && along < bestAlong && controls(column).length > 0) {
                best = column;
                bestAlong = along;
            }
        }
        return best;
    }

    // The last control you were on in the page or the column that's still there, or its
    // first.
    function landing(scope) {
        if (scope === null)
            return null;

        const list = ordered(scope);
        return (memory.get(scope) || []).find((item) => {
            return list.includes(item);
        }) || list[0];
    }

    // An arrow: to the neighbour that way, into the next column past the end of a row,
    // or back onto the page while no control has the keyboard.
    function move(dx, dy) {
        const target = current === null ? landing(page) : neighbour(dx, dy) || (dx !== 0 ? landing(nextColumn(dx)) : null);
        if (target)
            take(target);

    }

    // Once a new page is shown, or the control with the keyboard is hidden. A page that
    // gave a field the keyboard itself keeps it.
    function settle() {
        if (current !== null)
            return ;

        const target = navigating ? landing(page) : null;
        if (target)
            take(target);
        else if (home !== null)
            home.forceActiveFocus();
    }

    function forget() {
        navigating = false;
        memory = new Map();
    }

    // Tab and Shift+Tab, round the page.
    function step(delta) {
        const list = ordered(page);
        if (list.length === 0)
            return ;

        const index = list.indexOf(current);
        take(list[index < 0 ? (delta > 0 ? 0 : list.length - 1) : (index + delta + list.length) % list.length]);
    }

    // Gives the control the keyboard, scrolling its list to it.
    function take(item) {
        navigating = true;
        item.forceActiveFocus(Qt.TabFocusReason);
        for (let parent = item.parent; parent !== null && parent !== page; parent = parent.parent) {
            if (parent.contentItem === undefined || parent.contentY === undefined)
                continue;

            const top = item.mapToItem(parent.contentItem, 0, 0).y;
            if (top < parent.contentY)
                parent.contentY = top;
            else if (top + item.height > parent.contentY + parent.height)
                parent.contentY = top + item.height - parent.height;
        }
    }

    // The control's click, or its second button with Shift.
    function activate(alternative) {
        if (current === null)
            return ;

        navigating = true;
        if (alternative && typeof current.activateAlt === "function")
            current.activateAlt();
        else if (!alternative && typeof current.activate === "function")
            current.activate();
    }

    Rectangle {
        id: ring

        readonly property Item target: keyboardFocus.current !== null && keyboardFocus.current.drawsFocus !== true ? keyboardFocus.current : null

        // Follows the control as the page zooms, the list scrolls or it bounces.
        function follow() {
            const r = target.mapToItem(keyboardFocus, 0, 0, target.width, target.height);
            x = r.x - 3;
            y = r.y - 3;
            width = r.width + 6;
            height = r.height + 6;
        }

        visible: target !== null
        radius: (target !== null && target.radius !== undefined ? target.radius : 10) + 3
        color: "transparent"
        border.width: 1.5
        border.color: Colors.alpha(Colors.primary, 0.85)
        onTargetChanged: {
            if (target !== null)
                follow();

        }

        FrameAnimation {
            running: ring.visible
            onTriggered: ring.follow()
        }

    }

}
