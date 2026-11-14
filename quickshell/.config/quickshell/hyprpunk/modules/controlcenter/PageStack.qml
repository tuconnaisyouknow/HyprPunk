import QtQuick
import qs.theme

// The control center's pages (ControlPage), one shown at a time. You go into a page and
// come back out the way you came: the pages you went through are its history, so a page
// opened from two places goes back to the one you came from. Going in slides the new
// page in from the right, coming back slides it in from the left (Motion.page).
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
    // Runs linearly from 0 to 1: the slide eases out, the fades below don't.
    property real progress: 1
    // Each page by its name.
    property var pages: ({
    })
    readonly property Item currentPage: pages[current] ?? null

    // Back past the main page: the panel closes.
    signal closeRequested()

    function go(next, direction) {
        previous = current;
        stack.direction = direction;
        history = next;
        slide.restart();
    }

    function push(name) {
        if (name !== current)
            go(history.concat([name]), 1);

    }

    function back() {
        if (history.length > 1)
            go(history.slice(0, -1), -1);
        else
            closeRequested();
    }

    // Back to a page you went through, past the ones after it.
    function backTo(name) {
        const index = history.lastIndexOf(name);
        if (index >= 0 && index < history.length - 1)
            go(history.slice(0, index + 1), -1);

    }

    // The panel folds back on the main page, without a slide.
    function reset() {
        slide.stop();
        history = ["main"];
        previous = "main";
        progress = 1;
    }

    function pageVisible(name) {
        return name === current || (progress < 1 && name === previous);
    }

    function pageX(name) {
        const slid = 1 - Math.pow(1 - progress, 3);
        if (name === current)
            return (1 - slid) * direction * width * Motion.page.slideIn;

        return -slid * direction * width * Motion.page.backOff;
    }

    function pageOpacity(name) {
        if (name === current)
            return Math.max(0, Math.min(1, (progress - 0.2) / 0.6));

        return Math.max(0, 1 - progress / 0.35);
    }

    implicitHeight: currentPage !== null ? currentPage.implicitHeight : 0
    Component.onCompleted: {
        const found = {
        };
        for (const child of children) {
            if (child.pageName !== undefined)
                found[child.pageName] = child;

        }
        pages = found;
    }

    NumberAnimation {
        id: slide

        target: stack
        property: "progress"
        from: 0
        to: 1
        duration: Motion.page.duration
    }

}
