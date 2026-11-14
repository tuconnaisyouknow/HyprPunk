pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// The shell's polkit agent: it answers the password prompts of pkexec, systemctl and
// the apps asking for admin rights (PolkitPrompt). Always on, since a prompt can come at
// any time.
Singleton {
    readonly property alias agent: agent

    PolkitAgent {
        id: agent
    }

}
