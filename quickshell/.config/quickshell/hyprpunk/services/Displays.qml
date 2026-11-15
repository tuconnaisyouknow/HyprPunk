pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Your screens as displayctl.sh sees them, and changing their settings. A new
// resolution, refresh rate or scale undoes itself unless you keep it in time; once nobody
// looks (ServiceRef: the settings' displays page closed), it's kept.
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
    property int revertCountdown: 0
    readonly property bool busy: applier.running || reader.running

    function refresh() {
        reader.running = true;
    }

    // guarded: a mode or scale change, which displayctl can undo.
    function apply(args, guarded) {
        if (busy)
            return ;

        applier.command = [displayctl].concat(guarded ? ["try"] : [], args);
        if (guarded) {
            revertCountdown = revertSeconds;
            countdown.restart();
        }
        applier.running = true;
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
        else if (refCount === 0)
            keep();
    }

    Process {
        id: reader

        command: [displays.displayctl, "info"]

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
