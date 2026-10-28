import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper picker: a looping carousel that opens on your current one.
// Arrows, Tab or the wheel to browse, Enter or a click on the middle one to apply.
IslandPanel {
    id: picker

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/wallpaper.conf"
    readonly property string wallpaperctl: Quickshell.env("HOME") + "/Scripts/wallpaperctl.sh"
    readonly property int cardPadding: 14

    function apply() {
        const wallpaper = carousel.centreId;
        if (wallpaper === "")
            return ;

        if (wallpaper !== carousel.currentId) {
            applyProcess.command = [wallpaperctl, "set", wallpaper];
            applyProcess.running = true;
        }
        close();
    }

    panelName: "wallpaper"
    cardWidth: 820
    cardHeight: carousel.thumbHeight + 2 * cardPadding
    keyTargets: [keys]
    onOpening: {
        listProcess.running = true;
        carousel.centreOn(carousel.currentId);
    }

    Process {
        id: listProcess

        command: ["sh", "-c", "find -L \"$0\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort", picker.wallpaperDir]
        running: true

        stdout: StdioCollector {
            onStreamFinished: carousel.setItems(text.split("\n").filter((line) => {
                return line !== "";
            }).map((path) => {
                return {
                    "id": path,
                    "image": path
                };
            }))
        }

    }

    FileView {
        path: picker.stateFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const match = text().match(/^wallpaper=(.*)$/m);
            if (match)
                carousel.currentId = match[1];

        }
    }

    Process {
        id: applyProcess

        stderr: StdioCollector {
            id: applyErrors
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-u", "critical", "Unable to change wallpaper", applyErrors.text.trim()]);

        }
    }

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const direction = picker.horizontalKey(event);
            if (direction !== 0) {
                carousel.step(direction);
                event.accepted = true;
            }
        }
        Keys.onLeftPressed: carousel.step(-1)
        Keys.onRightPressed: carousel.step(1)
        Keys.onTabPressed: carousel.step(1)
        Keys.onBacktabPressed: carousel.step(-1)
        Keys.onReturnPressed: picker.apply()
        Keys.onEnterPressed: picker.apply()
    }

    ImageCarousel {
        id: carousel

        anchors.top: parent.top
        anchors.topMargin: picker.cardPadding
        anchors.left: parent.left
        anchors.right: parent.right
        onActivated: picker.apply()
    }

}
