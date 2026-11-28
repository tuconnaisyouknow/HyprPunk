import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.theme

// A workspace's app, as its icon: the window you were last on there, which Hyprland gives
// the focus as you arrive, or a desktop's outline while it's empty. Going to another
// workspace, it rolls like RollingText's digits: up when you go further, down when you
// come back. The island shows it as you switch (IslandView).
Item {
    id: app

    // The HyprlandWorkspace.
    property var workspace: null
    property bool animated: true
    property real size: Metrics.text.heading
    // Its icon right now: "" while it's empty. The focus lands on a window a moment after
    // the workspace changes, and the icon follows without rolling again.
    readonly property string source: iconOf(workspace)
    // What's showing, and what's leaving: icon paths, "" for the outline.
    property string current: ""
    property string previous: ""
    // The workspace it last rolled to, and how far along: 0 with the old icon in place, 1
    // with the new one. 1 when the new one rises from below, -1 when it falls from above.
    property var rolledTo: null
    property real progress: 1
    property int way: 1
    // What the icon showing leaves empty on each side of its box, and what it draws: apps'
    // icons come with a margin of their own, and the island measures its gaps from what's
    // drawn. The outline fills its box.
    property real inkLeft: 0
    property real inkRight: 0
    readonly property real inkWidth: width - inkLeft - inkRight

    function iconOf(workspace) {
        if (workspace === null)
            return "";

        const windows = workspace.toplevels.values;
        const window = windows.find((toplevel) => {
            return toplevel.activated;
        }) || windows[0] || null;
        if (window === null)
            return "";

        const appId = window.wayland !== null ? window.wayland.appId : ((window.lastIpcObject || {}).class || "");
        const entry = DesktopEntries.heuristicLookup(appId);
        return Quickshell.iconPath(entry !== null ? entry.icon : "", "application-x-executable");
    }

    // A whole, even number of pixels, the outline on a whole pixel inside: in the island's
    // middle it lands on whole pixels, where the glyph, drawn snapped to them, holds still.
    implicitWidth: 2 * Math.round(size / 2)
    implicitHeight: implicitWidth
    onWorkspaceChanged: {
        const from = rolledTo;
        previous = current;
        current = iconOf(workspace);
        rolledTo = workspace;
        turn.stop();
        if (from === null || workspace === null || !animated) {
            progress = 1;
            return ;
        }
        way = workspace.id > from.id ? 1 : -1;
        progress = 0;
        turn.start();
    }
    onSourceChanged: {
        if (workspace === rolledTo)
            current = source;

    }

    // The window they pass through, a little taller than the icon so it lands past its
    // place without being cut.
    Item {
        id: passage

        readonly property real margin: Math.ceil(app.size / 10)

        y: -margin
        width: app.width
        height: app.height + 2 * margin
        clip: turn.running

        AppGlyph {
            y: passage.margin - passage.height * app.progress * app.way
            visible: app.progress < 1
            source: app.previous
        }

        AppGlyph {
            y: passage.margin + passage.height * (1 - app.progress) * app.way
            source: app.current
        }

    }

    // Measures the icon's margins once per icon, drawn out of sight at its size: the first
    // and last columns with anything in them.
    Canvas {
        id: inkProbe

        readonly property string icon: app.current

        function measure() {
            if (icon === "") {
                app.inkLeft = 0;
                app.inkRight = 0;
            } else if (isImageLoaded(icon)) {
                requestPaint();
            } else {
                loadImage(icon);
            }
        }

        width: app.width
        height: app.height
        opacity: 0
        onIconChanged: measure()
        onImageLoaded: measure()
        onPaint: {
            if (icon === "" || !isImageLoaded(icon))
                return ;

            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            context.drawImage(icon, 0, 0, width, height);
            const pixels = context.getImageData(0, 0, width, height).data;
            let first = width;
            let last = -1;
            for (let x = 0; x < width; x++) {
                for (let y = 0; y < height; y++) {
                    // Nearly transparent pixels are the edges' softening, not ink.
                    if (pixels[(y * width + x) * 4 + 3] > 24) {
                        first = Math.min(first, x);
                        last = x;
                        break;
                    }
                }
            }
            app.inkLeft = last < 0 ? 0 : first;
            app.inkRight = last < 0 ? 0 : width - 1 - last;
        }
    }

    Anim {
        id: turn

        target: app
        property: "progress"
        to: 1
        token: Motion.roll
    }

    // An app's icon, or the outline of an empty desktop, off like anything unavailable.
    component AppGlyph: Item {
        property string source

        width: app.width
        height: app.height

        IconImage {
            anchors.fill: parent
            visible: parent.source !== ""
            source: parent.source
            implicitSize: app.width
        }

        // Placed by hand: centerIn rounds as it goes, and the glyph would step a pixel as the
        // island grows around it.
        Icon {
            x: Math.round((parent.width - implicitWidth) / 2)
            y: Math.round((parent.height - implicitHeight) / 2)
            visible: parent.source === ""
            text: "desktop_windows"
            color: Colors.alpha(Colors.secondary, 0.5)
            // Material draws it across the whole size it's given.
            size: app.width
        }

    }

}
