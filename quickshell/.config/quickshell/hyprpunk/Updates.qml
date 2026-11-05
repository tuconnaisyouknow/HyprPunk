pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The pending package updates, official repos and AUR counted together, for the bar's
// updates pill. Checked at startup, every 15 minutes, and after anything pacman does,
// from the pill or from a terminal.
Singleton {
    id: updates

    property int count: 0
    // Asked while a check was running: it would only see the state from before.
    property bool checkAgain: false

    function check() {
        if (countProcess.running)
            checkAgain = true;
        else
            countProcess.running = true;
    }

    // In your terminal, where yay asks before it changes anything. Counted again from
    // pacman's log.
    function upgrade() {
        Session.launchInTerminal(["yay", "-Syu", "--removemake"]);
    }

    // Both at once, since they ask different servers: the repos through your mirror, the
    // AUR on its own site.
    Process {
        id: countProcess

        command: ["sh", "-c", "{ checkupdates & yay -Qua & wait; } 2>/dev/null | wc -l"]
        running: true
        onExited: {
            if (updates.checkAgain) {
                updates.checkAgain = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                updates.count = isNaN(count) ? 0 : count;
            }
        }

    }

    // pacman writes its log as it syncs, installs or removes, wherever you run it from.
    // Only watched, never read.
    FileView {
        path: "/var/log/pacman.log"
        preload: false
        watchChanges: true
        printErrors: false
        onFileChanged: afterPacman.restart()
    }

    // Once a transaction has gone quiet, not at each of its lines.
    Timer {
        id: afterPacman

        interval: 3000
        onTriggered: updates.check()
    }

    // Cheap: the mirror only sends its package list again when it has changed.
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updates.check()
    }

}
