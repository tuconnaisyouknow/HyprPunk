import QtQuick
import Quickshell
import Quickshell.Hyprland

// What belongs to one screen, made by ShellState for each of them and found with
// ShellState.forScreen().
QtObject {
    required property ShellScreen modelData
    readonly property ShellScreen screen: modelData
    // A window is fullscreen on the screen, over the shell's window (which stays in the
    // layer under fullscreen windows): the panels you ask for don't open there, the
    // prompts do (they show once it's gone). Maximized windows don't count, they leave
    // the bar its room.
    readonly property bool fullscreen: {
        const monitor = Hyprland.monitorFor(screen);
        const workspace = monitor !== null ? monitor.activeWorkspace : null;
        return workspace !== null && workspace.toplevels.values.some((toplevel) => {
            return toplevel.wayland !== null && toplevel.wayland.fullscreen;
        });
    }
}
