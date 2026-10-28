import QtQuick
import Quickshell

// The screenshot menu, laid out like the main menu: capture the screen, a region,
// or a region to annotate, or record the screen or a region (or stop the recording).
// Arrows, Tab or the Vim keys to choose, Enter or a click to go.
IslandPanel {
    id: menu

    property int selectedIndex: 0
    readonly property int cardPadding: 14
    readonly property int entrySize: 64
    readonly property int entrySpacing: 10
    readonly property int labelHeight: 26
    // mode: the screenshot taken, or the recording started, on this screen; badge: a
    // small icon at the bottom right of the icon.
    readonly property var entries: [{
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

    // Wait for the card to fold away, so it isn't in the picture.
    function run(entry) {
        close();
        shellState.requestScreenshot(entry.mode, screen.name, entry.mode === "stop" ? 0 : 380);
    }

    function select(delta) {
        selectedIndex = (selectedIndex + delta + entries.length) % entries.length;
    }

    panelName: "screenshot"
    cardWidth: entries.length * entrySize + (entries.length - 1) * entrySpacing + 2 * cardPadding
    cardHeight: entrySize + labelHeight + 2 * cardPadding
    keyTargets: [keys]
    onOpening: selectedIndex = 0
    onEntriesChanged: selectedIndex = Math.min(selectedIndex, entries.length - 1)

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
                    id: entryIcon

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

                // Over the icon's corner, cut out of it by an outline of the card's colour.
                Text {
                    visible: entryCard.modelData.badge !== undefined
                    x: entryIcon.x + entryIcon.width - width * 0.8
                    y: entryIcon.y + entryIcon.height - height * 0.95
                    text: entryCard.modelData.badge || ""
                    color: entryIcon.color
                    style: Text.Outline
                    styleColor: entryCard.selected ? "#cba6f7" : "#2a2a3d"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
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
