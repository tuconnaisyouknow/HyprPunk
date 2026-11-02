import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The file picker the apps' Open and Save dialogs get through the portal, grown out of
// the island on the focused screen. Type to filter the folder, or a path from / or ~ to
// go there. The arrows or Ctrl + the Vim keys move (left goes up a folder, right goes
// into one), Backspace on an empty field goes up, Enter opens or picks, Shift+Enter
// picks the folder itself when the app wants one. Ctrl+Space marks several files when
// the app takes them, Ctrl+F switches the file type, Ctrl+. shows the hidden files.
IslandPanel {
    id: picker

    required property var chooser
    // The app's dialog, kept while the card folds away.
    property var request: null
    property bool answered: false
    readonly property bool saving: request !== null && request.mode === "save"
    // The app wants a folder (SaveFiles too: its files go in the one you pick).
    readonly property bool pickingFolder: request !== null && request.directory
    readonly property bool multiple: request !== null && request.multiple && !pickingFolder
    readonly property var filters: request && !pickingFolder ? request.filters : []
    property int filterIndex: 0
    property string folder: ""
    property bool showHidden: false
    // The folder's entries, filtered: {name, path, isDir, size, modified}.
    property var entries: []
    property int selectedIndex: -1
    readonly property var selected: selectedIndex >= 0 && selectedIndex < entries.length ? entries[selectedIndex] : null
    // The files marked with Ctrl+Space or Ctrl+click.
    property var marked: []
    // Saving over a file that's already there takes a second Enter.
    property bool replaceArmed: false
    // The sidebar: home, the XDG folders, your GTK bookmarks and the root, as {icon, name, path}.
    property var userDirs: []
    property var bookmarks: []
    readonly property var places: [{
        "icon": "󰋜",
        "name": "Home",
        "path": home
    }].concat(userDirs, bookmarks.filter((bookmark) => {
        return bookmark.path !== home && !userDirs.some((place) => {
            return place.path === bookmark.path;
        });
    }), [{
        "icon": "󰋊",
        "name": "Computer",
        "path": "/"
    }])
    readonly property string home: Quickshell.env("HOME")
    // A path typed from / or ~: the folder follows it, the rest filters.
    readonly property bool typingPath: /^[\/~]/.test(field.text)
    readonly property string query: saving ? "" : typingPath ? field.text.substring(field.text.lastIndexOf("/") + 1) : field.text
    readonly property int cardPadding: 14
    readonly property int sectionSpacing: 12
    readonly property int headerHeight: 22
    readonly property int footerHeight: 34
    readonly property int sidebarWidth: 170
    readonly property int previewWidth: 210
    readonly property int rowHeight: 36
    readonly property real bodyHeight: cardHeight - 2 * cardPadding - headerHeight - field.height - footerHeight - 3 * sectionSpacing
    readonly property string acceptLabel: request && request.acceptLabel !== "" ? request.acceptLabel : saving ? "Save" : pickingFolder ? "Choose" : "Open"

    function expand(path) {
        return path === "~" || path.startsWith("~/") ? home + path.substring(1) : path;
    }

    function collapse(path) {
        return path === home || path.startsWith(home + "/") ? "~" + path.substring(home.length) : path;
    }

    function join(directory, name) {
        return directory === "/" ? "/" + name : directory + "/" + name;
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function globRegex(glob) {
        return new RegExp("^" + glob.replace(/[.+^${}()|\\]/g, "\\$&").replace(/\*/g, ".*").replace(/\?/g, ".") + "$", "i");
    }

    function formatSize(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let size = bytes;
        let unit = 0;
        while (size >= 1024 && unit < units.length - 1) {
            size /= 1024;
            unit += 1;
        }
        return (unit === 0 ? size : size.toFixed(size < 10 ? 1 : 0)) + " " + units[unit];
    }

    function isImage(name) {
        return /\.(png|jpe?g|gif|webp|bmp|svg|avif|tiff?)$/i.test(name);
    }

    function iconFor(entry) {
        if (entry.isDir)
            return "󰉋";

        const name = entry.name.toLowerCase();
        if (isImage(name))
            return "󰋩";

        if (/\.(mp4|mkv|webm|mov|avi)$/.test(name))
            return "󰈫";

        if (/\.(mp3|flac|ogg|opus|wav|m4a)$/.test(name))
            return "󰈣";

        if (/\.pdf$/.test(name))
            return "󰈦";

        if (/\.(zip|tar|gz|xz|zst|bz2|7z|rar)$/.test(name))
            return "󰗄";

        if (/\.(txt|md|odt|docx?|rtf)$/.test(name))
            return "󰈙";

        return "󰈔";
    }

    // Read again whenever the folder, the filter or what you type changes, keeping the
    // selection on the same file when it's still there.
    function rebuild() {
        const filter = filters.length > 0 ? filters[filterIndex] : null;
        const patterns = filter ? filter.globs.map(globRegex) : [];
        const search = query.toLowerCase();
        const keep = selected ? selected.path : "";
        const list = [];
        for (let index = 0; index < folderModel.count; index++) {
            const name = folderModel.get(index, "fileName");
            const isDir = folderModel.get(index, "fileIsDir");
            if (search !== "" && name.toLowerCase().indexOf(search) < 0)
                continue;

            if (!isDir && patterns.length > 0 && !patterns.some((pattern) => {
                return pattern.test(name);
            }))
                continue;

            list.push({
                "name": name,
                "path": folderModel.get(index, "filePath"),
                "isDir": isDir,
                "size": folderModel.get(index, "fileSize"),
                "modified": folderModel.get(index, "fileModified")
            });
        }
        entries = list;
        const kept = list.findIndex((entry) => {
            return entry.path === keep;
        });
        // Nothing selected at first when saving or picking a folder: Enter then means
        // here, not the first entry.
        selectedIndex = kept >= 0 ? kept : saving || pickingFolder || list.length === 0 ? -1 : 0;
        syncList();
    }

    // Set by hand: the list puts itself back on its first entry whenever it's refilled.
    function syncList() {
        list.currentIndex = selectedIndex;
        if (selectedIndex >= 0)
            list.positionViewAtIndex(selectedIndex, ListView.Contain);

    }

    function select(index) {
        selectedIndex = index;
        replaceArmed = false;
        // Picking a file while saving takes its name, to save over it.
        if (saving && selected && !selected.isDir)
            field.text = selected.name;

    }

    function move(delta) {
        if (entries.length > 0)
            select(Math.max(0, Math.min(entries.length - 1, selectedIndex + delta)));

    }

    function enter(path) {
        if (typingPath) {
            field.text = collapse(path) + "/";
        } else {
            if (!saving)
                field.text = "";

            folder = path;
        }
    }

    function up() {
        if (folder !== "/")
            enter(folder.substring(0, folder.lastIndexOf("/")) || "/");

    }

    function toggleMark() {
        if (!multiple || !selected || selected.isDir)
            return ;

        const path = selected.path;
        marked = marked.indexOf(path) >= 0 ? marked.filter((item) => {
            return item !== path;
        }) : marked.concat([path]);
    }

    // The footer's button, and Shift+Enter.
    function accept() {
        if (pickingFolder)
            pick([selected && selected.isDir ? selected.path : folder]);
        else if (saving)
            save();
        else if (marked.length > 0)
            pick(marked);
        else if (selected && selected.isDir)
            enter(selected.path);
        else if (selected)
            pick([selected.path]);
    }

    // Enter, or a double click: into a folder, or the same as the button.
    function activate() {
        if (selected && selected.isDir)
            enter(selected.path);
        else
            accept();
    }

    function save() {
        const name = field.text;
        if (name === "" || name.endsWith("/")) {
            shake.restart();
            return ;
        }
        const path = typingPath ? expand(name) : join(folder, name);
        if (folderModel.indexOf(fileUrl(path)) >= 0 && !replaceArmed) {
            replaceArmed = true;
            return ;
        }
        pick([path]);
    }

    function pick(paths) {
        answered = true;
        chooser.answer(paths, filters.length > 0 ? filterIndex : -1);
        close();
    }

    panelName: "filechooser"
    cardWidth: 860
    cardHeight: 540
    onOpening: {
        request = chooser.request;
        answered = false;
        marked = [];
        replaceArmed = false;
        showHidden = false;
        filterIndex = request ? request.filter : 0;
        folder = request ? request.folder : home;
        field.text = saving ? request.name : "";
        rebuild();
    }
    onOpenedChanged: {
        if (opened) {
            field.input.forceActiveFocus();
            // The name ready to type over, its extension kept.
            const dot = field.text.lastIndexOf(".");
            if (saving)
                field.input.select(0, dot > 0 ? dot : field.text.length);

        } else if (!answered && request && chooser.request && chooser.request.id === request.id) {
            chooser.cancel();
        }
    }
    onFolderChanged: {
        marked = [];
        replaceArmed = false;
        selectedIndex = -1;
    }
    onQueryChanged: Qt.callLater(rebuild)
    onFilterIndexChanged: Qt.callLater(rebuild)
    onSelectedIndexChanged: syncList()

    // The app gave up on its dialog, or another one replaced it. Also while the card is
    // still mapping: an app that quits at once closes its dialog before the first frame.
    Connections {
        function onRequestChanged() {
            if ((picker.opened || picker.openPending) && picker.request && (!picker.chooser.request || picker.chooser.request.id !== picker.request.id)) {
                picker.answered = true;
                picker.close();
            }
        }

        target: picker.chooser
    }

    FolderListModel {
        id: folderModel

        // Only reads the folder while the card is shown.
        folder: picker.shown && picker.folder !== "" ? picker.fileUrl(picker.folder) : ""
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: picker.showHidden
        showFiles: !picker.pickingFolder
        sortCaseSensitive: false
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                Qt.callLater(picker.rebuild);

        }
        onCountChanged: Qt.callLater(picker.rebuild)
    }

    // The XDG folders that aren't just home (xdg-user-dir falls back to it).
    Process {
        command: ["sh", "-c", "for name in DESKTOP DOCUMENTS DOWNLOAD PICTURES MUSIC VIDEOS; do printf '%s\\t%s\\n' \"$name\" \"$(xdg-user-dir \"$name\")\"; done"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const icons = {
                    "DESKTOP": "󰇄",
                    "DOCUMENTS": "󰈙",
                    "DOWNLOAD": "󰉍",
                    "PICTURES": "󰉏",
                    "MUSIC": "󱍙",
                    "VIDEOS": "󰕧"
                };
                picker.userDirs = text.split("\n").filter((line) => {
                    return line !== "";
                }).map((line) => {
                    const fields = line.split("\t");
                    return {
                        "icon": icons[fields[0]] || "󰉋",
                        "name": fields[1].substring(fields[1].lastIndexOf("/") + 1),
                        "path": fields[1]
                    };
                }).filter((place) => {
                    return place.path !== picker.home && place.path !== "";
                });
            }
        }

    }

    // Your GTK bookmarks, one "file:///path Name" a line.
    FileView {
        path: picker.home + "/.config/gtk-3.0/bookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: picker.bookmarks = text().split("\n").filter((line) => {
            return line.startsWith("file://");
        }).map((line) => {
            const space = line.indexOf(" ");
            // Nautilus writes them with a trailing slash.
            const path = decodeURIComponent((space > 0 ? line.substring(0, space) : line).substring(7)).replace(/(.)\/+$/, "$1");
            return {
                "icon": "󰃀",
                "name": space > 0 ? line.substring(space + 1) : path.substring(path.lastIndexOf("/") + 1),
                "path": path
            };
        })
    }

    // The app's title on the left, where you are on the right.
    Item {
        id: header

        x: picker.cardPadding
        y: picker.cardPadding
        width: picker.cardWidth - 2 * picker.cardPadding
        height: picker.headerHeight

        Text {
            id: titleLabel

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width / 2)
            elide: Text.ElideRight
            text: picker.request && picker.request.title !== "" ? picker.request.title : picker.saving ? "Save" : "Open"
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: titleLabel.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: picker.collapse(picker.folder)
            color: Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 12
        }

    }

    GlassField {
        id: field

        property real shakeOffset: 0

        x: picker.cardPadding + shakeOffset
        anchors.top: header.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.cardWidth - 2 * picker.cardPadding
        icon: picker.saving ? "󰆓" : "󰍉"
        placeholder: picker.saving ? "File name" : "Filter, or a path from / or ~"
        // What Enter will do.
        hint: picker.replaceArmed ? "Enter again to replace" : picker.selected && picker.selected.isDir ? "Open folder" : picker.multiple && picker.marked.length > 0 ? picker.acceptLabel + " " + picker.marked.length : picker.selected || picker.saving || picker.pickingFolder ? picker.acceptLabel : ""
        onTextChanged: {
            // The folder follows the path typed, up to its last slash.
            if (!picker.typingPath)
                return ;

            const cut = text.lastIndexOf("/");
            const directory = cut < 0 ? picker.home : picker.expand(text.substring(0, cut + 1));
            picker.folder = directory.length > 1 ? directory.replace(/\/+$/, "") : directory;
        }
        onKeyPressed: (event) => {
            const move = picker.controlMove(event);
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            const control = (event.modifiers & Qt.ControlModifier) !== 0;
            if (move && move[1] !== 0)
                picker.move(move[1]);
            else if (move && move[0] < 0)
                picker.up();
            else if (move && picker.selected && picker.selected.isDir)
                picker.enter(picker.selected.path);
            else if (event.key === Qt.Key_Escape)
                picker.close();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                shift ? picker.accept() : picker.activate();
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                picker.move(1);
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                picker.move(-1);
            else if (event.key === Qt.Key_Backspace && text === "")
                picker.up();
            else if (control && event.key === Qt.Key_Space)
                picker.toggleMark();
            else if (control && event.key === Qt.Key_F && picker.filters.length > 1)
                picker.filterIndex = (picker.filterIndex + 1) % picker.filters.length;
            else if (control && event.key === Qt.Key_Period)
                picker.showHidden = !picker.showHidden;
            else
                return ;
            event.accepted = true;
        }
    }

    // Typing a new name forgets the file picked to save over.
    Connections {
        function onTextEdited() {
            picker.replaceArmed = false;
            if (picker.saving)
                picker.selectedIndex = -1;

        }

        target: field.input
    }

    Item {
        id: body

        x: picker.cardPadding
        anchors.top: field.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.cardWidth - 2 * picker.cardPadding
        height: picker.bodyHeight

        ListView {
            id: placeList

            width: picker.sidebarWidth
            height: parent.height
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: picker.places

            delegate: Rectangle {
                id: place

                required property var modelData
                readonly property bool current: picker.folder === modelData.path

                width: ListView.view.width
                height: 32
                radius: 12
                color: "transparent"

                GlassSurface {
                    visible: place.current || placeHover.hovered
                    radius: parent.radius
                    hovered: true
                }

                Text {
                    id: placeIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    text: place.modelData.icon
                    color: Theme.mauve
                    font.family: Theme.font
                    font.pixelSize: 14
                }

                Text {
                    anchors.left: placeIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: place.modelData.name
                    color: place.current ? Theme.text : Theme.subtext1
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                HoverHandler {
                    id: placeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        field.text = picker.saving && !picker.typingPath ? field.text : "";
                        picker.folder = place.modelData.path;
                    }
                }

            }

        }

        ListView {
            id: list

            anchors.left: placeList.right
            anchors.leftMargin: picker.sectionSpacing
            anchors.right: preview.left
            anchors.rightMargin: picker.sectionSpacing
            height: parent.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: picker.entries
            highlightFollowsCurrentItem: true
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            highlight: SelectionHighlight {
                view: list
                radius: 12
            }

            delegate: Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool isMarked: picker.marked.indexOf(modelData.path) >= 0

                width: ListView.view.width
                height: picker.rowHeight

                Text {
                    id: rowIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    text: row.isMarked ? "󰄲" : picker.iconFor(row.modelData)
                    color: row.isMarked || row.modelData.isDir ? Theme.mauve : Theme.overlay2
                    font.family: Theme.font
                    font.pixelSize: 15
                }

                Text {
                    anchors.left: rowIcon.right
                    anchors.leftMargin: 8
                    anchors.right: sizeLabel.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    text: row.modelData.name
                    color: row.isMarked ? Theme.mauve : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                Text {
                    id: sizeLabel

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.isDir ? "" : picker.formatSize(row.modelData.size)
                    color: Theme.overlay1
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => {
                        picker.select(row.index);
                        if (mouse.modifiers & Qt.ControlModifier)
                            picker.toggleMark();

                        field.input.forceActiveFocus();
                    }
                    onDoubleClicked: picker.activate()
                }

            }

        }

        Text {
            anchors.centerIn: list
            visible: picker.entries.length === 0 && folderModel.status === FolderListModel.Ready
            text: picker.query !== "" ? "Nothing matches" : "Empty folder"
            color: Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 13
        }

        // The selected file, or the folder itself when nothing is: a picture's preview,
        // otherwise its icon, with its size and date.
        Column {
            id: preview

            readonly property var entry: picker.selected
            readonly property bool showsImage: entry !== null && !entry.isDir && picker.isImage(entry.name)

            anchors.right: parent.right
            width: picker.previewWidth
            height: parent.height
            spacing: 10

            ClippingRectangle {
                width: parent.width
                height: parent.width
                radius: 14
                color: "transparent"

                GlassSurface {
                    radius: 14
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: preview.showsImage
                    source: preview.showsImage ? picker.fileUrl(preview.entry.path) : ""
                    sourceSize: Qt.size(420, 420)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: !preview.showsImage
                    text: preview.entry ? picker.iconFor(preview.entry) : "󰉋"
                    color: preview.entry && !preview.entry.isDir ? Theme.overlay2 : Theme.mauve
                    font.family: Theme.font
                    font.pixelSize: 64
                }

            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
                text: preview.entry ? preview.entry.name : picker.folder === "/" ? "/" : picker.folder.substring(picker.folder.lastIndexOf("/") + 1)
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: text !== ""
                text: !preview.entry ? picker.entries.length + (picker.entries.length === 1 ? " item" : " items") : (preview.entry.isDir ? "Folder" : picker.formatSize(preview.entry.size)) + " · " + preview.entry.modified.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
                color: Theme.overlay1
                font.family: Theme.font
                font.pixelSize: 11
            }

        }

    }

    // The file type and the hidden files on the left, Cancel and the app's button on the right.
    Item {
        id: footer

        x: picker.cardPadding
        anchors.top: body.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.cardWidth - 2 * picker.cardPadding
        height: picker.footerHeight

        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: 8

            Chip {
                visible: picker.filters.length > 0
                icon: "󰈲"
                label: picker.filters.length > 0 ? picker.filters[picker.filterIndex].name : ""
                onClicked: picker.filterIndex = (picker.filterIndex + 1) % picker.filters.length
            }

            Chip {
                icon: picker.showHidden ? "󰈈" : "󰈉"
                label: "Hidden"
                active: picker.showHidden
                onClicked: picker.showHidden = !picker.showHidden
            }

        }

        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: 8

            Chip {
                label: "Cancel"
                onClicked: picker.close()
            }

            Chip {
                label: picker.replaceArmed ? "Replace" : picker.multiple && picker.marked.length > 0 ? picker.acceptLabel + " " + picker.marked.length : picker.acceptLabel
                accent: true
                onClicked: picker.accept()
            }

        }

    }

    // Wrong name to save under (empty): the field shakes.
    SequentialAnimation {
        id: shake

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: -12
            duration: 50
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: 10
            duration: 70
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: -6
            duration: 60
        }

        NumberAnimation {
            target: field
            property: "shakeOffset"
            to: 0
            duration: 60
        }

    }

    // The footer's pill buttons: glass, or mauve for the one that answers the app.
    component Chip: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""
        property bool accent: false
        property bool active: false

        signal clicked()

        implicitWidth: chipLabel.implicitWidth + 32
        height: parent.height
        radius: height / 2
        color: "transparent"

        GlassSurface {
            radius: parent.radius
            hovered: chipHover.hovered || chip.active
            backgroundColor: chip.accent ? Theme.alpha(Theme.mauve, chipHover.hovered ? 0.95 : 0.8) : "transparent"
        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: (chip.icon !== "" ? chip.icon + "  " : "") + chip.label
            color: chip.accent ? Theme.base : chip.active ? Theme.text : Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: chip.accent ? Font.Bold : Font.Normal
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                chipBounce.restart();
                chip.clicked();
            }
        }

        BounceAnimation {
            id: chipBounce

            target: chip
        }

    }

}
