import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// The app launcher in the dynamic island: a list of your apps, each with what it's for
// under its name, the ones you pinned in the settings first, then the ones you use most,
// narrowed down as you type (Apps). The ones you hid there never show. It does a bit
// more too:
//   2+2       a calculation, Enter copies the result
//   > cmd     runs a command (Shift+Enter in a terminal)
//   ? words   searches the web, also offered when no app matches
// Tab or a right click shows an app's extra actions.
SearchPanel {
    id: launcher

    readonly property int maxRows: 6
    // One row for everything listed: the apps, their actions, the calculation.
    readonly property int rowHeight: 52
    readonly property int rowSpacing: Metrics.spacing.small
    readonly property string trimmedQuery: query.trim()
    readonly property string mode: trimmedQuery.startsWith(">") ? "command" : trimmedQuery.startsWith("?") ? "web" : "apps"
    readonly property string modeArgument: mode === "apps" ? trimmedQuery : trimmedQuery.slice(1).trim()
    readonly property var calculation: mode === "apps" ? Apps.calculate(trimmedQuery) : null
    // Built once the shell has settled after startup, then kept: built at the first
    // opening, the list and its icons froze the card for ~300 ms. Not right away either:
    // building the list as the shell starts held up the bar's first values.
    property bool listWanted: false
    readonly property var results: listWanted && mode === "apps" ? Apps.search(trimmedQuery) : []
    // calc, command, web or "" when there is no special row.
    readonly property string special: mode === "command" ? "command" : mode === "web" ? "web" : calculation !== null ? "calc" : trimmedQuery !== "" && results.length === 0 ? "web" : ""
    readonly property int listRows: Math.min(maxRows, results.length)
    // Application whose actions are listed, null for the apps.
    property var actionsEntry: null
    property int actionIndex: 0
    readonly property var actionRows: actionsEntry ? [{
        "name": "Launch",
        "icon": "",
        "action": null
    }].concat(actionsEntry.actions.map((action) => {
        return {
            "name": action.name,
            "icon": action.icon,
            "action": action
        };
    })) : []

    // Set by hand: as the apps are narrowed down the list moves its rows, and keeps its
    // current one on the app it was on.
    function syncList() {
        list.currentIndex = selectedIndex;
    }

    function rowsHeight(rows) {
        return rows * (rowHeight + rowSpacing) - rowSpacing;
    }

    function launch(entry, action) {
        close();
        Apps.launch(entry, action);
    }

    function activate(shift) {
        if (actionsEntry) {
            launch(actionsEntry, actionRows[actionIndex].action);
            return ;
        }
        if (selectedIndex >= 0 && results.length > 0) {
            if (shift) {
                close();
                Apps.searchWeb(trimmedQuery);
            } else {
                launch(results[selectedIndex]);
            }
            return ;
        }
        if (special === "")
            return ;

        close();
        if (special === "calc" && !shift)
            Quickshell.execDetached(["wl-copy", calculation]);
        else if (special === "command")
            Apps.run(modeArgument, shift);
        else
            Apps.searchWeb(modeArgument);
    }

    function showActions(entry) {
        if (!entry || entry.actions.length === 0)
            return ;

        actionsEntry = entry;
        actionIndex = 0;
    }

    panelName: "launcher"
    searchIcon: actionsEntry ? "󰅂" : "󰍉"
    readOnly: actionsEntry !== null
    placeholder: actionsEntry ? actionsEntry.name : "Search apps, > command, ? web"
    placeholderColor: actionsEntry ? Colors.secondary : Colors.alpha(Colors.secondary, 0.5)
    // What Enter will do in the current mode.
    hint: actionsEntry ? "Tab back" : mode === "command" ? "Run" : mode === "web" ? "Web" : special === "calc" ? "Calc" : ""
    count: results.length
    view: list
    // The calculation comes first, the web search fallback is the only choice.
    defaultIndex: special === "calc" || results.length === 0 ? -1 : 0
    firstIndex: special !== "" ? -1 : 0
    cardWidth: 480
    bodyHeight: actionsEntry ? rowsHeight(actionRows.length) : (special !== "" ? rowHeight : 0) + (special !== "" && listRows > 0 ? sectionSpacing : 0) + (listRows > 0 ? rowsHeight(listRows) : 0)
    // Right on an empty field picks, like in the other lists.
    onActivated: (index, shift) => {
        return activate(shift);
    }
    onOpening: actionsEntry = null
    onDefaultIndexChanged: selectedIndex = defaultIndex
    onSelectedIndexChanged: syncList()
    // Enter and Tab are the launcher's own; so is every key while an app's actions
    // are listed, which go up and down and back to the apps.
    onKeyPressed: (event) => {
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            activate(shift);
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (actionsEntry)
                actionsEntry = null;
            else if (selectedIndex >= 0)
                showActions(results[selectedIndex]);
        } else if (actionsEntry) {
            const move = controlMove(event);
            const step = move ? move[0] + move[1] : event.key === Qt.Key_Up || event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Down || event.key === Qt.Key_Right ? 1 : 0;
            if (step !== 0)
                actionIndex = Math.max(0, Math.min(actionRows.length - 1, actionIndex + step));
            else if (event.key === Qt.Key_Escape || Navigation.backs(event))
                actionsEntry = null;
            else
                return ;
        } else {
            return ;
        }
        event.accepted = true;
    }

    // Like the control center's pages, once the bar has its values.
    Timer {
        interval: 1500
        running: true
        onTriggered: launcher.listWanted = true
    }

    // Calculation, command or web search.
    Rectangle {
        id: specialRow

        readonly property bool selected: launcher.selectedIndex < 0 || launcher.results.length === 0

        width: parent.width
        height: launcher.rowHeight
        // Round ends, like the field above.
        radius: height / 2
        color: "transparent"
        visible: launcher.special !== "" && !launcher.actionsEntry

        GlassSurface {
            radius: parent.radius
            hovered: specialRow.selected
            tinted: specialRow.selected
            backgroundColor: "transparent"
        }

        Text {
            id: specialIcon

            anchors.left: parent.left
            anchors.leftMargin: Metrics.spacing.huge
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.special === "calc" ? "󰃬" : launcher.special === "command" ? "" : "󰖟"
            color: Colors.primary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.heading
        }

        Text {
            anchors.left: specialIcon.right
            anchors.leftMargin: Metrics.spacing.large
            anchors.right: specialHint.left
            anchors.rightMargin: Metrics.spacing.large
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: launcher.special === "calc" ? "= " + launcher.calculation : launcher.modeArgument !== "" ? launcher.modeArgument : launcher.special === "command" ? "Type a command" : "Type a search"
            color: launcher.modeArgument !== "" ? Colors.secondary : Colors.alpha(Colors.secondary, 0.5)
            font.family: Metrics.font
            font.pixelSize: launcher.special === "calc" ? Metrics.text.title : Metrics.text.emphasis
            font.weight: launcher.special === "calc" ? Font.Bold : Font.Normal
        }

        Text {
            id: specialHint

            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing.huge
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.special === "calc" ? "Enter copies" : launcher.special === "command" ? "Shift+Enter in a terminal" : "Search the web"
            color: Colors.secondary
            font.family: Metrics.font
            font.pixelSize: Metrics.text.body
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered && launcher.results.length > 0)
                    launcher.selectedIndex = -1;

            }
        }

        TapHandler {
            onTapped: {
                launcher.selectedIndex = -1;
                launcher.activate(false);
            }
        }

    }

    // Applications.
    ListView {
        id: list

        anchors.top: specialRow.visible ? specialRow.bottom : parent.top
        anchors.topMargin: specialRow.visible ? launcher.sectionSpacing : 0
        width: parent.width
        height: launcher.rowsHeight(launcher.maxRows)
        visible: !launcher.actionsEntry && launcher.mode === "apps"
        clip: true
        spacing: launcher.rowSpacing
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0
        highlightResizeDuration: 0

        // An app keeps its row as long as it's listed, whatever object stands for it:
        // Quickshell makes some anew each time it lists the apps again.
        model: ScriptModel {
            objectProp: "id"
            values: launcher.results
            onValuesChanged: launcher.syncList()
        }

        highlight: SelectionHighlight {
            view: list
            radius: specialRow.radius
        }

        delegate: Item {
            id: row

            required property var modelData
            required property int index
            readonly property bool selected: launcher.selectedIndex === index
            readonly property real pressScale: rowContent.scale

            width: ListView.view.width
            height: launcher.rowHeight

            Item {
                id: rowContent

                anchors.fill: parent
                scale: rowTap.pressed ? 0.97 : 1

                IconImage {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.spacing.huge
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 32
                    asynchronous: true
                    source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                }

                // Centred as a pair, so a name with nothing under it sits in the middle.
                Column {
                    anchors.left: appIcon.right
                    anchors.leftMargin: Metrics.spacing.large
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.spacing.huge
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: row.selected ? Colors.primary : Colors.secondary
                        font.family: Metrics.font
                        font.pixelSize: Metrics.text.emphasis
                        font.weight: row.selected ? Font.Bold : Font.Normal
                    }

                    // What the app is for, or what kind of app it is when it doesn't say.
                    // Cut with an ellipsis, scrolling round on the selected app when it
                    // doesn't fit.
                    Item {
                        id: description

                        readonly property string text: row.modelData.comment || row.modelData.genericName
                        readonly property bool scrolling: row.selected && descriptionText.implicitWidth > width

                        width: parent.width
                        height: descriptionText.implicitHeight
                        visible: text !== ""

                        Text {
                            id: descriptionText

                            width: parent.width
                            visible: !description.scrolling
                            elide: Text.ElideRight
                            text: description.text
                            textFormat: Text.PlainText
                            color: Colors.secondary
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.body
                        }

                        // Only the selected app has one: the list is built at startup.
                        Loader {
                            width: parent.width
                            active: description.scrolling

                            sourceComponent: MarqueeText {
                                text: description.text
                                color: Colors.secondary
                                font.family: Metrics.font
                                font.pixelSize: Metrics.text.body
                            }

                        }

                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.move.small.duration
                        easing.type: Motion.bounce.releaseEasing
                    }

                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        launcher.selectedIndex = row.index;

                }
            }

            TapHandler {
                id: rowTap

                onTapped: launcher.launch(row.modelData)
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    launcher.selectedIndex = row.index;
                    launcher.showActions(row.modelData);
                }
            }

        }

    }

    // Actions of an application (Launch first, then the desktop file's actions).
    Column {
        width: parent.width
        spacing: launcher.rowSpacing
        visible: launcher.actionsEntry !== null

        Repeater {
            model: launcher.actionRows

            Rectangle {
                id: actionRow

                required property var modelData
                required property int index
                readonly property bool selected: launcher.actionIndex === index

                width: parent.width
                height: launcher.rowHeight
                radius: specialRow.radius
                color: "transparent"

                GlassSurface {
                    radius: parent.radius
                    hovered: actionRow.selected
                    tinted: actionRow.selected
                }

                IconImage {
                    id: actionIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Metrics.spacing.huge
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 28
                    asynchronous: true
                    source: Quickshell.iconPath(actionRow.modelData.icon || launcher.actionsEntry.icon, "application-x-executable")
                }

                Text {
                    anchors.left: actionIcon.right
                    anchors.leftMargin: Metrics.spacing.large
                    anchors.right: parent.right
                    anchors.rightMargin: Metrics.spacing.huge
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: actionRow.modelData.name
                    color: actionRow.selected ? Colors.primary : Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.emphasis
                    font.weight: actionRow.selected ? Font.Bold : Font.Normal
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered)
                            launcher.actionIndex = actionRow.index;

                    }
                }

                TapHandler {
                    onTapped: launcher.launch(launcher.actionsEntry, actionRow.modelData.action)
                }

            }

        }

    }

}
