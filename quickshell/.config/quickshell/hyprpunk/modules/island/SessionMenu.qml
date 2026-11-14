import QtQuick
import Quickshell

// The session menu: lock, log out, reboot, shut down. Arrows or Tab to choose,
// Enter or a click to go.
IconMenu {
    id: session

    // Destructive actions ask for a second click (or Enter).
    entries: [{
        "id": "lock",
        "icon": "󰌾",
        "confirm": false,
        "command": ["qs", "-c", "hyprpunk", "ipc", "call", "lock", "lock"]
    }, {
        "id": "logout",
        "icon": "",
        "confirm": true,
        "command": ["hyprctl", "dispatch", "hl.dsp.exit()"]
    }, {
        "id": "reboot",
        "icon": "󰑓",
        "confirm": true,
        "command": ["systemctl", "reboot"]
    }, {
        "id": "shutdown",
        "icon": "",
        "confirm": true,
        "command": ["systemctl", "poweroff"]
    }]

    panelName: "session"
    selectedIndex: -1
    labelShown: false
    hoverOnly: true
    onOpening: {
        armedIndex = -1;
        selectedIndex = -1;
    }
    onOpenedChanged: {
        if (!opened)
            armedIndex = -1;

    }
    // Moving away from an armed action disarms it.
    onSelectedIndexChanged: {
        if (armedIndex >= 0 && armedIndex !== selectedIndex)
            armedIndex = -1;

    }
    onChosen: (entry, index) => {
        if (entry.confirm && armedIndex !== index) {
            armedIndex = index;
            disarmDelay.restart();
            return ;
        }
        close();
        Quickshell.execDetached(entry.command);
    }

    Timer {
        id: disarmDelay

        interval: 3000
        onTriggered: session.armedIndex = -1
    }

}
