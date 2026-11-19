pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Your screens as displayctl.sh sees them, and changing their settings. Read at startup,
// then again each time someone looks (ServiceRef: the settings' displays page). A new
// resolution, refresh rate or scale undoes itself unless you keep it in time, and at once
// when nobody looks any more.
Singleton {
    id: displays

    readonly property string displayctl: Session.scripts + "/displayctl.sh"
    readonly property int revertSeconds: 15
    property int refCount: 0
    // From displayctl info: { layout, outputs: [...] }.
    property var info: ({
        "layout": "auto",
        "outputs": []
    })
    // Seconds left before the last guarded change reverts, 0 when none.
    property alias revertCountdown: kept.revertCountdown
    readonly property bool busy: applier.running || reader.running

    function refresh() {
        reader.running = true;
    }

    // guarded: a mode or scale change, which displayctl can undo.
    function apply(args, guarded) {
        if (busy)
            return ;

        applier.command = [displayctl].concat(guarded ? ["try"] : [], args);
        applier.running = true;
        if (guarded) {
            revertCountdown = revertSeconds;
            countdown.restart();
        }
    }

    function keep() {
        revertCountdown = 0;
        countdown.stop();
    }

    function revert() {
        keep();
        Quickshell.execDetached([displayctl, "undo"]);
        revertRefresh.restart();
    }

    onRefCountChanged: {
        if (refCount === 1)
            refresh();
        else if (refCount === 0 && revertCountdown > 0)
            revert();
    }

    // The countdown goes on through a reload: forgotten, a change you never kept would
    // stay, even one that left the screen unusable.
    PersistentProperties {
        id: kept

        property int revertCountdown: 0

        reloadableId: "displays"
        onReloaded: {
            if (revertCountdown > 0)
                countdown.restart();

        }
    }

    Process {
        id: reader

        command: [displays.displayctl, "info"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    displays.info = JSON.parse(text);
                } catch (error) {
                    console.warn("displayctl info:", error);
                }
            }
        }

    }

    Process {
        id: applier

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                displays.keep();
                Quickshell.execDetached(["notify-send", "-u", "normal", "Unable to change the display settings", errors.text.trim().split("\n").pop() || ""]);
            }
            displays.refresh();
        }

        stderr: StdioCollector {
            id: errors
        }

    }

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            displays.revertCountdown -= 1;
            if (displays.revertCountdown <= 0)
                displays.revert();

        }
    }

    // Hyprland takes a moment to apply the restored state.
    Timer {
        id: revertRefresh

        interval: 600
        onTriggered: displays.refresh()
    }

}
