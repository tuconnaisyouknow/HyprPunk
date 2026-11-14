import QtQuick
import qs.components
import qs.services
import qs.theme

// The file picker the apps' Open and Save dialogs get through the portal, grown out of
// the island on the focused screen. Type to filter the folder, or a path from / or ~ to
// go there. Up and down or Ctrl + the Vim keys move, Vim's left and right going up a
// folder and into one. Enter opens or picks, and so does right once the field is
// empty, where left and Backspace go up a folder. Shift+Enter picks the folder itself
// when the app wants one. Ctrl+Space marks several files when the app takes them,
// Ctrl+F switches the file type, Ctrl+. shows the hidden files.
// The list is FolderList's; the panel answers the app (FileChooser).
IslandPanel {
    id: picker

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
    readonly property var selected: folderList.selected
    // The files marked with Ctrl+Space or Ctrl+click.
    property var marked: []
    // Saving over a file that's already there takes a second Enter.
    property bool replaceArmed: false
    // A path typed from / or ~: the folder follows it, the rest filters.
    readonly property bool typingPath: /^[\/~]/.test(field.text)
    readonly property string query: saving ? "" : typingPath ? field.text.substring(field.text.lastIndexOf("/") + 1) : field.text
    readonly property int cardPadding: Metrics.spacing.large
    readonly property int sectionSpacing: Metrics.spacing.large
    readonly property int contentWidth: cardWidth - 2 * cardPadding
    readonly property int sidebarWidth: 170
    readonly property int previewWidth: 210
    readonly property string acceptLabel: request && request.acceptLabel !== "" ? request.acceptLabel : saving ? "Save" : pickingFolder ? "Choose" : "Open"
    // What the button and Enter will do.
    readonly property string answerLabel: replaceArmed ? "Replace" : multiple && marked.length > 0 ? acceptLabel + " " + marked.length : acceptLabel

    function select(index) {
        folderList.selectedIndex = index;
        replaceArmed = false;
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

    function toggleMark() {
        if (!multiple || !selected || selected.isDir)
            return ;

        const path = selected.path;
        marked = marked.indexOf(path) >= 0 ? marked.filter((item) => {
            return item !== path;
        }) : marked.concat([path]);
    }

    function nextFilter() {
        if (filters.length > 1)
            filterIndex = (filterIndex + 1) % filters.length;

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
        const path = typingPath ? Files.expand(name) : Files.join(folder, name);
        if (folderList.contains(path) && !replaceArmed) {
            replaceArmed = true;
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
        replaceArmed = false;
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
            // The name ready to type over, its extension kept.
            const dot = field.text.lastIndexOf(".");
            if (saving)
                field.input.select(0, dot > 0 ? dot : field.text.length);

        } else if (!answered && request && FileChooser.request && FileChooser.request.id === request.id) {
            FileChooser.cancel();
        }
    }
    // The selection stays on the old list until the new one replaces it.
    onFolderChanged: {
        marked = [];
        replaceArmed = false;
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
        icon: picker.saving ? "󰆓" : "󰍉"
        placeholder: picker.saving ? "File name" : "Filter, or a path from / or ~"
        // What Enter will do.
        hint: picker.replaceArmed ? "Enter again to replace" : picker.selected && picker.selected.isDir ? "Open folder" : picker.selected || picker.saving || picker.pickingFolder || picker.marked.length > 0 ? picker.answerLabel : ""
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
                folderList.selectedIndex = -1;

        }

        target: field.input
    }

    // Wrong name to save under (empty): the field shakes.
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
                Text {
                    id: placeIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.spacing.large
                    anchors.verticalCenter: parent.verticalCenter
                    width: Metrics.spacing.section
                    text: place.modelData.icon
                    color: place.current ? Colors.primary : Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
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
                    onTapped: {
                        if (!picker.saving || picker.typingPath)
                            field.text = "";

                        picker.folder = place.modelData.path;
                    }
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
                picker.select(index);
                if (modifiers & Qt.ControlModifier)
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

    // The file type and the hidden files on the left, Cancel and the app's button on the right.
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
                icon: "󰈲"
                label: picker.filters.length > 0 ? picker.filters[picker.filterIndex].name : ""
                onClicked: picker.nextFilter()
            }

            GlassButton {
                height: parent.height
                icon: picker.showHidden ? "󰈈" : "󰈉"
                label: "Hidden"
                active: picker.showHidden
                onClicked: picker.showHidden = !picker.showHidden
            }

        }

        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: Metrics.spacing.normal

            GlassButton {
                height: parent.height
                label: "Cancel"
                onClicked: picker.close()
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
