import QtQuick
import Quickshell
import Quickshell.Io

// The emoji picker: every emoji from data/emojis.tsv, your recent ones first, searchable
// by name and keyword. Enter or a click copies it.
SearchPanel {
    id: picker

    readonly property string historyPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/emoji-history.json"
    readonly property int cellSize: 56
    readonly property int visibleRows: 5
    readonly property int maxRecent: 30
    // [{ "emoji", "name", "keywords" }]
    property var emojis: []
    readonly property var baseEmojis: emojis.filter((emoji) => {
        return !emoji.name.includes("skin tone");
    })
    // Most recent first.
    property var recent: []
    readonly property var results: {
        const needle = query.trim().toLowerCase();
        // The skin tone variants only when asked for.
        const emojis = needle.includes("tone") ? picker.emojis : baseEmojis;
        if (needle === "") {
            const byEmoji = {};
            for (const emoji of picker.emojis)
                byEmoji[emoji.emoji] = emoji;
            const recentEmojis = recent.filter((emoji) => {
                return byEmoji[emoji];
            }).map((emoji) => {
                return byEmoji[emoji];
            });
            return recentEmojis.concat(emojis.filter((emoji) => {
                return !recent.includes(emoji.emoji);
            }));
        }
        const matches = [];
        for (let i = 0; i < emojis.length; i++) {
            const emoji = emojis[i];
            const score = emoji.name === needle ? 5 : emoji.name.startsWith(needle) ? 4 : (" " + emoji.name).includes(" " + needle) ? 3 : emoji.name.includes(needle) ? 2 : emoji.keywords.includes(needle) ? 1 : 0;
            if (score > 0)
                matches.push({
                "emoji": emoji,
                "score": score,
                "order": i
            });

        }
        matches.sort((a, b) => {
            return b.score - a.score || a.order - b.order;
        });
        return matches.map((match) => {
            return match.emoji;
        });
    }

    function copy(emoji) {
        close();
        const list = [emoji.emoji].concat(recent.filter((item) => {
            return item !== emoji.emoji;
        })).slice(0, maxRecent);
        recent = list;
        historyFile.setText(JSON.stringify(list));
        Quickshell.execDetached(["wl-copy", emoji.emoji]);
    }

    panelName: "emoji"
    searchIcon: "󰱨"
    placeholder: "Search emojis"
    hint: selectedIndex >= 0 && selectedIndex < results.length ? results[selectedIndex].name : ""
    count: results.length
    columns: 10
    view: grid
    cardWidth: columns * cellSize + 2 * cardPadding
    bodyHeight: results.length > 0 ? Math.min(visibleRows, Math.ceil(results.length / columns)) * cellSize : 40
    onActivated: (index) => {
        return copy(results[index]);
    }

    // "emoji<TAB>name<TAB>keywords" per line, after a # header.
    FileView {
        path: Quickshell.shellPath("data/emojis.tsv")
        onLoaded: picker.emojis = text().split("\n").filter((line) => {
            return line !== "" && !line.startsWith("# ");
        }).map((line) => {
            const fields = line.split("\t");
            return {
                "emoji": fields[0],
                "name": fields[1] || "",
                "keywords": (fields[2] || "").toLowerCase()
            };
        })
    }

    FileView {
        id: historyFile

        path: picker.historyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const list = JSON.parse(text());
                picker.recent = Array.isArray(list) ? list : [];
            } catch (error) {
                picker.recent = [];
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: picker.results.length === 0
        text: "No emoji"
        color: Theme.overlay1
        font.family: Theme.font
        font.pixelSize: 14
    }

    GridView {
        id: grid

        anchors.fill: parent
        clip: true
        cellWidth: picker.cellSize
        cellHeight: picker.cellSize
        boundsBehavior: Flickable.StopAtBounds
        model: picker.results
        currentIndex: picker.selectedIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0
        highlight: SelectionHighlight {
            view: grid
            inset: 3
        }

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool selected: picker.selectedIndex === index
            readonly property real pressScale: cellContent.scale

            width: picker.cellSize
            height: picker.cellSize

            Rectangle {
                id: cellContent

                anchors.fill: parent
                anchors.margins: 3
                radius: 14
                color: "transparent"
                scale: cellTap.pressed ? 0.9 : 1

                Text {
                    anchors.centerIn: parent
                    text: cell.modelData.emoji
                    font.family: "Apple Color Emoji"
                    font.pixelSize: 28
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutBack
                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        picker.selectedIndex = cell.index;

                }
            }

            TapHandler {
                id: cellTap

                onTapped: picker.copy(cell.modelData)
            }

        }

    }

}
