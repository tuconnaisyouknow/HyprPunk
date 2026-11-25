import QtQuick
import qs.components
import qs.services
import qs.theme

// The file picker the apps' Open and Save dialogs get through the portal, grown out of
// the island on the focused screen. Type to filter the folder, or a path from / or ~ to
// go there. Up and down or Ctrl + the Vim keys move, Vim's left and right going up a
// folder and into one. Enter opens or picks, and so does right once the field is
// empty, where left and Backspace go up a folder. Shift+Enter picks the folder itself
// when the app wants one. Ctrl+F switches the file type, Ctrl+. shows the hidden files.
// When the app takes several, Ctrl+Space or Ctrl+click marks one, Shift with up, down or
// a click marks all the way there, and Ctrl+A marks them all.
// Ctrl+N makes a file, or a folder when its name ends with /, F2 renames the selected
// entry and Delete, with nothing left for it to erase in the field, sends the marked or
// selected ones to the trash after an Enter. The field takes the name meanwhile, and
// Escape gives up.
// The list is FolderList's; the panel answers the app (FileChooser) and changes the
// files through FileOps.
IslandPanel {
    id: picker

    // The app's dialog, kept while the card folds away.
    property var request: null
    property bool answered: false
    readonly property bool saving: request !== null && request.mode === "save"
    // The app wants a folder (SaveFiles too: its files go in the one you pick).
    readonly property bool pickingFolder: request !== null && request.directory
    readonly property bool multiple: request !== null && request.multiple
    readonly property var filters: request && !pickingFolder ? request.filters : []
    property int filterIndex: 0
    property string folder: ""
    property bool showHidden: false
    readonly property var selected: folderList.selected
    // The entries marked to pick at once.
    property var marked: []
    // What the field and Enter are taken for, instead of filtering and picking: naming
    // a new entry ("new") or the selected one again ("rename"), or one more Enter
    // before the trash ("trash") or saving over a file that's already there ("replace").
    property string intent: ""
    readonly property bool naming: intent === "new" || intent === "rename"
    // The entry being renamed.
    property string renamed: ""
    // The name to save under, kept while the field names something else.
    property string heldName: ""
    // Only folders show when the app wants one, so a new entry is one too.
    readonly property bool makesFolder: pickingFolder || field.text.endsWith("/")
    readonly property var trashTargets: marked.length > 0 ? marked : selected ? [selected.path] : []
    // A path typed from / or ~: the folder follows it, the rest filters.
    readonly property bool typingPath: !naming && /^[\/~]/.test(field.text)
    readonly property string query: saving || naming ? "" : typingPath ? field.text.substring(field.text.lastIndexOf("/") + 1) : field.text
    readonly property int cardPadding: Metrics.spacing.large
    readonly property int sectionSpacing: Metrics.spacing.large
    readonly property int contentWidth: cardWidth - 2 * cardPadding
    readonly property int sidebarWidth: 170
    readonly property int previewWidth: 210
    readonly property string acceptLabel: request && request.acceptLabel !== "" ? request.acceptLabel : saving ? "Save" : pickingFolder ? "Choose" : "Open"
    // What the button and Enter will do.
    readonly property string answerLabel: intent === "new" ? "Create" : intent === "rename" ? "Rename" : intent === "trash" ? (trashTargets.length > 1 ? "Trash " + trashTargets.length : "Trash") : intent === "replace" ? "Replace" : marked.length > 0 ? acceptLabel + " " + marked.length : acceptLabel

    // Back to filtering and picking: the field gets the name to save under again, or
    // empties.
    function drop() {
        if (naming)
            field.text = saving ? heldName : "";

        intent = "";
    }

    // Escape and Cancel give up on what's under way first, then on the dialog.
    function cancel() {
        if (intent !== "")
            drop();
        else
            close();
    }

    function startNaming(kind, name) {
        drop();
        heldName = field.text;
        intent = kind;
        field.text = name;
        selectStem();
    }

    function create() {
        startNaming("new", "");
    }

    function rename() {
        if (!selected)
            return ;

        renamed = selected.path;
        startNaming("rename", selected.name);
    }

    function armTrash() {
        if (trashTargets.length === 0)
            return ;

        drop();
        intent = "trash";
    }

    // Enter or the button, while they're taken for something else than picking.
    function carryOut() {
        if (intent === "replace") {
            save();
            return ;
        }
        if (intent === "trash") {
            const targets = trashTargets;
            intent = "";
            folderList.wanted = folderList.selectsEntry ? folderList.neighbour(targets) : "";
            FileOps.trash(targets, (done) => {
                if (!done) {
                    refuse();
                    return ;
                }
                marked = marked.filter((path) => {
                    return targets.indexOf(path) < 0;
                });
            });
            return ;
        }
        const name = field.text.replace(/\/$/, "");
        const path = Files.join(folder, name);
        if (intent === "rename" && path === renamed) {
            drop();
            return ;
        }
        // A name is one part of a path, and never takes another entry's place.
        if (name === "" || name === "." || name === ".." || name.indexOf("/") >= 0 || folderList.contains(path)) {
            shake.restart();
            return ;
        }
        const from = intent === "rename" ? renamed : "";
        const finish = (done) => {
            if (!done) {
                refuse();
                return ;
            }
            // A marked entry stays marked under its new name.
            marked = marked.map((item) => {
                return item === from ? path : item;
            });
            if (naming)
                drop();

        };
        folderList.wanted = path;
        if (from !== "")
            FileOps.rename(from, path, finish);
        else if (makesFolder)
            FileOps.createFolder(path, finish);
        else
            FileOps.createFile(path, finish);
    }

    // The disk said no (no right to write there): the field shakes.
    function refuse() {
        folderList.wanted = "";
        shake.restart();
    }

    // The name ready to type over, its extension kept.
    function selectStem() {
        const dot = field.text.lastIndexOf(".");
        field.input.select(0, dot > 0 ? dot : field.text.length);
    }

    function select(index) {
        drop();
        folderList.selectedIndex = index;
        // Picking a file while saving takes its name, to save over it.
        if (saving && selected && !selected.isDir)
            field.text = selected.name;

    }

    function move(delta) {
        const count = folderList.entries.length;
        if (count > 0)
            select(Math.max(0, Math.min(count - 1, folderList.selectedIndex + delta)));

    }

    function enter(path) {
        if (typingPath) {
            field.text = Files.collapse(path) + "/";
        } else {
            if (!saving)
                field.text = "";

            folder = path;
        }
    }

    function up() {
        if (folder !== "/")
            enter(Files.parent(folder));

    }

    // To a place of the sidebar: the field keeps a name to save under, not a filter or
    // a path.
    function go(path) {
        drop();
        if (!saving || typingPath)
            field.text = "";

        folder = path;
    }

    // The app takes it as one of several: a file, or a folder when it wants folders.
    function takes(entry) {
        return multiple && entry.isDir === pickingFolder;
    }

    // Marks or unmarks the ones the app takes among these.
    function setMarked(entries, on) {
        const paths = entries.filter(takes).map((entry) => {
            return entry.path;
        });
        const rest = marked.filter((path) => {
            return paths.indexOf(path) < 0;
        });
        marked = on ? rest.concat(paths) : rest;
    }

    // Marking what the app doesn't take, like a folder among files: the field shakes.
    function toggleMark() {
        if (!selected)
            return ;

        if (takes(selected))
            setMarked([selected], marked.indexOf(selected.path) < 0);
        else
            shake.restart();
    }

    // Every entry between two rows of the list.
    function markRange(from, to) {
        setMarked(folderList.entries.slice(Math.max(0, Math.min(from, to)), Math.max(from, to) + 1), true);
    }

    // Shift with up or down: marks from where you are to where you land.
    function moveMarking(delta) {
        const from = folderList.selectedIndex;
        move(delta);
        markRange(from, folderList.selectedIndex);
    }

    // All of them, or none once they all are.
    function toggleAll() {
        setMarked(folderList.entries, !folderList.entries.every((entry) => {
            return !takes(entry) || marked.indexOf(entry.path) >= 0;
        }));
    }

    function nextFilter() {
        if (filters.length > 1)
            filterIndex = (filterIndex + 1) % filters.length;

    }

    // The footer's button, and Shift+Enter.
    function accept() {
        if (intent !== "")
            carryOut();
        else if (saving)
            save();
        else if (marked.length > 0)
            pick(marked);
        else if (pickingFolder)
            pick([selected ? selected.path : folder]);
        else if (selected && selected.isDir)
            enter(selected.path);
        else if (selected)
            pick([selected.path]);
    }

    // Enter, or a double click: into a folder, or the same as the button.
    function activate() {
        if (intent !== "")
            carryOut();
        else if (selected && selected.isDir)
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
        const path = typingPath ? Files.expand(name) : Files.join(folder, name);
        // Saving over a file that's already there takes a second Enter.
        if (folderList.contains(path) && intent !== "replace") {
            intent = "replace";
            return ;
        }
        pick([path]);
    }

    function pick(paths) {
        answered = true;
        FileChooser.answer(paths, filters.length > 0 ? filterIndex : -1);
        close();
    }

    panelName: "filechooser"
    isPrompt: true
    cardWidth: 860
    cardHeight: 540
    onOpening: {
        request = FileChooser.request;
        answered = false;
        marked = [];
        intent = "";
        showHidden = false;
        filterIndex = request ? Math.max(0, request.filter) : 0;
        // Last time's list goes: the new one comes with the card.
        folderList.reset();
        folder = request ? request.folder : Files.home;
        field.text = saving ? request.name : "";
        Qt.callLater(folderList.rebuild);
    }
    onOpenedChanged: {
        if (opened) {
            field.input.forceActiveFocus();
            if (saving)
                selectStem();

        } else if (!answered && request && FileChooser.request && FileChooser.request.id === request.id) {
            FileChooser.cancel();
        }
    }
    // The selection stays on the old list until the new one replaces it.
    onFolderChanged: {
        marked = [];
        drop();
    }

    // The app gave up on its dialog, or another one replaced it. Also while the card is
    // still mapping: an app that quits at once closes its dialog before the first frame.
    Connections {
        function onRequestChanged() {
            if (picker.opened && picker.request && (!FileChooser.request || FileChooser.request.id !== picker.request.id)) {
                picker.answered = true;
                picker.close();
            }
        }

        target: FileChooser
    }

    ServiceRef {
        service: Places
        active: picker.opened
    }

    // The app's title on the left, where you are on the right.
    Item {
        id: header

        x: picker.cardPadding
        y: picker.cardPadding
        width: picker.contentWidth
        height: titleLabel.implicitHeight

        Text {
            id: titleLabel

            anchors.left: parent.left
            anchors.leftMargin: Metrics.spacing.small
            width: Math.min(implicitWidth, parent.width / 2)
            elide: Text.ElideRight
            text: picker.request && picker.request.title !== "" ? picker.request.title : picker.saving ? "Save" : "Open"
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.emphasis
            font.weight: Font.DemiBold
        }

        Text {
            anchors.left: titleLabel.right
            anchors.leftMargin: Metrics.spacing.huge
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing.small
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: Files.collapse(picker.folder)
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.body
        }

    }

    GlassField {
        id: field

        property real shakeOffset: 0

        x: picker.cardPadding + shakeOffset
        anchors.top: header.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.contentWidth
        icon: picker.intent === "new" ? "create_new_folder" : picker.intent === "rename" ? "edit" : picker.saving ? "save" : "search"
        placeholder: picker.intent === "new" ? (picker.pickingFolder ? "New folder's name" : "New file's name, or a folder's ending with /") : picker.intent === "rename" ? "New name" : picker.saving ? "File name" : "Filter, or a path from / or ~"
        // What Enter will do.
        hint: picker.intent === "new" ? (picker.makesFolder ? "Create folder" : "Create file") : picker.intent === "rename" ? "Rename" : picker.intent === "trash" ? (picker.trashTargets.length > 1 ? "Move " + picker.trashTargets.length + " to the trash" : "Move to the trash") : picker.intent === "replace" ? "Enter again to replace" : picker.selected && picker.selected.isDir ? "Open folder" : picker.selected || picker.saving || picker.pickingFolder || picker.marked.length > 0 ? picker.answerLabel : ""
        onTextChanged: {
            // The folder follows the path typed, up to its last slash.
            if (!picker.typingPath)
                return ;

            const cut = text.lastIndexOf("/");
            const directory = cut < 0 ? Files.home : Files.expand(text.substring(0, cut + 1));
            picker.folder = directory.length > 1 ? directory.replace(/\/+$/, "") : directory;
        }
        onKeyPressed: (event) => {
            const move = picker.controlMove(event);
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            const control = (event.modifiers & Qt.ControlModifier) !== 0;
            const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
            // Naming: every other key is typed.
            if (picker.naming) {
                if (enter)
                    picker.carryOut();
                else if (event.key === Qt.Key_Escape)
                    picker.drop();
                else
                    return ;
                event.accepted = true;
                return ;
            }
            if (move && move[1] !== 0)
                picker.move(move[1]);
            else if (move && move[0] < 0)
                picker.up();
            else if (move && picker.selected && picker.selected.isDir)
                picker.enter(picker.selected.path);
            else if (event.key === Qt.Key_Escape)
                picker.cancel();
            else if (enter)
                shift ? picker.accept() : picker.activate();
            else if (shift && event.key === Qt.Key_Down)
                picker.moveMarking(1);
            else if (shift && event.key === Qt.Key_Up)
                picker.moveMarking(-1);
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                picker.move(1);
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                picker.move(-1);
            else if (text === "" && event.key === Qt.Key_Right)
                picker.activate();
            else if (text === "" && (event.key === Qt.Key_Left || Navigation.backs(event)))
                picker.up();
            else if (control && event.key === Qt.Key_Space)
                picker.toggleMark();
            else if (control && event.key === Qt.Key_F)
                picker.nextFilter();
            else if (control && event.key === Qt.Key_Period)
                picker.showHidden = !picker.showHidden;
            else if (control && event.key === Qt.Key_A && picker.multiple)
                picker.toggleAll();
            else if (control && event.key === Qt.Key_N)
                picker.create();
            else if (event.key === Qt.Key_F2)
                picker.rename();
            else if (event.key === Qt.Key_Delete && input.cursorPosition === text.length && input.selectedText === "")
                picker.armTrash();
            else
                return ;
            event.accepted = true;
        }
    }

    // Typing forgets the trash, and a new name the file picked to save over.
    Connections {
        function onTextEdited() {
            if (picker.naming)
                return ;

            picker.intent = "";
            if (picker.saving)
                folderList.selectedIndex = -1;

        }

        target: field.input
    }

    // A name that can't be (empty, taken, refused by the disk), or a mark the app
    // doesn't take: the field shakes.
    Shake {
        id: shake

        target: field
    }

    Item {
        id: body

        x: picker.cardPadding
        anchors.top: field.bottom
        anchors.topMargin: picker.sectionSpacing
        anchors.bottom: footer.top
        anchors.bottomMargin: picker.sectionSpacing
        width: picker.contentWidth

        // Your places: home, the XDG folders, your bookmarks and the root.
        ListView {
            id: placeList

            width: picker.sidebarWidth
            height: parent.height
            clip: true
            spacing: Metrics.spacing.hairline
            boundsBehavior: Flickable.StopAtBounds
            model: Places.list

            delegate: Item {
                id: place

                required property var modelData
                readonly property bool current: picker.folder === modelData.path

                width: ListView.view.width
                height: Metrics.buttonHeight

                GlassSurface {
                    visible: place.current || placeHover.hovered
                    radius: Metrics.radius.normal
                    hovered: true
                }

                // An icon column, so the names line up like the files'.
                Icon {
                    id: placeIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    width: Metrics.spacing.section
                    text: place.modelData.icon
                    color: place.current ? Colors.primary : Colors.secondary
                    size: Metrics.text.emphasis
                }

                Text {
                    anchors.left: placeIcon.right
                    anchors.leftMargin: Metrics.spacing.small
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: place.modelData.name
                    color: place.current ? Colors.primary : Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                }

                HoverHandler {
                    id: placeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: picker.go(place.modelData.path)
                }

            }

        }

        FolderList {
            id: folderList

            anchors.left: placeList.right
            anchors.leftMargin: picker.sectionSpacing
            anchors.right: preview.left
            anchors.rightMargin: picker.sectionSpacing
            height: parent.height
            folder: picker.folder
            reading: picker.shown
            query: picker.query
            globs: picker.filters.length > 0 ? picker.filters[picker.filterIndex].globs : []
            showHidden: picker.showHidden
            showFiles: !picker.pickingFolder
            // Nothing selected at first when saving or picking a folder: Enter then means
            // here, not the first entry.
            selectsEntry: !picker.saving && !picker.pickingFolder
            marked: picker.marked
            onClicked: (index, modifiers) => {
                const from = folderList.selectedIndex;
                picker.select(index);
                if (modifiers & Qt.ShiftModifier)
                    picker.markRange(from, index);
                else if (modifiers & Qt.ControlModifier)
                    picker.toggleMark();

                field.input.forceActiveFocus();
            }
            onDoubleClicked: picker.activate()
        }

        FilePreview {
            id: preview

            anchors.right: parent.right
            width: picker.previewWidth
            height: parent.height
            entry: picker.selected
            folder: picker.folder
            count: folderList.entries.length
        }

    }

    // The file type, the hidden files and what changes the folder (new, rename, trash) on
    // the left, Cancel and the app's button on the right.
    Item {
        id: footer

        x: picker.cardPadding
        y: picker.cardHeight - picker.cardPadding - height
        width: picker.contentWidth
        height: Metrics.buttonHeight

        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: Metrics.spacing.normal

            GlassButton {
                visible: picker.filters.length > 0
                height: parent.height
                icon: "filter_alt"
                label: picker.filters.length > 0 ? picker.filters[picker.filterIndex].name : ""
                onClicked: picker.nextFilter()
            }

            GlassButton {
                height: parent.height
                icon: picker.showHidden ? "visibility" : "visibility_off"
                label: "Hidden"
                active: picker.showHidden
                onClicked: picker.showHidden = !picker.showHidden
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "create_new_folder"
                iconSize: Metrics.text.title
                lit: picker.intent === "new"
                onClicked: picker.create()

                ToolTipArea {
                    text: "New folder · Ctrl+N"
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "edit"
                iconSize: Metrics.text.title
                lit: picker.intent === "rename"
                enabled: picker.selected !== null
                onClicked: picker.rename()

                ToolTipArea {
                    text: "Rename · F2"
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "delete"
                iconSize: Metrics.text.title
                lit: picker.intent === "trash"
                enabled: picker.trashTargets.length > 0
                onClicked: picker.armTrash()

                ToolTipArea {
                    text: "Move to trash · Delete"
                }
            }

        }

        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: Metrics.spacing.normal

            GlassButton {
                height: parent.height
                label: "Cancel"
                onClicked: picker.cancel()
            }

            GlassButton {
                height: parent.height
                label: picker.answerLabel
                accent: true
                onClicked: picker.accept()
            }

        }

    }

}
