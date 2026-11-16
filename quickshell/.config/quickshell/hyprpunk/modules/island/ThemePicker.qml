import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// The theme picker: a card per theme, showing the wallpaper it would switch to (its last
// one), its name and its motto. Picking a theme brings that wallpaper back, and with it
// the theme's whole look.
// Arrows, Tab or the Vim keys to choose, Enter, Space or a click to apply.
IslandPanel {
    id: picker

    readonly property int cardPadding: Metrics.spacing.large
    readonly property int gap: 14
    readonly property int thumbWidth: 360
    readonly property int thumbHeight: 202
    readonly property var mottos: ({
        "neon": "the city never sleeps",
        "daydream": "but it dreams"
    })
    readonly property var themes: Wallpapers.themes
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

        if (index !== currentIndex)
            Wallpapers.setTheme(theme.name);

        close();
    }

    panelName: "theme"
    cardWidth: themes.length * thumbWidth + Math.max(0, themes.length - 1) * gap + 2 * cardPadding
    cardHeight: cards.height + 2 * cardPadding
    keyTargets: [keys]
    onOpening: selectedIndex = Math.max(0, currentIndex)

    ServiceRef {
        service: Wallpapers
        active: picker.opened
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

        // A card per theme, built by their number alone: a new wallpaper changes what
        // the cards show, not the cards.
        Repeater {
            model: picker.themes.length

            Column {
                id: themeCard

                required property int index
                readonly property var theme: picker.themes[index]
                readonly property bool selected: index === picker.selectedIndex

                width: picker.thumbWidth
                spacing: Metrics.spacing.small

                Item {
                    width: picker.thumbWidth
                    height: picker.thumbHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Metrics.radius.normal
                        color: Colors.crust

                        Image {
                            anchors.fill: parent
                            source: "file://" + themeCard.theme.thumbnail
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                        }

                        GlassSurface {
                            z: 1
                            radius: Metrics.radius.normal
                            tinted: false
                        }

                    }

                    // Accent ring on the theme you're about to pick.
                    Rectangle {
                        anchors.fill: parent
                        radius: Metrics.radius.normal
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.primary
                        opacity: themeCard.selected ? 1 : 0

                        Behavior on opacity {
                            Anim {
                                token: Motion.color.small
                            }

                        }

                    }

                    // Badge on the theme in use.
                    Rectangle {
                        visible: themeCard.index === picker.currentIndex
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Metrics.spacing.normal
                        width: 28
                        height: 28
                        radius: Metrics.radius.normal
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                            backgroundColor: Colors.alpha(Colors.primary, 0.9)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            color: Colors.base
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.emphasis
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
                    topPadding: Metrics.spacing.small
                    text: themeCard.theme.name
                    color: themeCard.selected ? Colors.primary : Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                    font.weight: Font.Bold
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: picker.mottos[themeCard.theme.name] || ""
                    visible: text !== ""
                    color: Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                    font.italic: true
                }

            }

        }

    }

}
