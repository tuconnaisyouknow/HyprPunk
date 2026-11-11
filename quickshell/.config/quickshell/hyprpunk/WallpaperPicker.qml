import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper picker: a looping carousel of the current theme's wallpapers, in
// wallpaperctl.sh's order, that opens on your current one.
// Arrows, Tab or the wheel to browse, Enter or a click on the middle one to apply.
IslandPanel {
    id: picker

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

    // A new wallpaper may be another theme's: its list is ready, images and all, by the
    // time the picker opens.
    Connections {
        function onWallpaperChanged() {
            listProcess.running = true;
        }

        target: Session
    }

    Process {
        id: listProcess

        command: [picker.wallpaperctl, "list"]
        running: true

        stdout: StdioCollector {
            // A wallpaper and its thumbnail per line, a tab between them.
            onStreamFinished: carousel.setItems(text.split("\n").filter((line) => {
                return line !== "";
            }).map((line) => {
                const [path, thumbnail] = line.split("\t");
                return {
                    "id": path,
                    "image": thumbnail
                };
            }))
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

    CarouselKeys {
        id: keys

        panel: picker
        carousel: carousel
        onPicked: picker.apply()
    }


    ImageCarousel {
        id: carousel

        currentId: Session.wallpaper
        anchors.top: parent.top
        anchors.topMargin: picker.cardPadding
        anchors.left: parent.left
        anchors.right: parent.right
        onActivated: picker.apply()
    }

}
