import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Your clipboard history in the dynamic island, newest first, with thumbnails for
// images. Enter or a click puts an entry back on the clipboard.
SearchPanel {
    id: clipboard

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/hyprpunk/clipboard"
    readonly property int textRowHeight: 40
    readonly property int imageRowHeight: 92
    readonly property int rowSpacing: 4
    readonly property int maxBodyHeight: 440
    // [{ "id", "text", "image": decoded file or "" }]
    property var entries: []
    readonly property var results: {
        const words = query.toLowerCase().split(/\s+/).filter((word) => {
            return word !== "";
        });
        return entries.filter((entry) => {
            const text = (entry.image !== "" ? "image " : "") + entry.text.toLowerCase();
            return words.every((word) => {
                return text.includes(word);
            });
        });
    }

    // "[[ binary data 23 KiB png 1920x1080 ]]" -> "PNG · 1920x1080 · 23 KiB"
    function imageLabel(text) {
        const match = text.match(/binary data ([\d.]+ \w+) (\w+)(?: (\d+x\d+))?/);
        return match ? [match[2].toUpperCase(), match[3], match[1]].filter((part) => {
            return part;
        }).join(" · ") : "Image";
    }

    function copy(entry) {
        close();
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$0\" | wl-copy", entry.id]);
    }

    panelName: "clipboard"
    searchIcon: "󰅌"
    placeholder: "Search the clipboard"
    hint: entries.length > 0 ? results.length + " / " + entries.length : ""
    count: results.length
    view: list
    cardWidth: 640
    bodyHeight: results.length > 0 ? Math.min(list.contentHeight, maxBodyHeight) : textRowHeight
    onOpening: listProcess.running = true
    onActivated: (index) => {
        return copy(results[index]);
    }

    // One "id<TAB>preview<TAB>image" line per entry, the images decoded once into the cache.
    Process {
        id: listProcess

        command: ["bash", "-c", "mkdir -p \"$0\"; find \"$0\" -type f -mtime +30 -delete; cliphist list | while IFS=$'\\t' read -r id preview; do image=''; if [[ $preview == '[[ binary data '* ]]; then ext=$(sed -nE 's/.* (png|jpeg|jpg|gif|bmp|webp) .*/\\1/p' <<<\"$preview\"); if [[ -n $ext ]]; then image=\"$0/$id.$ext\"; [[ -s $image ]] || cliphist decode \"$id\" >\"$image\" 2>/dev/null; fi; fi; printf '%s\\t%s\\t%s\\n' \"$id\" \"$preview\" \"$image\"; done", clipboard.cacheDir]

        stdout: StdioCollector {
            onStreamFinished: clipboard.entries = text.split("\n").filter((line) => {
                return line !== "";
            }).map((line) => {
                const fields = line.split("\t");
                return {
                    "id": fields[0],
                    "text": fields[1] || "",
                    "image": fields[2] || ""
                };
            })
        }

    }

    Text {
        anchors.centerIn: parent
        visible: clipboard.results.length === 0
        text: listProcess.running && clipboard.entries.length === 0 ? "Loading…" : clipboard.entries.length === 0 ? "The clipboard is empty" : "No match"
        color: Theme.overlay1
        font.family: Theme.font
        font.pixelSize: 14
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        spacing: clipboard.rowSpacing
        boundsBehavior: Flickable.StopAtBounds
        model: clipboard.results
        currentIndex: clipboard.selectedIndex
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
            readonly property bool selected: clipboard.selectedIndex === index
            readonly property bool isImage: modelData.image !== ""

            width: ListView.view.width
            height: isImage ? clipboard.imageRowHeight : clipboard.textRowHeight
            radius: 14
            color: "transparent"

            ClippingRectangle {
                id: thumbnail

                visible: row.isImage
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 136
                height: clipboard.imageRowHeight - 16
                radius: 10
                color: Theme.crust

                Image {
                    anchors.fill: parent
                    source: row.isImage ? "file://" + row.modelData.image : ""
                    sourceSize.width: 272
                    sourceSize.height: 152
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

            }

            Text {
                anchors.left: row.isImage ? thumbnail.right : parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                text: row.isImage ? clipboard.imageLabel(row.modelData.text) : row.modelData.text
                textFormat: Text.PlainText
                color: row.selected ? Theme.mauve : row.isImage ? Theme.lavender : Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        clipboard.selectedIndex = row.index;

                }
            }

            TapHandler {
                onTapped: clipboard.copy(row.modelData)
            }

        }

    }

}
