pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The pending package updates, official repos and AUR counted together, for the bar's
// updates pill. Checked at startup, every hour and after an upgrade.
Singleton {
    id: updates

    property int count: 0

    function check() {
        countProcess.running = true;
    }

    // In a terminal, then counted again.
    function upgrade() {
        upgradeProcess.running = true;
    }

    Process {
        id: countProcess

        command: ["sh", "-c", "{ checkupdates; yay -Qua; } 2>/dev/null | wc -l"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt(text.trim());
                updates.count = isNaN(count) ? 0 : count;
            }
        }

    }

    Process {
        id: upgradeProcess

        command: ["kitty", "-e", "yay", "-Syu", "--noconfirm", "--removemake"]
        // The current locale, not the one the shell was started with.
        environment: Session.localeEnvironment
        onExited: updates.check()
    }

    Timer {
        interval: 60 * 60 * 1000
        running: true
        repeat: true
        onTriggered: updates.check()
    }

}
