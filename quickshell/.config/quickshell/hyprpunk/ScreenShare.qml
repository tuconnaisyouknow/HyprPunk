import QtQuick
import Quickshell
import Quickshell.Io

// Talks to ~/Scripts/screenshare-picker.sh, which xdg-desktop-portal-hyprland runs when
// an app asks to share your screen: holds the request, and sends back the screen, window
// or region you picked. The region is drawn with the screenshot selector.
Scope {
    id: share

    required property var shellState
    // {fifo, allowToken, windows: [{handle, title, class, address}]}, null when none.
    property var request: null
    // The screen whose region is being drawn, empty otherwise.
    property string regionScreen: ""
    // Whether the region's answer may come with a restore token.
    property bool regionRemember: false

    // A request came in, for shell.qml to open the picker.
    signal requested()

    // selection: xdph's "screen:…", "window:…" or "region:…", empty to cancel. remember
    // lets the app share the same thing again later without asking.
    function answer(selection, remember) {
        if (!request)
            return ;

        const line = selection === "" ? "" : (remember ? "r" : "") + "/" + selection;
        // Only into the script's fifo: once it's gone, a plain file would be left behind.
        Quickshell.execDetached(["sh", "-c", '[ -p "$1" ] && printf "%s\\n" "$2" > "$1"', "sh", request.fifo, line]);
        request = null;
        regionScreen = "";
    }

    function cancel() {
        answer("", false);
    }

    // Folds the picker away and lets you draw the region on that screen.
    function pickRegion(screenName, remember) {
        regionScreen = screenName;
        regionRemember = remember;
        // Once the card is gone, or it'd be in the frozen screen.
        shellState.requestScreenshot("share-region", screenName, 350);
    }

    // xdph's window list: <handle>[HC>]<class>[HT>]<title>[HE>]<address in decimal>[HA>]…
    function parseWindows(list) {
        return list.split("[HA>]").filter((entry) => {
            return entry.indexOf("[HC>]") > 0;
        }).map((entry) => {
            const handle = entry.substring(0, entry.indexOf("[HC>]"));
            const rest = entry.substring(entry.indexOf("[HC>]") + 5);
            const classEnd = rest.indexOf("[HT>]");
            const titleEnd = rest.indexOf("[HE>]");
            return {
                "handle": handle,
                "class": rest.substring(0, classEnd),
                "title": rest.substring(classEnd + 5, titleEnd),
                // Hex, the way Hyprland's own clients list writes it.
                "address": Number(rest.substring(titleEnd + 5)).toString(16)
            };
        });
    }

    Connections {
        function onScreenshotSelected(rect) {
            if (share.regionScreen === "")
                return ;

            if (rect === null) {
                // Changed your mind about the region: back to the picker.
                share.shellState.requestPanel("screenshare", "open", share.regionScreen);
                share.regionScreen = "";
                return ;
            }
            const values = [rect.x, rect.y, rect.width, rect.height].map(Math.round).join(",");
            share.answer("region:" + share.regionScreen + "@" + values, share.regionRemember);
        }

        target: share.shellState
    }

    IpcHandler {
        // Called by the script. allowToken: whether remembering starts on.
        function pick(fifo: string, allowToken: bool, windows: string): void {
            // An app that asks again before you've answered: its old request is dropped.
            share.cancel();
            share.request = {
                "fifo": fifo,
                "allowToken": allowToken,
                "windows": share.parseWindows(windows)
            };
            share.requested();
        }

        target: "screenshare"
    }

}
