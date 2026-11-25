import QtQuick
import Quickshell
import qs.modules.island
import qs.services
import qs.state

// The screenshot menu, laid out like the session menu: capture the screen, a region,
// or a region to annotate, or record the screen or a region (or stop the recording).
IconMenu {
    id: menu

    // mode: the screenshot taken, or the recording started, on this screen. A region is
    // dashed, whether captured or recorded.
    entries: [{
        "icon": "monitor",
        "name": "Screen",
        "mode": "screen"
    }, {
        "icon": "screenshot_region",
        "name": "Region",
        "mode": "region"
    }, {
        "icon": "edit",
        "name": "Region and annotate",
        "mode": "annotate"
    }].concat(Screenshot.recording ? [{
        "icon": "stop",
        "name": "Stop recording",
        "mode": "stop"
    }] : [{
        "icon": "videocam",
        "name": "Record screen",
        "mode": "record"
    }, {
        "icon": "screen_record",
        "name": "Record region",
        "mode": "record-region"
    }])

    panelName: "screenshot"
    onOpening: selectedIndex = 0
    // Waits for the card to fold away, so it isn't in the picture.
    onChosen: (entry) => {
        close();
        Screenshot.request(entry.mode, screen.name, entry.mode === "stop" ? 0 : 380);
    }
}
