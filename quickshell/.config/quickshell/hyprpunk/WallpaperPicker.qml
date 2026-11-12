import QtQuick
import Quickshell
import Quickshell.Io

// The wallpaper picker: a looping carousel of the current theme's wallpapers, in
// wallpaperctl.sh's order, that opens on your current one. Under the one in the middle,
// its title and its palette's colors, to see the look before you pick it.
// Arrows, Tab or the wheel to browse, Enter or a click on the middle one to apply.
IslandPanel {
    id: picker

    readonly property string wallpaperctl: Session.scripts + "/wallpaperctl.sh"
    readonly property int cardPadding: 14
    readonly property var centre: carousel.centreIndex >= 0 ? carousel.items[carousel.centreIndex] : null

    // The file's name, as a title: last-light-at-the-seaside-station.png gives
    // "Last light at the seaside station".
    function titleOf(path) {
        const name = path.split("/").pop().replace(/\.[^.]*$/, "").replace(/[-_]+/g, " ");
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

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
    cardHeight: carousel.thumbHeight + caption.height + 2 * cardPadding
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
            // A wallpaper, its thumbnail and its palette's accent, secondary and
            // surface per line, a tab between them.
            onStreamFinished: carousel.setItems(text.split("\n").filter((line) => {
                return line !== "";
            }).map((line) => {
                const [path, thumbnail, ...colors] = line.split("\t");
                return {
                    "id": path,
                    "image": thumbnail,
                    "colors": colors
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

    Column {
        id: caption

        anchors.top: carousel.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        topPadding: 10
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: picker.centre ? picker.titleOf(picker.centre.id) : ""
            color: Theme.primary
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.Bold
        }

        // The colors the whole desktop takes with it. The surface would vanish on the
        // card without its faint outline.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: picker.centre ? picker.centre.colors : []

                Rectangle {
                    required property string modelData

                    width: 14
                    height: 14
                    radius: 7
                    color: modelData
                    border.width: 1
                    border.color: Theme.alpha(Theme.secondary, 0.3)
                }

            }

        }

    }

}
