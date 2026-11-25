import Qt.labs.folderlistmodel
import QtQuick
import qs.components
import qs.theme

// The file picker's list: a folder's entries, folders first, filtered by what you type
// and the app's file types. A new folder's entries only replace the old ones once
// they're read, so nothing empties or blinks meanwhile, and they slide in from where
// you're going: the right going in, the left going back up.
Item {
    id: folderList

    required property string folder
    // The picker is shown: the folder is only read then.
    required property bool reading
    property string query: ""
    // The app's file type, as patterns like "*.png": none for every file.
    property var globs: []
    property bool showHidden: false
    property bool showFiles: true
    // Enter means the selected entry rather than the folder itself: the first entry is
    // selected at first, and going back up selects the folder you came out of.
    property bool selectsEntry: true
    // The entries marked to pick at once.
    property var marked: []
    // The entry to select as soon as the folder shows it: one just made or renamed, or
    // the one next to those sent to the trash.
    property string wanted: ""
    // The folder the entries are from, behind folder while the new one is read.
    property string shownFolder: ""
    // {name, path, isDir, size, modified}
    property var entries: []
    property int selectedIndex: -1
    readonly property var selected: selectedIndex >= 0 && selectedIndex < entries.length ? entries[selectedIndex] : null

    // A click on an entry, with its modifier keys.
    signal clicked(int index, int modifiers)
    signal doubleClicked()

    // The entry is in the folder shown, filtered out or not.
    function contains(path) {
        return folderModel.indexOf(Files.url(path)) >= 0;
    }

    // The entry the selection falls back on once these are gone: the next one down,
    // else the last one before them.
    function neighbour(paths) {
        const stays = (entry) => {
            return paths.indexOf(entry.path) < 0;
        };
        const next = entries.slice(selectedIndex + 1).find(stays) ?? entries.slice(0, Math.max(0, selectedIndex)).reverse().find(stays);
        return next ? next.path : "";
    }

    // Opening again: last time's entries go, and a slide cut short by closing ends.
    function reset() {
        shownFolder = "";
        wanted = "";
        entries = [];
        selectedIndex = -1;
        folderIn.stop();
        listShift.x = 0;
        list.opacity = 1;
    }

    // Read again whenever the folder, its entries, the file type or what you type
    // changes, keeping the selection on the same entry while it's still there.
    function rebuild() {
        if (folderModel.status !== FolderListModel.Ready || decodeURIComponent(String(folderModel.folder)) !== "file://" + folder)
            return ;

        const previous = shownFolder;
        const fresh = previous !== folder;
        const cameFrom = fresh && selectsEntry && Files.inside(folder, previous) ? Files.join(folder, previous.substring(folder === "/" ? 1 : folder.length + 1).split("/")[0]) : "";
        const patterns = globs.map(Files.globRegex);
        const search = query.toLowerCase();
        const keep = fresh ? cameFrom : selected ? selected.path : "";
        // Asked for in the folder you left: forgotten.
        if (fresh)
            wanted = "";

        const found = [];
        for (let index = 0; index < folderModel.count; index++) {
            const name = folderModel.get(index, "fileName");
            const isDir = folderModel.get(index, "fileIsDir");
            if (search !== "" && name.toLowerCase().indexOf(search) < 0)
                continue;

            if (!isDir && patterns.length > 0 && !patterns.some((pattern) => {
                return pattern.test(name);
            }))
                continue;

            found.push({
                "name": name,
                "path": folderModel.get(index, "filePath"),
                "isDir": isDir,
                "size": folderModel.get(index, "fileSize"),
                "modified": folderModel.get(index, "fileModified")
            });
        }
        entries = found;
        const indexOf = (path) => {
            return path === "" ? -1 : found.findIndex((entry) => {
                return entry.path === path;
            });
        };
        const asked = indexOf(wanted);
        if (asked >= 0)
            wanted = "";

        const kept = asked >= 0 ? asked : indexOf(keep);
        selectedIndex = kept >= 0 ? kept : selectsEntry && found.length > 0 ? 0 : -1;
        syncList();
        if (fresh) {
            shownFolder = folder;
            // Not on opening: the card grows already.
            if (previous !== "") {
                folderIn.step = Files.inside(previous, folder) ? 1 : Files.inside(folder, previous) ? -1 : 0;
                folderIn.restart();
            }
        }
    }

    // Set by hand: the list puts itself back on its first entry whenever it's refilled.
    function syncList() {
        list.currentIndex = selectedIndex;
        if (selectedIndex >= 0)
            list.positionViewAtIndex(selectedIndex, ListView.Contain);

    }

    onSelectedIndexChanged: syncList()
    onQueryChanged: Qt.callLater(rebuild)
    onGlobsChanged: Qt.callLater(rebuild)

    FolderListModel {
        id: folderModel

        folder: folderList.reading && folderList.folder !== "" ? Files.url(folderList.folder) : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: folderList.showHidden
        showFiles: folderList.showFiles
        sortCaseSensitive: false
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                Qt.callLater(folderList.rebuild);

        }
        onCountChanged: Qt.callLater(folderList.rebuild)
        // A new name or size leaves the count as it was.
        onDataChanged: Qt.callLater(folderList.rebuild)
    }

    ListView {
        id: list

        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: folderList.entries
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0
        highlightResizeDuration: 0

        transform: Translate {
            id: listShift
        }

        // Inset like the hover's glass, so the two never touch on rows side by side.
        highlight: SelectionHighlight {
            view: list
            radius: Metrics.radius.normal
            inset: Metrics.stroke
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index
            readonly property bool marked: folderList.marked.indexOf(modelData.path) >= 0
            readonly property bool lit: marked || ListView.isCurrentItem

            width: ListView.view.width
            // Room for the name and the glass around it.
            height: 36

            // Fainter than the selection's glass: hovering a file doesn't pick it,
            // since picking changes the preview and, when saving, the name.
            GlassSurface {
                anchors.margins: Metrics.stroke
                radius: Metrics.radius.normal
                opacity: rowHover.hovered && !row.ListView.isCurrentItem ? 1 : 0

                Behavior on opacity {
                    Anim {
                        token: Motion.color.small
                    }

                }

            }

            HoverHandler {
                id: rowHover

                cursorShape: Qt.PointingHandCursor
            }

            Icon {
                id: rowIcon

                anchors.left: parent.left
                anchors.leftMargin: Metrics.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                width: Metrics.spacing.section
                text: row.marked ? "check_box" : Files.icon(row.modelData)
                color: row.lit ? Colors.primary : Colors.secondary
                size: Metrics.text.title
            }

            Text {
                anchors.left: rowIcon.right
                anchors.leftMargin: Metrics.spacing.small
                anchors.right: sizeLabel.left
                anchors.rightMargin: Metrics.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideMiddle
                text: row.modelData.name
                color: row.lit ? Colors.primary : Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.emphasis
            }

            Text {
                id: sizeLabel

                anchors.right: parent.right
                anchors.rightMargin: Metrics.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.isDir ? "" : Files.size(row.modelData.size)
                color: Colors.secondary
                font.family: Metrics.font
                font.pixelSize: Metrics.text.small
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    return folderList.clicked(row.index, mouse.modifiers);
                }
                onDoubleClicked: folderList.doubleClicked()
            }

        }

    }

    // The folder shown, even while the next one is read: no flash in between.
    Text {
        anchors.centerIn: parent
        visible: folderList.entries.length === 0 && folderList.shownFolder !== ""
        opacity: list.opacity
        text: folderList.query !== "" ? "Nothing matches" : "Empty folder"
        color: Colors.secondary
        font.family: Metrics.font
        font.pixelSize: Metrics.text.emphasis
    }

    ParallelAnimation {
        id: folderIn

        // 1 into a folder, -1 back up, 0 elsewhere.
        property int step: 0

        Anim {
            target: listShift
            property: "x"
            from: Metrics.spacing.huge * folderIn.step
            to: 0
            token: Motion.move.normal
        }

        Anim {
            target: list
            property: "opacity"
            from: 0
            to: 1
            token: Motion.color.normal
        }

    }

}
