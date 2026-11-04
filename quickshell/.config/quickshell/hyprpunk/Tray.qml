pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// The apps running in the background, shown in the control center, and whether one is
// waiting for you, which the control pill shows with a dot.
Singleton {
    // Apps that say they're idle stay out, as the tray standard asks.
    readonly property var items: SystemTray.items.values.filter((item) => {
        return item.status !== Status.Passive;
    })
    readonly property bool needsAttention: items.some((item) => {
        return item.status === Status.NeedsAttention;
    })

    // The app's title, falling back on its tooltip and its id when it leaves the title empty.
    function name(item) {
        return item.title || firstLine(item.tooltipTitle) || item.id;
    }

    // What the app says about itself in its tooltip (Nextcloud: "Last sync was
    // successful"), on one line and without its markup.
    function detail(item) {
        const title = firstLine(item.tooltipTitle);
        if (title !== "" && title !== name(item))
            return title;

        return firstLine(item.tooltipDescription);
    }

    function firstLine(text) {
        return (text || "").replace(/<[^>]*>/g, "").trim().split("\n")[0].trim();
    }
}
