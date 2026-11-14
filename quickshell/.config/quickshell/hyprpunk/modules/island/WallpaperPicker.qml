import QtQuick
import qs.config
import qs.services
import qs.theme

// The wallpaper picker: a looping carousel of the current theme's wallpapers, in
// wallpaperctl.sh's order, that opens on your current one. Under the one in the middle,
// its title and its palette's colors, to see the look before you pick it.
// Arrows, Tab or the wheel to browse, Enter or a click on the middle one to apply.
IslandPanel {
    id: picker

    readonly property int cardPadding: 14
    readonly property var centre: carousel.centreIndex >= 0 ? carousel.items[carousel.centreIndex] : null

    // The file's name, as a title: last-light-at-the-seaside-station.png gives
    // "Last light at the seaside station".
    function titleOf(path) {
        const name = path.split("/").pop().replace(/\.[^.]*$/, "").replace(/[-_]+/g, " ");
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    function showList() {
        carousel.setItems(Wallpapers.list.map((wallpaper) => {
            return {
                "id": wallpaper.path,
                "image": wallpaper.thumbnail,
                "colors": wallpaper.colors
            };
        }));
    }

    function apply() {
        const wallpaper = carousel.centreId;
        if (wallpaper === "")
            return ;

        if (wallpaper !== carousel.currentId)
            Wallpapers.set(wallpaper);

        close();
    }

    panelName: "wallpaper"
    cardWidth: 820
    cardHeight: carousel.thumbHeight + caption.height + 2 * cardPadding
    keyTargets: [keys]
    onOpening: carousel.centreOn(carousel.currentId)
    Component.onCompleted: showList()

    ServiceRef {
        service: Wallpapers
        active: picker.opened
    }

    // The list is kept up to date even while the picker is closed, images and all, so
    // it's ready by the time it opens.
    Connections {
        function onListChanged() {
            picker.showList();
        }

        target: Wallpapers
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
            color: Colors.primary
            font.family: Metrics.font
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
                    border.color: Colors.alpha(Colors.secondary, 0.3)
                }

            }

        }

    }

}
