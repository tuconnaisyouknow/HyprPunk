import QtQuick
import Quickshell
import Quickshell.Widgets

// A tray app's menu, drawn in the shell's style instead of Qt's. Each submenu is
// another TrayMenu opening beside its entry, or on the other side near the screen's edge.
PopupWindow {
    id: menu

    // The menu to show: the tray item's, or the entry a submenu unfolds.
    property var handle: null
    // The item the root menu opens from (the tray icon).
    property Item anchorItem: null
    // The menu this one is a submenu of, set by its loader.
    property var parentMenu: null
    readonly property bool isRoot: parentMenu === null
    // Wayland doesn't tell windows where they are, so each menu works out its place from
    // the tray's, which the tray item passes along before opening it.
    property real anchorRight: 0
    // Set when the menu is asked for. The window waits for the app's entries before
    // showing, because a popup that's already up never grows taller and would stay an
    // empty strip.
    property bool wanted: false
    readonly property real screenWidth: isRoot ? (screen ? screen.width : 1920) : parentMenu.screenWidth
    // A submenu goes on the side its parent went, so it never covers it, unless the
    // screen ends there.
    readonly property bool opensLeft: {
        // From the tray, in the screen's bottom right corner.
        if (isRoot)
            return true;

        if (parentMenu.opensLeft)
            return parentMenu.screenLeft - gap - width >= 0;

        return parentMenu.screenLeft + parentMenu.width + gap + width > screenWidth;
    }
    readonly property real screenLeft: {
        if (isRoot)
            return Math.max(0, anchorRight - width);

        return opensLeft ? parentMenu.screenLeft - gap - width : parentMenu.screenLeft + parentMenu.width + gap;
    }
    readonly property int padding: 6
    readonly property int gap: 4
    // The open submenu: the entry it shows and the row it opens beside.
    property int openIndex: -1
    property var openEntry: null
    property Item openRow: null
    property bool openedByKeyboard: false
    // Opened with the keyboard: its first entry is chosen once the application sent them.
    property bool selectFirst: false
    // Hovered, or chosen with the arrows.
    property int currentIndex: -1
    property int pendingIndex: -1
    property bool hasChecks: false
    property bool hasIcons: false
    property real widestRow: 0
    // Added up here rather than read from the column, which only lays out once the window
    // draws, and an empty menu draws nothing, so it would never grow.
    property real rowsHeight: 0
    readonly property real maxHeight: (screen ? screen.height : 1080) - 48
    readonly property bool overflows: rowsHeight + padding * 2 > maxHeight

    // Closes the whole menu, from the root.
    signal dismissed()
    // Left or Escape in a submenu: back to its parent.
    signal backRequested()

    function entryAt(index) {
        return index >= 0 && index < opener.children.values.length ? opener.children.values[index] : null;
    }

    function selectable(entry) {
        return entry !== null && !entry.isSeparator && entry.enabled;
    }

    function measure() {
        let widest = 0;
        let height = 0;
        let checks = false;
        let icons = false;
        for (let i = 0; i < rowRepeater.count; i++) {
            const row = rowRepeater.itemAt(i);
            if (row === null)
                continue;

            widest = Math.max(widest, row.naturalWidth);
            height += row.height;
            const entry = row.modelData;
            if (entry.isSeparator)
                continue;

            checks = checks || entry.buttonType !== QsMenuButtonType.None;
            icons = icons || entry.icon !== "";
        }
        widestRow = widest;
        rowsHeight = height;
        hasChecks = checks;
        hasIcons = icons;
        showWhenReady();
    }

    function open() {
        wanted = true;
        giveUp.restart();
        showWhenReady();
    }

    function showWhenReady() {
        if (wanted && !visible && rowsHeight > 0) {
            giveUp.stop();
            visible = true;
        }
    }

    function openSubmenu(index, keyboard) {
        if (index === openIndex)
            return ;

        submenuDelay.stop();
        // Closed and unloaded before the next opens (Wayland only lets the topmost menu
        // close), then the next one is created beside its own row.
        if (submenuLoader.item !== null)
            submenuLoader.item.close();

        openIndex = -1;
        openEntry = null;
        openRow = null;
        const entry = entryAt(index);
        if (!selectable(entry) || !entry.hasChildren)
            return ;

        openedByKeyboard = keyboard;
        openEntry = entry;
        openRow = rowRepeater.itemAt(index);
        openIndex = index;
    }

    // Its submenus first, deepest first, then itself.
    function close() {
        wanted = false;
        giveUp.stop();
        openSubmenu(-1, false);
        visible = false;
    }

    function hover(index) {
        currentIndex = index;
        const entry = entryAt(index);
        // A short delay before opening or closing, so cutting across other rows on the way
        // to the submenu doesn't close it.
        pendingIndex = selectable(entry) && entry.hasChildren ? index : -1;
        if (pendingIndex === openIndex)
            submenuDelay.stop();
        else
            submenuDelay.restart();
    }

    function activate(index, keyboard) {
        const entry = entryAt(index);
        if (!selectable(entry))
            return ;

        if (entry.hasChildren) {
            openSubmenu(index, keyboard);
            return ;
        }
        entry.triggered();
        menu.dismissed();
    }

    function step(delta) {
        const count = opener.children.values.length;
        let index = currentIndex;
        for (let i = 0; i < count; i++) {
            index = index < 0 ? (delta > 0 ? 0 : count - 1) : (index + delta + count) % count;
            if (selectable(entryAt(index))) {
                currentIndex = index;
                return ;
            }
        }
    }

    function reveal(index) {
        const row = rowRepeater.itemAt(index);
        if (row === null || !overflows)
            return ;

        const top = row.y + entryColumn.y;
        const bottom = top + row.height + menu.padding;
        if (top - menu.padding < flick.contentY)
            flick.contentY = Math.max(0, top - menu.padding);
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }

    implicitWidth: Math.ceil(Math.max(180, Math.min(380, widestRow))) + padding * 2
    implicitHeight: Math.min(rowsHeight + padding * 2, maxHeight)
    color: "transparent"
    grabFocus: true
    onCurrentIndexChanged: reveal(currentIndex)
    onVisibleChanged: {
        card.shown = visible;
        if (!visible) {
            wanted = false;
            openSubmenu(-1, false);
            currentIndex = -1;
            flick.contentY = 0;
        }
    }

    anchor {
        item: menu.isRoot ? menu.anchorItem : menu.parentMenu.openRow
        // The root menu rises from the tray, a submenu unfolds beside its entry, its first
        // row level with it.
        edges: Edges.Top | (menu.opensLeft && !menu.isRoot ? Edges.Left : Edges.Right)
        gravity: menu.isRoot ? Edges.Top | Edges.Left : Edges.Bottom | (menu.opensLeft ? Edges.Left : Edges.Right)
        adjustment: menu.isRoot ? PopupAdjustment.Slide | PopupAdjustment.FlipY : PopupAdjustment.FlipX | PopupAdjustment.SlideY
        // Clears the tray panel border above the icons, like the tooltips.
        margins.top: menu.isRoot ? -23 : -menu.padding
        margins.left: menu.isRoot ? 0 : -(menu.padding + menu.gap)
        margins.right: menu.isRoot ? 0 : -(menu.padding + menu.gap)
    }

    QsMenuOpener {
        id: opener

        // Only while the menu is asked for, since apps refresh it every time it opens.
        menu: menu.wanted ? menu.handle : null
    }

    // If the app never sends its entries, give up so the next click can try again.
    Timer {
        id: giveUp

        interval: 2000
        onTriggered: menu.wanted = false
    }

    Timer {
        id: submenuDelay

        interval: 220
        onTriggered: menu.openSubmenu(menu.pendingIndex, false)
    }

    FocusScope {
        id: card

        property bool shown: false
        // The window already waits for the entries, this just keeps an empty menu invisible.
        readonly property bool revealed: shown && rowRepeater.count > 0

        anchors.fill: parent
        focus: true
        opacity: revealed ? 1 : 0
        scale: revealed ? 1 : 0.96
        transformOrigin: menu.isRoot ? Item.BottomRight : menu.opensLeft ? Item.TopRight : Item.TopLeft
        Keys.onPressed: (event) => {
            switch (event.key) {
            case Qt.Key_Down:
            case Qt.Key_Tab:
                menu.step(1);
                break;
            case Qt.Key_Up:
            case Qt.Key_Backtab:
                menu.step(-1);
                break;
            case Qt.Key_Home:
                menu.currentIndex = -1;
                menu.step(1);
                break;
            case Qt.Key_End:
                menu.currentIndex = -1;
                menu.step(-1);
                break;
            case Qt.Key_Right:
                if (menu.selectable(menu.entryAt(menu.currentIndex)) && menu.entryAt(menu.currentIndex).hasChildren)
                    menu.openSubmenu(menu.currentIndex, true);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                menu.activate(menu.currentIndex, true);
                break;
            case Qt.Key_Left:
                if (!menu.isRoot)
                    menu.backRequested();
                break;
            case Qt.Key_Escape:
                if (menu.isRoot)
                    menu.dismissed();
                else
                    menu.backRequested();
                break;
            default:
                return ;
            }
            event.accepted = true;
        }

        GlassSurface {
            radius: 16
            tinted: false
            backgroundColor: Theme.panel
        }

        Flickable {
            id: flick

            anchors.fill: parent
            clip: menu.overflows
            interactive: menu.overflows
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: menu.rowsHeight + menu.padding * 2

            Column {
                id: entryColumn

                x: menu.padding
                y: menu.padding
                width: flick.width - menu.padding * 2

                Repeater {
                    id: rowRepeater

                    model: opener.children
                    onItemAdded: {
                        Qt.callLater(menu.measure);
                        if (menu.selectFirst && menu.currentIndex < 0)
                            Qt.callLater(menu.step, 1);

                    }
                    onItemRemoved: Qt.callLater(menu.measure)

                    Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool selectable: menu.selectable(modelData)
                        readonly property bool current: selectable && (menu.currentIndex === index || menu.openIndex === index)
                        readonly property real leadingWidth: (menu.hasChecks ? 22 : 0) + (menu.hasIcons ? 24 : 0)
                        // The margins around the label and the chevron, below.
                        readonly property real naturalWidth: modelData.isSeparator ? 0 : 12 + leadingWidth + label.implicitWidth + 8 + chevron.width + 10

                        readonly property string kind: modelData.buttonType + modelData.icon

                        width: entryColumn.width
                        height: modelData.isSeparator ? 9 : 32
                        onNaturalWidthChanged: Qt.callLater(menu.measure)
                        onKindChanged: Qt.callLater(menu.measure)

                        Rectangle {
                            visible: row.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            x: 8
                            width: parent.width - 16
                            height: 1
                            color: Theme.alpha(Theme.text, 0.12)
                        }

                        Rectangle {
                            visible: !row.modelData.isSeparator
                            anchors.fill: parent
                            radius: 10
                            color: row.current ? Theme.alpha(Theme.mauve, 0.16) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }

                            }

                        }

                        Row {
                            visible: !row.modelData.isSeparator
                            anchors.left: parent.left
                            anchors.right: chevron.left
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: row.modelData.enabled ? 1 : 0.4

                            // Check boxes and radio buttons, in the menu's colors.
                            Text {
                                visible: menu.hasChecks
                                width: 22
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const entry = row.modelData;
                                    if (entry.buttonType === QsMenuButtonType.CheckBox)
                                        return entry.checkState === Qt.Checked ? "󰄵" : entry.checkState === Qt.PartiallyChecked ? "󰡖" : "󰄱";

                                    if (entry.buttonType === QsMenuButtonType.RadioButton)
                                        return entry.checkState === Qt.Checked ? "󰐾" : "󰄰";

                                    return "";
                                }
                                color: row.modelData.checkState === Qt.Checked ? Theme.mauve : Theme.lavender
                                font.family: Theme.font
                                font.pixelSize: 15
                            }

                            Item {
                                visible: menu.hasIcons
                                width: 24
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter

                                IconImage {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16
                                    height: 16
                                    implicitSize: 16
                                    visible: row.modelData.icon !== ""
                                    source: row.modelData.icon
                                }

                            }

                            Text {
                                id: label

                                width: parent.width - row.leadingWidth
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.text
                                color: row.current ? Theme.mauve : Theme.lavender
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: row.current ? Font.Medium : Font.Normal
                            }

                        }

                        Text {
                            id: chevron

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: row.modelData.hasChildren && !row.modelData.isSeparator
                            width: visible ? implicitWidth : 0
                            opacity: row.modelData.enabled ? 1 : 0.4
                            text: "󰅂"
                            color: row.current ? Theme.mauve : Theme.lavender
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: row.selectable
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: menu.hover(row.index)
                            onExited: {
                                if (menu.currentIndex === row.index && menu.openIndex !== row.index)
                                    menu.currentIndex = -1;

                            }
                            onClicked: menu.activate(row.index, false)
                        }

                    }

                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }

        }

    }

    LazyLoader {
        id: submenuLoader

        active: menu.visible && menu.openRow !== null
        source: Qt.resolvedUrl("TrayMenu.qml")
        onItemChanged: {
            if (item === null)
                return ;

            item.parentMenu = menu;
            item.handle = Qt.binding(() => {
                return menu.openEntry;
            });
            item.selectFirst = menu.openedByKeyboard;

            item.dismissed.connect(menu.dismissed);
            item.backRequested.connect(() => {
                return menu.openSubmenu(-1, false);
            });
            item.open();
        }
    }

    // The pointer reached the submenu: it stays open whatever rows it crossed.
    Connections {
        function onCurrentIndexChanged() {
            if (submenuLoader.item !== null && submenuLoader.item.currentIndex >= 0) {
                submenuDelay.stop();
                menu.currentIndex = menu.openIndex;
            }
        }

        // Closed by the compositor or because its entry went away.
        function onVisibleChanged() {
            if (submenuLoader.item !== null && !submenuLoader.item.visible)
                menu.openSubmenu(-1, false);

        }

        target: submenuLoader.item
        ignoreUnknownSignals: true
    }

}
