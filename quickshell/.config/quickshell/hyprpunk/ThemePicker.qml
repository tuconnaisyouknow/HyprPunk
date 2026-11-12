import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The theme picker: a card per theme, showing the wallpaper it would switch to (its last
// one), its name and its motto. Picking a theme brings that wallpaper back, and with it
// the theme's whole look.
// Arrows, Tab or the Vim keys to choose, Enter, Space or a click to apply.
IslandPanel {
    id: picker

    readonly property string wallpaperctl: Session.scripts + "/wallpaperctl.sh"
    readonly property int cardPadding: 14
    readonly property int gap: 14
    readonly property int thumbWidth: 360
    readonly property int thumbHeight: 202
    readonly property var mottos: ({
        "neon": "the city never sleeps",
        "daydream": "but it dreams"
    })
    // [{ "name": theme, "wallpaper": path, "thumbnail": path }], in wallpaperctl.sh's order.
    property var themes: []
    property int selectedIndex: 0
    // The theme in use is the one whose last wallpaper is on screen.
    readonly property int currentIndex: themes.findIndex((theme) => {
        return theme.wallpaper === Session.wallpaper;
    })

    function select(delta) {
        if (themes.length > 0)
            selectedIndex = (selectedIndex + delta + themes.length) % themes.length;

    }

    function apply(index) {
        const theme = themes[index];
        if (!theme)
            return ;

        if (index !== currentIndex) {
            applyProcess.command = [wallpaperctl, "theme", theme.name];
            applyProcess.running = true;
        }
        close();
    }

    panelName: "theme"
    cardWidth: themes.length * thumbWidth + Math.max(0, themes.length - 1) * gap + 2 * cardPadding
    cardHeight: cards.height + 2 * cardPadding
    keyTargets: [keys]
    onOpening: listProcess.running = true

    Process {
        id: listProcess

        command: [picker.wallpaperctl, "themes"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                picker.themes = text.split("\n").filter((line) => {
                    return line !== "";
                }).map((line) => {
                    const [name, wallpaper, thumbnail] = line.split("\t");
                    return {
                        "name": name,
                        "wallpaper": wallpaper,
                        "thumbnail": thumbnail
                    };
                });
                picker.selectedIndex = Math.max(0, picker.currentIndex);
            }
        }

    }

    Process {
        id: applyProcess

        stderr: StdioCollector {
            id: applyErrors
        }

        onExited: (exitCode) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-u", "critical", "Unable to change theme", applyErrors.text.trim()]);

        }
    }

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const direction = picker.horizontalKey(event);
            if (direction !== 0)
                picker.select(direction);
            else if (Navigation.accepts(event))
                picker.apply(picker.selectedIndex);
            else
                return ;
            event.accepted = true;
        }
        Keys.onLeftPressed: picker.select(-1)
        Keys.onRightPressed: picker.select(1)
        Keys.onTabPressed: picker.select(1)
        Keys.onBacktabPressed: picker.select(-1)
    }

    Row {
        id: cards

        anchors.top: parent.top
        anchors.topMargin: picker.cardPadding
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: picker.gap

        Repeater {
            model: picker.themes

            Column {
                id: themeCard

                required property var modelData
                required property int index
                readonly property bool selected: index === picker.selectedIndex

                width: picker.thumbWidth
                spacing: 4

                Item {
                    width: picker.thumbWidth
                    height: picker.thumbHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Theme.crust

                        Image {
                            anchors.fill: parent
                            source: "file://" + themeCard.modelData.thumbnail
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        GlassSurface {
                            z: 1
                            radius: 12
                            tinted: false
                        }

                    }

                    // Accent ring on the theme you're about to pick.
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
                        opacity: themeCard.selected ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                            }

                        }

                    }

                    // Badge on the theme in use.
                    Rectangle {
                        visible: themeCard.index === picker.currentIndex
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 28
                        height: 28
                        radius: 14
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                            backgroundColor: Theme.alpha(Theme.primary, 0.9)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Theme.base
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: picker.apply(themeCard.index)
                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 4
                    text: themeCard.modelData.name
                    color: themeCard.selected ? Theme.primary : Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: picker.mottos[themeCard.modelData.name] || ""
                    visible: text !== ""
                    color: Theme.secondary
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.italic: true
                }

            }

        }

    }

}
