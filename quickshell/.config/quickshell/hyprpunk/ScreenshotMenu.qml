import QtQuick
import Quickshell

// The screenshot menu, laid out like the main menu: capture the screen, a region,
// or a region to annotate, or record the screen or a region (or stop the recording).
IconMenu {
    id: menu

    // mode: the screenshot taken, or the recording started, on this screen; badge: a
    // small icon at the bottom right of the icon.
    entries: [{
        "icon": "󰍹",
        "name": "Screen",
        "mode": "screen"
    }, {
        "icon": "󰒉",
        "name": "Region",
        "mode": "region"
    }, {
        "icon": "󰏫",
        "name": "Region and annotate",
        "mode": "annotate"
    }].concat(shellState.recording ? [{
        "icon": "󰓛",
        "name": "Stop recording",
        "mode": "stop"
    }] : [{
        "icon": "󰕧",
        "name": "Record screen",
        "mode": "record"
    }, {
        "icon": "󰒉",
        "badge": "󰕧",
        "name": "Record region",
        "mode": "record-region"
    }])

    panelName: "screenshot"
    onOpening: selectedIndex = 0
    // Waits for the card to fold away, so it isn't in the picture.
    onChosen: (entry) => {
        close();
        shellState.requestScreenshot(entry.mode, screen.name, entry.mode === "stop" ? 0 : 380);
    }
}
