import QtQuick
import Quickshell

// An island panel laid out as a row of glass squares, one per entry, with the selected
// one's name underneath: the main menu, the screenshot menu and the session menu.
// Arrows, Tab or the Vim keys to choose, Enter or a click to pick (chosen()).
IslandPanel {
    id: menu

    // [{"icon", "name", "badge" (optional, a small icon at the icon's corner), ...}]:
    // the other keys are the caller's.
    required property var entries
    // -1 while nothing is selected.
    property int selectedIndex: 0
    // An entry waiting for a second click or Enter turns red.
    property int armedIndex: -1
    property bool labelShown: true
    // Hovering selects, and the pointer leaving takes the selection with it.
    property bool hoverOnly: false
    readonly property int cardPadding: 14
    readonly property int entrySize: 64
    readonly property int entrySpacing: 10
    readonly property int labelHeight: 26

    signal chosen(var entry, int index)

    function select(delta) {
        const count = entries.length;
        selectedIndex = selectedIndex < 0 ? (delta > 0 ? 0 : count - 1) : (selectedIndex + delta + count) % count;
    }

    function choose() {
        if (selectedIndex >= 0)
            chosen(entries[selectedIndex], selectedIndex);

    }

    cardWidth: entries.length * entrySize + (entries.length - 1) * entrySpacing + 2 * cardPadding
    cardHeight: entrySize + (labelShown ? labelHeight : 0) + 2 * cardPadding
    keyTargets: [keys]
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
        Keys.onReturnPressed: menu.choose()
        Keys.onEnterPressed: menu.choose()
    }

    // Built on each opening and dropped once folded away: it only takes a couple of
    // milliseconds, and a closed menu then costs next to nothing.
    Loader {
        anchors.fill: parent
        active: menu.shown

        sourceComponent: Item {
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
                        readonly property bool armed: menu.armedIndex === index

                        width: menu.entrySize
                        height: menu.entrySize
                        radius: 18
                        color: "transparent"
                        scale: entryTap.pressed ? 0.92 : 1

                        // Plain glass, mauve when selected, red once armed.
                        GlassSurface {
                            radius: parent.radius
                            hovered: entryCard.selected
                            backgroundColor: entryCard.armed ? Theme.alpha(Theme.red, 0.9) : entryCard.selected ? Theme.alpha(Theme.mauve, 0.9) : "transparent"

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
                            color: entryCard.armed || entryCard.selected ? Theme.base : Theme.mauve
                            font.family: Theme.font
                            font.pixelSize: 24
                            font.weight: Font.Bold

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }

                            }

                        }

                        // Over the icon's corner, cut out of it by an outline of the square's color.
                        Text {
                            visible: entryCard.modelData.badge !== undefined
                            x: entryIcon.x + entryIcon.width - width * 0.8
                            y: entryIcon.y + entryIcon.height - height * 0.95
                            text: entryCard.modelData.badge || ""
                            color: entryIcon.color
                            style: Text.Outline
                            styleColor: entryCard.selected ? Theme.mauve : "#2a2a3d"
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: {
                                if (hovered)
                                    menu.selectedIndex = entryCard.index;
                                else if (menu.hoverOnly && menu.selectedIndex === entryCard.index)
                                    menu.selectedIndex = -1;
                            }
                        }

                        TapHandler {
                            id: entryTap

                            onTapped: menu.chosen(entryCard.modelData, entryCard.index)
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
                visible: menu.labelShown && menu.selectedIndex >= 0
                verticalAlignment: Text.AlignBottom
                text: menu.selectedIndex >= 0 ? menu.entries[menu.selectedIndex].name || "" : ""
                color: Theme.lavender
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.Bold
            }

        }

    }

}
