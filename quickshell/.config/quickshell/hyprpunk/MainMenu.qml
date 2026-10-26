import QtQuick
import Quickshell

// Main menu in the dynamic island: one glass square per panel, the name of the
// selected one under the row. Arrows, Tab or the layout's keys pick an entry,
// Enter or a click opens it.
IslandPanel {
    id: menu

    property int selectedIndex: 0
    readonly property int cardPadding: 14
    readonly property int entrySize: 64
    readonly property int entrySpacing: 10
    readonly property int labelHeight: 26
    // panel: the island panel opened on this screen.
    readonly property var entries: [{
        "icon": "",
        "name": "Apps",
        "panel": "launcher"
    }, {
        "icon": "󰅌",
        "name": "Clipboard",
        "panel": "clipboard"
    }, {
        "icon": "󰱨",
        "name": "Emoji",
        "panel": "emoji"
    }, {
        "icon": "",
        "name": "Keybindings",
        "panel": "keybindings"
    }, {
        "icon": "",
        "name": "Wallpaper",
        "panel": "wallpaper"
    }, {
        "icon": "󰔎",
        "name": "SDDM theme",
        "panel": "sddm"
    }, {
        "icon": "",
        "name": "Configuration",
        "panel": "config"
    }, {
        "icon": "󰍹",
        "name": "Monitor",
        "panel": "monitor"
    }, {
        "icon": "",
        "name": "Session",
        "panel": "session"
    }]

    function run(entry) {
        close();
        shellState.requestPanel(entry.panel, "open", screen.name, panelName);
    }

    function select(delta) {
        selectedIndex = (selectedIndex + delta + entries.length) % entries.length;
    }

    panelName: "menu"
    cardWidth: entries.length * entrySize + (entries.length - 1) * entrySpacing + 2 * cardPadding
    cardHeight: entrySize + labelHeight + 2 * cardPadding
    keyTargets: [keys]
    // Back from an entry's panel, that entry stays selected.
    onOpening: selectedIndex = Math.max(0, entries.findIndex((entry) => {
        return entry.panel === openedFrom;
    }))

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const direction = menu.horizontalKey(event);
            if (direction !== 0) {
                menu.select(direction);
                event.accepted = true;
            }
        }
        Keys.onLeftPressed: menu.select(-1)
        Keys.onRightPressed: menu.select(1)
        Keys.onTabPressed: menu.select(1)
        Keys.onBacktabPressed: menu.select(-1)
        Keys.onReturnPressed: menu.run(menu.entries[menu.selectedIndex])
        Keys.onEnterPressed: menu.run(menu.entries[menu.selectedIndex])
    }

    Row {
        id: entryRow

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: menu.cardPadding
        spacing: menu.entrySpacing

        Repeater {
            model: menu.entries

            Rectangle {
                id: entryCard

                required property var modelData
                required property int index
                readonly property bool selected: menu.selectedIndex === index

                width: menu.entrySize
                height: menu.entrySize
                radius: 18
                color: "transparent"
                scale: entryTap.pressed ? 0.92 : 1

                // Same squares as the session menu: plain glass, mauve when selected.
                GlassSurface {
                    radius: parent.radius
                    hovered: entryCard.selected
                    backgroundColor: entryCard.selected ? Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.9) : "transparent"

                    Behavior on backgroundColor {
                        ColorAnimation {
                            duration: 140
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    text: entryCard.modelData.icon
                    color: entryCard.selected ? "#1e1e2e" : "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 24
                    font.weight: Font.Bold

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }

                    }

                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered)
                            menu.selectedIndex = entryCard.index;

                    }
                }

                TapHandler {
                    id: entryTap

                    onTapped: menu.run(entryCard.modelData)
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutBack
                    }

                }

            }

        }

    }

    Text {
        anchors.top: entryRow.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: menu.labelHeight
        verticalAlignment: Text.AlignBottom
        text: menu.entries[menu.selectedIndex].name
        color: "#b4befe"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.weight: Font.Bold
    }

}
