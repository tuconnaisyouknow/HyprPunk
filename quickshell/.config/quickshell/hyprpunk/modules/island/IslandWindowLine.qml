import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme

// The window you're on, in the open island over your workspaces (IslandView): its app's
// icon, its title over the app's name. On an empty workspace, the line says so. A click
// opens the workspace preview, to see the others.
IslandBlock {
    id: line

    required property var screen
    readonly property var workspace: Hyprland.monitorFor(screen)?.activeWorkspace ?? null
    // The one focused there, or the first one while you're on another screen.
    readonly property var window: {
        const windows = workspace !== null ? workspace.toplevels.values : [];
        return windows.find((window) => {
            return window.activated;
        }) ?? windows[0] ?? null;
    }
    readonly property string appId: window?.wayland?.appId ?? ""
    readonly property var entry: appId !== "" ? DesktopEntries.heuristicLookup(appId) : null
    readonly property real slot: Metrics.islandBlockHeight

    radius: Metrics.spacing.normal

    IconImage {
        x: (line.slot - implicitSize) / 2
        y: (line.slot - implicitSize) / 2
        implicitSize: line.slot - 2 * Metrics.spacing.small
        visible: line.window !== null
        source: Quickshell.iconPath(line.entry?.icon ?? "", "application-x-executable")
    }

    IslandLineText {
        x: line.slot + Metrics.spacing.normal
        width: line.width - x - Metrics.spacing.normal
        visible: line.window !== null
        title: line.window?.title ?? ""
        detail: line.entry?.name ?? line.appId
    }

    // An empty workspace.
    IslandLineEmpty {
        width: line.width
        visible: line.window === null
        icon: "desktop_windows"
        label: "Nothing open"
    }

}
