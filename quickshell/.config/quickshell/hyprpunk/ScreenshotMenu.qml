import QtQuick
import Quickshell

// Screenshot menu in the dynamic island, like the main menu: the screen, a region, or
// a region then annotated, and recording the screen or a region (stopping it while
// one runs). Arrows, Tab or the layout's keys pick one, Enter or a click
// takes it.
IslandPanel {
    id: menu

    property int selectedIndex: 0
    readonly property int cardPadding: 14
    readonly property int entrySize: 64
    readonly property int entrySpacing: 10
    readonly property int labelHeight: 26
    // mode: the screenshot taken, or the recording started, on this screen.
    readonly property var entries: [{
        "icon": "󰍹",
        "name": "Screen",
        "mode": "screen"
    }, {
        "icon": "󰩭",
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
        "icon": "󰑋",
        "name": "Record region",
        "mode": "record-region"
    }])

    // Once the card has folded away, not to be in the screenshot.
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
