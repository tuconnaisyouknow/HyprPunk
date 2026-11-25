import QtQuick
import Quickshell
import qs.components
import qs.theme

// An island panel laid out as a row of glass squares, one per entry, with the selected
// one's name underneath: the screenshot menu and the session menu.
// Arrows, Tab or the Vim keys to choose, Enter, Space or a click to pick (chosen()).
IslandPanel {
    id: menu

    // [{"icon", "name", ...}]: the other keys are the caller's.
    required property var entries
    // -1 while nothing is selected.
    property int selectedIndex: 0
    // An entry waiting for a second click or Enter turns red.
    property int armedIndex: -1
    property bool labelShown: true
    // Hovering selects, and the pointer leaving takes the selection with it.
    property bool hoverOnly: false
    readonly property int cardPadding: Metrics.spacing.large
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
            if (direction !== 0)
                menu.select(direction);
            else if (Navigation.accepts(event))
                menu.choose();
            else
                return ;
            event.accepted = true;
        }
        Keys.onLeftPressed: menu.select(-1)
        Keys.onRightPressed: menu.select(1)
        Keys.onTabPressed: menu.select(1)
        Keys.onBacktabPressed: menu.select(-1)
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
                        radius: Metrics.radius.card
                        color: "transparent"
                        scale: entryTap.pressed ? 0.92 : 1

                        // Plain glass, accent when selected, red once armed. A selection:
                        // in neon the glass lights up from its edge inward.
                        GlassSurface {
                            radius: parent.radius
                            hovered: entryCard.selected
                            lit: true
                            inward: true
                            backgroundColor: entryCard.armed ? Colors.alpha(Colors.red, 0.9) : Colors.alpha(Colors.primary, entryCard.selected ? 0.9 : 0)

                            ColorFade on backgroundColor {
                                token: Motion.color.small
                            }

                        }

                        Icon {
                            anchors.centerIn: parent
                            text: entryCard.modelData.icon
                            filled: entryCard.selected
                            color: entryCard.armed ? Colors.over(Colors.red) : entryCard.selected ? Colors.over(Colors.primary) : Colors.primary
                            size: 24

                            ColorFade on color {
                                token: Motion.color.small
                            }

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
                            Anim {
                                token: Motion.pop
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
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
                font.weight: Font.Bold
            }

        }

    }

}
