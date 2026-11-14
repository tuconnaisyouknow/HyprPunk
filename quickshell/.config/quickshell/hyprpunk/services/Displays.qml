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
    readonly property string stateFile: Session.stateDir + "/monitor-state.conf"
    readonly property string backupFile: Session.cacheDir + "/monitor-state.backup"
    readonly property int revertSeconds: 15
    property int refCount: 0
    // From displayctl info: { layout, default_scale, outputs: [...] }.
    property var info: ({
        "layout": "auto",
        "default_scale": "auto",
        "outputs": []
    })
    // Seconds left before the last guarded change reverts, 0 when none.
    property int revertCountdown: 0
    readonly property bool busy: applier.running || reader.running

    function refresh() {
        reader.running = true;
    }

    // guarded: a resolution, refresh rate or scale change, which can undo itself.
    function apply(args, guarded) {
        if (busy)
            return ;

        if (guarded) {
            applier.command = ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\"; if [[ -f $0 ]]; then cp -f \"$0\" \"$1\"; else rm -f \"$1\"; fi; shift; exec \"$@\"", stateFile, backupFile, displayctl].concat(args);
            revertCountdown = revertSeconds;
            countdown.restart();
        } else {
            applier.command = [displayctl].concat(args);
        }
        applier.running = true;
    }

    function keep() {
        revertCountdown = 0;
        countdown.stop();
    }

    function revert() {
        keep();
        Quickshell.execDetached(["bash", "-c", "flock -w 10 \"$0.lock\" bash -c 'if [[ -f $1 ]]; then cp -f \"$1\" \"$0\"; else rm -f \"$0\"; fi' \"$0\" \"$1\" && \"$2\" reload", stateFile, backupFile, displayctl]);
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
