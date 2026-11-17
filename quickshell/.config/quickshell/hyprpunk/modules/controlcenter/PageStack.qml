import QtQuick
import qs.components
import qs.theme

// The control center's pages (ControlPage), one shown at a time. You go into a page and
// come back out the way you came: the pages you went through are its history, so a page
// opened from two places goes back to the one you came from. You go into a page through
// the glass you opened it from, its door: the door opens up to the panel's edges with the
// new page inside it, while the page you leave grows past you with it. Coming back
// plays it the other way, the page closing onto its door (Motion.page).
Item {
    id: stack

    // The panel is open: what a page runs while you look at it runs then.
    required property bool opened
    // The most a page can take: past it, it scrolls.
    property real maxHeight: Infinity
    // The pages you went through, from the main page to the one shown.
    property var history: ["main"]
    readonly property string current: history[history.length - 1]
    property string previous: "main"
    // 1 going in, -1 coming back.
    property int direction: 1
    // Runs linearly from 0 to 1: the zoom eases out, the fades below don't.
    property real progress: 1
    // Where you last pointed, with the pointer or the keys (pointAt).
    property point pointed: Qt.point(width / 2, 0)
    // The door each page of the history was opened from, and the one opening or closing.
    property var doors: [noDoor]
    property var door: noDoor
    readonly property var noDoor: ({
        "x": 0,
        "y": 0,
        "width": 0,
        "height": 0,
        "radius": 0
    })
    // The panel's padding round the pages and its corners, which a door opens up to.
    property real padding: 0
    property real radius: 0
    // How far into the page behind the door you are: 0 before it, 1 inside.
    readonly property real entered: {
        const eased = 1 - Math.pow(1 - progress, 3);
        return direction > 0 ? eased : 1 - eased;
    }
    // The page behind the door and the one in front, and how much of the first the door
    // shows.
    readonly property Item innerPage: pages[direction > 0 ? current : previous] ?? null
    readonly property Item outerPage: pages[direction > 0 ? previous : current] ?? null
    readonly property rect opening: {
        const height = innerPage !== null ? innerPage.implicitHeight : 0;
        return Qt.rect(door.x * (1 - entered), door.y * (1 - entered), door.width + (width - door.width) * entered, door.height + (height - door.height) * entered);
    }
    // Each page by its name.
    property var pages: ({
    })
    readonly property Item currentPage: pages[current] ?? null

    // Back past the main page: the panel closes.
    signal closeRequested()

    // In this order the stack keeps the height of the page you're on until the move
    // starts: the panel never sees another one go by.
    function go(next, spots, through, direction) {
        zoom.stop();
        previous = current;
        stack.direction = direction;
        progress = 0;
        door = through;
        history = next;
        doors = spots;
        zoom.start();
    }

    // The keys' click has no pointer: the control they're on is where you point.
    function pointAt(item) {
        pointed = item.mapToItem(stack, item.width / 2, item.height / 2);
    }

    // The glass block you point at, or failing one the spot itself.
    function doorAt(spot) {
        let block = null;
        const walk = (item) => {
            for (const child of item.children) {
                if (!child.visible)
                    continue;

                if (child instanceof ControlBlock && child.contains(child.mapFromItem(stack, spot.x, spot.y)))
                    block = child;

                walk(child);
            }
        };
        if (currentPage !== null)
            walk(currentPage);

        if (block === null)
            return {
                "x": spot.x,
                "y": spot.y,
                "width": 0,
                "height": 0,
                "radius": 0
            };

        const shape = block.mapToItem(stack, 0, 0, block.width, block.height);
        return {
            "x": shape.x,
            "y": shape.y,
            "width": shape.width,
            "height": shape.height,
            "radius": block.radius
        };
    }

    function push(name) {
        if (name === current)
            return ;

        const through = doorAt(pointed);
        go(history.concat([name]), doors.concat([through]), through, 1);
    }

    function back() {
        if (history.length > 1)
            go(history.slice(0, -1), doors.slice(0, -1), doors[doors.length - 1], -1);
        else
            closeRequested();
    }

    // Back to a page you went through, past the ones after it.
    function backTo(name) {
        const index = history.lastIndexOf(name);
        if (index >= 0 && index < history.length - 1)
            go(history.slice(0, index + 1), doors.slice(0, index + 1), doors[index + 1], -1);

    }

    // The panel folds back on the main page, without a zoom.
    function reset() {
        zoom.stop();
        history = ["main"];
        doors = [noDoor];
        previous = "main";
        progress = 1;
    }

    function pageVisible(name) {
        return name === current || (progress < 1 && name === previous);
    }

    function pageOpacity(name) {
        if (name === current)
            return Math.max(0, Math.min(1, (progress - 0.05) / 0.4));

        return Math.max(0, 1 - progress / 0.35);
    }

    // From one page's height to the other's with the door, which so stays in the panel.
    implicitHeight: {
        const outer = outerPage !== null ? outerPage.implicitHeight : 0;
        const inner = innerPage !== null ? innerPage.implicitHeight : 0;
        return outer + (inner - outer) * entered;
    }
    Component.onCompleted: {
        const found = {
        };
        for (const child of children) {
            if (child.pageName !== undefined)
                found[child.pageName] = child;

        }
        pages = found;
    }

    // The door's glass, between the page you leave and the one inside it. It takes over
    // from the block it starts on and melts into the panel's glass once on its edges.
    Item {
        readonly property real spread: stack.padding * stack.entered

        x: stack.opening.x - spread
        y: stack.opening.y - spread
        z: 1
        width: stack.opening.width + 2 * spread
        height: stack.opening.height + 2 * spread
        visible: stack.progress < 1
        opacity: Math.min(1, stack.entered / Motion.page.doorIn, (1 - stack.entered) / Motion.page.doorOut)

        GlassSurface {
            radius: stack.door.radius + (stack.radius - stack.door.radius) * stack.entered
        }

    }

    // Over the whole stack, under the pages' own handlers, which it leaves the pointer to.
    HoverHandler {
        onPointChanged: stack.pointed = point.position
    }

    NumberAnimation {
        id: zoom

        target: stack
        property: "progress"
        from: 0
        to: 1
        duration: Motion.page.duration
    }

}
