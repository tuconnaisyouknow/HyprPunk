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

    implicitWidth: size
    implicitHeight: size
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

        width: app.size
        height: app.size

        IconImage {
            anchors.fill: parent
            visible: parent.source !== ""
            source: parent.source
            implicitSize: app.size
        }

        Icon {
            anchors.centerIn: parent
            visible: parent.source === ""
            text: "desktop_windows"
            color: Colors.alpha(Colors.secondary, 0.5)
            size: app.size
        }

    }

}
