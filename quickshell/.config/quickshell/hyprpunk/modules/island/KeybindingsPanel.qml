import QtQuick
import qs.components
import qs.services
import qs.theme

// Every Hyprland shortcut that has a description, searchable by what it does or its
// keys. Enter or a click runs it for you.
SearchPanel {
    id: keybindings

    readonly property int rowHeight: 40
    readonly property int rowSpacing: 4
    readonly property int visibleRows: 10
    readonly property var binds: Keybindings.binds
    readonly property var results: {
        const words = query.toLowerCase().split(/\s+/).filter((word) => {
            return word !== "";
        });
        return binds.filter((bind) => {
            const text = (bind.description + " " + bind.keys.join(" ")).toLowerCase();
            return words.every((word) => {
                return text.includes(word);
            });
        });
    }

    function run(bind) {
        close();
        Keybindings.run(bind);
    }

    panelName: "keybindings"
    searchIcon: "󰌌"
    placeholder: "Search keybindings"
    hint: binds.length > 0 ? results.length + " / " + binds.length : ""
    count: results.length
    view: list
    cardWidth: 760
    bodyHeight: results.length > 0 ? Math.min(results.length, visibleRows) * (rowHeight + rowSpacing) - rowSpacing : rowHeight
    onActivated: (index) => {
        return run(results[index]);
    }

    ServiceRef {
        service: Keybindings
        active: keybindings.opened
    }

    Text {
        anchors.centerIn: parent
        visible: keybindings.results.length === 0
        text: Keybindings.loading && keybindings.binds.length === 0 ? "Loading…" : "No keybinding"
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: 14
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: keybindings.rowSpacing
        boundsBehavior: Flickable.StopAtBounds
        model: keybindings.results
        currentIndex: keybindings.selectedIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0
        highlightResizeDuration: 0
        highlight: SelectionHighlight {
            view: list
        }

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool selected: keybindings.selectedIndex === index

            width: ListView.view.width
            height: keybindings.rowHeight
            radius: 14
            color: "transparent"

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: keys.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.modelData.description
                color: row.selected ? Colors.primary : Colors.secondary
                font.family: Metrics.font
                font.pixelSize: 13
            }

            // One glass keycap per key.
            Row {
                id: keys

                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: row.modelData.keys

                    Rectangle {
                        required property string modelData

                        width: Math.max(26, keyLabel.implicitWidth + 16)
                        height: 26
                        radius: 8
                        color: "transparent"

                        GlassSurface {
                            radius: parent.radius
                        }

                        Text {
                            id: keyLabel

                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Colors.primary
                            font.family: Metrics.font
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }

                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        keybindings.selectedIndex = row.index;

                }
            }

            TapHandler {
                onTapped: keybindings.run(row.modelData)
            }

        }

    }

}
