import QtQuick

// The keyboard focus of the control center and the settings window: which control the
// keys act on, how they move to another, and the accent ring around it. A control takes
// part by turning on activeFocusOnTab and giving activate() (its click) and, when it has
// a small second button, activateAlt(). Fields draw their own ring (drawsFocus).
Item {
    id: keyboardFocus

    // The page shown, whose controls the keys move through.
    property Item page: null
    // What has the keyboard while no control does.
    property Item home: null
    // You've moved with the keys since the panel opened: a new page then hands its
    // control the keyboard at once, the one you left it on or its first.
    property bool navigating: false
    // The last control of each page.
    property var memory: new Map()
    // The control with the keyboard, null while the page itself has it.
    readonly property Item current: {
        const item = Window.activeFocusItem;
        return item !== null && item.activeFocusOnTab && contains(item) ? item : null;
    }

    onCurrentChanged: {
        if (current !== null)
            memory.set(page, current);

    }

    function contains(item) {
        for (let parent = item; parent !== null; parent = parent.parent) {
            if (parent === page)
                return true;

        }
        return false;
    }

    function controls() {
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
        if (page !== null)
            walk(page);

        return found;
    }

    function rect(item) {
        return item.mapToItem(page, 0, 0, item.width, item.height);
    }

    // In reading order, for Tab and the first key.
    function ordered() {
        return controls().map((item) => {
            return {
                "item": item,
                "rect": rect(item)
            };
        }).sort((a, b) => {
            return (a.rect.y - b.rect.y) || (a.rect.x - b.rect.x);
        }).map((entry) => {
            return entry.item;
        });
    }

    // The closest control that way, its centre past the current one's: overlapping it
    // across the move counts most, so down from a tile goes to the one under it.
    function neighbour(dx, dy) {
        const from = rect(current);
        const centre = (r) => {
            return Qt.point(r.x + r.width / 2, r.y + r.height / 2);
        };
        const start = centre(from);
        let best = null;
        let bestScore = Infinity;
        for (const item of controls()) {
            if (item === current)
                continue;

            const to = rect(item);
            const end = centre(to);
            const along = dx !== 0 ? (end.x - start.x) * dx : (end.y - start.y) * dy;
            if (along <= 0)
                continue;

            const gap = dx !== 0 ? Math.max(0, Math.max(from.y, to.y) - Math.min(from.y + from.height, to.y + to.height)) : Math.max(0, Math.max(from.x, to.x) - Math.min(from.x + from.width, to.x + to.width));
            const across = dx !== 0 ? Math.abs(end.y - start.y) : Math.abs(end.x - start.x);
            const score = along + 4 * gap + across / 100;
            if (score < bestScore) {
                best = item;
                bestScore = score;
            }
        }
        return best;
    }

    // The page's control you were last on, or its first.
    function landing() {
        const list = ordered();
        const remembered = memory.get(page);
        return list.includes(remembered) ? remembered : list[0];
    }

    // An arrow: to the neighbour that way, or back onto the page while no control has
    // the keyboard.
    function move(dx, dy) {
        const target = current === null ? landing() : neighbour(dx, dy);
        if (target)
            take(target);

    }

    // Once a new page is shown. One that gave a field the keyboard itself keeps it.
    function settle() {
        if (Window.activeFocusItem !== null && contains(Window.activeFocusItem))
            return ;

        const target = navigating ? landing() : null;
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
        const list = ordered();
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

        // Follows the control as the page slides, the list scrolls or it bounces.
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
        border.color: Theme.alpha(Theme.primary, 0.85)
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
