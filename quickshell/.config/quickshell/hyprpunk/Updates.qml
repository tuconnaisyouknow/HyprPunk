pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The pending package updates, official repos and AUR counted together, for the bar's
// updates pill. Checked at startup, as often as the settings say (UpdateSettings), and
// after anything pacman does, from the pill or from a terminal. Turned off there, it
// counts nothing and the pill stays hidden.
Singleton {
    id: updates

    readonly property int count: UpdateSettings.packages ? found : 0
    property int found: 0
    // Asked while a check was running: it would only see the state from before.
    property bool checkAgain: false

    function check() {
        if (!UpdateSettings.packages)
            return;

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
        onExited: {
            if (updates.checkAgain) {
                updates.checkAgain = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                updates.found = isNaN(count) ? 0 : count;
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

    // Cheap: the mirror only sends its package list again when it has changed. Turning
    // the count back on counts at once, like the startup.
    Timer {
        interval: (UpdateSettings.interval || 15) * 60 * 1000
        running: UpdateSettings.packages
        repeat: true
        triggeredOnStart: true
        onTriggered: updates.check()
    }

}
