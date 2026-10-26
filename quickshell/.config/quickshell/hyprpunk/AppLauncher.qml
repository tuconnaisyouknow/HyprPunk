import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Application launcher in the dynamic island: a grid of the applications, the ones
// launched often first, filtered by a fuzzy search. The query can also be a
// calculation (Enter copies the result), "> command" (Enter runs it, Shift+Enter
// in a terminal) or "? words" (web search, also offered when no application
// matches and on Shift+Enter). Tab or a right click lists the actions of an
// application.
IslandPanel {
    id: launcher

    readonly property string terminal: "kitty"
    readonly property string searchUrl: "https://www.startpage.com/sp/search?query="
    // Runs the command given as $1 in a terminal, which then waits for Enter to close.
    readonly property string holdScript: "eval \"$1\"; status=$?; printf '\\n\\033[2m[exit %s] Press Enter to close\\033[0m' \"$status\"; read -r _"
    readonly property string historyPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/launcher-history.json"
    readonly property int cardPadding: 14
    readonly property int fieldHeight: 44
    readonly property int sectionSpacing: 12
    readonly property int columns: 4
    readonly property int cellWidth: 112
    readonly property int cellHeight: 104
    readonly property int maxRows: 3
    readonly property int rowHeight: 52
    readonly property int rowSpacing: 6

    property string query: ""
    // { "<desktop id>": { "count": launches, "last": ms since epoch } }
    property var history: ({})
    // Index in results, -1 for the special row (calculation, command or web search).
    property int selectedIndex: 0
    // Application whose actions are listed, null for the grid.
    property var actionsEntry: null
    property int actionIndex: 0

    readonly property string trimmedQuery: query.trim()
    readonly property string mode: trimmedQuery.startsWith(">") ? "command" : trimmedQuery.startsWith("?") ? "web" : "apps"
    readonly property string modeArgument: mode === "apps" ? trimmedQuery : trimmedQuery.slice(1).trim()
    readonly property var calculation: mode === "apps" ? calculate(trimmedQuery) : null
    readonly property var results: mode === "apps" ? search(trimmedQuery, DesktopEntries.applications.values, history) : []
    // calc, command, web or "" when there is no special row.
    readonly property string special: mode === "command" ? "command" : mode === "web" ? "web" : calculation !== null ? "calc" : trimmedQuery !== "" && results.length === 0 ? "web" : ""
    readonly property int gridRows: Math.min(maxRows, Math.ceil(results.length / columns))
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

    // Score of a query against a text, 0 when it does not match: whole text, then
    // prefix, word start, substring and finally (fuzzy) letters in order, close enough.
    function matchScore(text, needle, fuzzy) {
        if (!text)
            return 0;

        const haystack = text.toLowerCase();
        if (haystack === needle)
            return 100;

        if (haystack.startsWith(needle))
            return 80;

        const index = haystack.indexOf(needle);
        if (index > 0)
            return /[\s\-_.]/.test(haystack[index - 1]) ? 65 : 45;

        if (!fuzzy)
            return 0;

        let position = 0;
        let gaps = 0;
        for (let i = 0; i < needle.length; i++) {
            const found = haystack.indexOf(needle[i], position);
            if (found < 0)
                return 0;

            gaps += found - position;
            position = found + 1;
        }
        return gaps <= 2 * needle.length ? 30 - gaps : 0;
    }

    // Launches weigh less as they get older (half after two weeks).
    function frecency(id, records) {
        const record = records[id];
        if (!record)
            return 0;

        const days = (Date.now() - record.last) / 86400000;
        return record.count / (1 + days / 14);
    }

    function search(text, entries, records) {
        const needle = text.toLowerCase();
        const matches = [];
        for (const entry of entries) {
            if (entry.noDisplay)
                continue;

            let score = 0;
            if (needle !== "") {
                score = Math.max(matchScore(entry.name, needle, true), 0.8 * matchScore(entry.genericName, needle, false), 0.7 * Math.max(0, ...entry.keywords.map((keyword) => {
                    return matchScore(keyword, needle, false);
                })), 0.6 * matchScore(entry.id, needle, false), needle.length > 2 ? 0.4 * matchScore(entry.comment, needle, false) : 0);
                if (score === 0)
                    continue;

            }
            matches.push({
                "entry": entry,
                "score": score + Math.min(20, 4 * frecency(entry.id, records))
            });
        }
        matches.sort((a, b) => {
            return b.score - a.score || a.entry.name.localeCompare(b.entry.name);
        });
        return matches.map((match) => {
            return match.entry;
        });
    }

    // Only digits, operators and parentheses (so evaluating it runs no code), with
    // at least one operator. Commas are decimal points, ^ is the power.
    function calculate(text) {
        if (!/^[\d\s+\-*/%^().,]+$/.test(text) || !/[\d)]\s*[+\-*/%^]\s*[\d(.]/.test(text))
            return null;

        try {
            const value = Function("return (" + text.replace(/,/g, ".").replace(/\^/g, "**") + ");")();
            if (typeof value !== "number" || !isFinite(value))
                return null;

            return String(Number(value.toPrecision(12)));
        } catch (error) {
            return null;
        }
    }

    function remember(entry) {
        const records = Object.assign({}, history);
        const record = records[entry.id] || {
            "count": 0,
            "last": 0
        };
        records[entry.id] = {
            "count": record.count + 1,
            "last": Date.now()
        };
        history = records;
        historyFile.setText(JSON.stringify(records));
    }

    function launch(entry, action) {
        remember(entry);
        close();
        // Through Hyprland, so the app gets the current locale (Session).
        const command = action ? action.command : entry.command;
        Session.launch(entry.runInTerminal ? [terminal, "-e"].concat(command) : command, entry.workingDirectory || Quickshell.env("HOME"));
    }

    function searchWeb(text) {
        close();
        if (text !== "")
            Session.launch(["xdg-open", searchUrl + encodeURIComponent(text)]);

    }

    function runCommand(command, inTerminal) {
        close();
        if (command === "")
            return ;

        // Not kitty --hold: it opens a shell afterwards, whose fastfetch hides the output.
        Session.launch(inTerminal ? [terminal, "-e", "sh", "-c", holdScript, "sh", command] : ["sh", "-c", command]);
    }

    function activate(shift) {
        if (actionsEntry) {
            const row = actionRows[actionIndex];
            launch(actionsEntry, row.action);
        } else if (selectedIndex < 0 || results.length === 0) {
            if (special === "calc" && !shift) {
                Quickshell.execDetached(["wl-copy", calculation]);
                close();
            } else if (special === "command") {
                runCommand(modeArgument, shift);
            } else if (special !== "") {
                searchWeb(modeArgument);
            }
        } else if (shift) {
            searchWeb(trimmedQuery);
        } else {
            launch(results[selectedIndex]);
        }
    }

    function showActions(entry) {
        if (!entry || entry.actions.length === 0)
            return ;

        actionsEntry = entry;
        actionIndex = 0;
    }

    // Moves the selection in the grid (dx, dy in cells), through the special row above it.
    function move(dx, dy) {
        if (actionsEntry) {
            actionIndex = Math.max(0, Math.min(actionRows.length - 1, actionIndex + dy + dx));
            return ;
        }
        const count = results.length;
        const top = special !== "" ? -1 : 0;
        if (count === 0)
            return ;

        if (selectedIndex < 0) {
            if (dy > 0 || dx > 0)
                selectedIndex = 0;

            return ;
        }
        if (dy < 0 && selectedIndex < columns) {
            selectedIndex = top;
            return ;
        }
        selectedIndex = Math.max(top < 0 && dx < 0 && selectedIndex === 0 ? -1 : 0, Math.min(count - 1, selectedIndex + dx + dy * columns));
    }

    // Left/right/down/up with Ctrl and the layout's keys (Ctrl+j/m/k/l on AZERTY,
    // Ctrl+h/l/j/k on QWERTY), the letters being typed.
    function controlKey(event) {
        if (!(event.modifiers & Qt.ControlModifier))
            return null;

        const keys = keyboardLayout === "fr" ? [Qt.Key_J, Qt.Key_M, Qt.Key_K, Qt.Key_L] : [Qt.Key_H, Qt.Key_L, Qt.Key_J, Qt.Key_K];
        const moves = [[-1, 0], [1, 0], [0, 1], [0, -1]];
        const index = keys.indexOf(event.key);
        return index >= 0 ? moves[index] : null;
    }

    panelName: "launcher"
    cardWidth: columns * cellWidth + 2 * cardPadding
    cardHeight: 2 * cardPadding + fieldHeight + (actionsEntry ? sectionSpacing + actionRows.length * (rowHeight + rowSpacing) - rowSpacing : (special !== "" ? sectionSpacing + rowHeight : 0) + (gridRows > 0 ? sectionSpacing + gridRows * cellHeight : 0))
    onOpening: {
        query = "";
        searchInput.text = "";
        actionsEntry = null;
        selectedIndex = 0;
        grid.positionViewAtBeginning();
    }
    onOpenedChanged: {
        if (opened)
            searchInput.forceActiveFocus();

    }
    // The calculation comes first, the web search fallback is the only choice.
    onSpecialChanged: selectedIndex = special === "calc" || results.length === 0 ? -1 : 0
    onResultsChanged: {
        selectedIndex = special === "calc" || results.length === 0 ? -1 : 0;
        grid.positionViewAtBeginning();
    }
    onSelectedIndexChanged: {
        if (selectedIndex >= 0)
            grid.positionViewAtIndex(selectedIndex, GridView.Contain);

    }

    FileView {
        id: historyFile

        path: launcher.historyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                launcher.history = JSON.parse(text()) || {};
            } catch (error) {
                launcher.history = {};
            }
        }
    }

    Behavior on cardHeight {
        enabled: launcher.opened

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    // Search field.
    Rectangle {
        id: field

        anchors.top: parent.top
        anchors.topMargin: launcher.cardPadding
        anchors.horizontalCenter: parent.horizontalCenter
        width: launcher.cardWidth - 2 * launcher.cardPadding
        height: launcher.fieldHeight
        radius: height / 2
        color: "transparent"

        GlassSurface {
            radius: parent.radius
            backgroundColor: Qt.rgba(30 / 255, 30 / 255, 46 / 255, 0.6)
        }

        Text {
            id: searchIcon

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.actionsEntry ? "󰅂" : "󰍉"
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }

        TextInput {
            id: searchInput

            anchors.left: searchIcon.right
            anchors.leftMargin: 10
            anchors.right: modeHint.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: "#cdd6f4"
            selectionColor: Qt.rgba(203 / 255, 166 / 255, 247 / 255, 0.35)
            selectedTextColor: "#cdd6f4"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            clip: true
            cursorDelegate: Item {
            }
            readOnly: launcher.actionsEntry !== null
            onTextChanged: launcher.query = text
            Keys.onPressed: (event) => {
                const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                const controlMove = launcher.controlKey(event);
                if (controlMove) {
                    launcher.move(controlMove[0], controlMove[1]);
                } else if (event.key === Qt.Key_Escape) {
                    if (launcher.actionsEntry)
                        launcher.actionsEntry = null;
                    else
                        launcher.back();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    launcher.activate(shift);
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    if (launcher.actionsEntry)
                        launcher.actionsEntry = null;
                    else if (launcher.selectedIndex >= 0)
                        launcher.showActions(launcher.results[launcher.selectedIndex]);
                } else if (event.key === Qt.Key_Left) {
                    launcher.move(-1, 0);
                } else if (event.key === Qt.Key_Right) {
                    launcher.move(1, 0);
                } else if (event.key === Qt.Key_Up) {
                    launcher.move(0, -1);
                } else if (event.key === Qt.Key_Down) {
                    launcher.move(0, 1);
                } else {
                    return ;
                }
                event.accepted = true;
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.text === ""
                text: launcher.actionsEntry ? launcher.actionsEntry.name : "Search apps, > command, ? web"
                color: launcher.actionsEntry ? "#cdd6f4" : "#7f849c"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: parent.font.pixelSize
            }

            BlockCursor {
                input: searchInput
            }

        }

        // What Enter will do in the current mode.
        Text {
            id: modeHint

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.actionsEntry ? "Tab back" : launcher.mode === "command" ? "Run" : launcher.mode === "web" ? "Web" : launcher.special === "calc" ? "Calc" : ""
            color: "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }

    }

    // Calculation, command or web search.
    Rectangle {
        id: specialRow

        readonly property bool selected: launcher.selectedIndex < 0 || launcher.results.length === 0

        anchors.top: field.bottom
        anchors.topMargin: launcher.sectionSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: field.width
        height: launcher.rowHeight
        radius: 16
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
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.special === "calc" ? "󰃬" : launcher.special === "command" ? "" : "󰖟"
            color: "#cba6f7"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 20
        }

        Text {
            anchors.left: specialIcon.right
            anchors.leftMargin: 14
            anchors.right: specialHint.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: launcher.special === "calc" ? "= " + launcher.calculation : launcher.modeArgument !== "" ? launcher.modeArgument : launcher.special === "command" ? "Type a command" : "Type a search"
            color: launcher.modeArgument !== "" ? "#cdd6f4" : "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: launcher.special === "calc" ? 18 : 15
            font.weight: launcher.special === "calc" ? Font.Bold : Font.Normal
        }

        Text {
            id: specialHint

            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: launcher.special === "calc" ? "Enter copies" : launcher.special === "command" ? "Shift+Enter in " + launcher.terminal : "Search the web"
            color: "#7f849c"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
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
    GridView {
        id: grid

        anchors.top: specialRow.visible ? specialRow.bottom : field.bottom
        anchors.topMargin: launcher.sectionSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        width: launcher.columns * launcher.cellWidth
        height: launcher.maxRows * launcher.cellHeight
        visible: !launcher.actionsEntry && launcher.mode === "apps"
        clip: true
        cellWidth: launcher.cellWidth
        cellHeight: launcher.cellHeight
        boundsBehavior: Flickable.StopAtBounds
        model: launcher.results

        delegate: Item {
            id: cell

            required property var modelData
            required property int index
            readonly property bool selected: launcher.selectedIndex === index

            width: launcher.cellWidth
            height: launcher.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 18
                color: "transparent"
                scale: cellTap.pressed ? 0.94 : 1

                GlassSurface {
                    radius: parent.radius
                    visible: cell.selected
                    hovered: true
                }

                IconImage {
                    id: appIcon

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    implicitSize: 48
                    asynchronous: true
                    source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                }

                Text {
                    anchors.top: appIcon.bottom
                    anchors.topMargin: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    color: cell.selected ? "#cba6f7" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: cell.selected ? Font.Bold : Font.Normal
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
                        launcher.selectedIndex = cell.index;

                }
            }

            TapHandler {
                id: cellTap

                onTapped: launcher.launch(cell.modelData)
            }

            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    launcher.selectedIndex = cell.index;
                    launcher.showActions(cell.modelData);
                }
            }

        }

    }

    // Actions of an application (Launch first, then the desktop file's actions).
    Column {
        anchors.top: field.bottom
        anchors.topMargin: launcher.sectionSpacing
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: launcher.rowSpacing
        visible: launcher.actionsEntry !== null

        Repeater {
            model: launcher.actionRows

            Rectangle {
                id: actionRow

                required property var modelData
                required property int index
                readonly property bool selected: launcher.actionIndex === index

                width: field.width
                height: launcher.rowHeight
                radius: 16
                color: "transparent"

                GlassSurface {
                    radius: parent.radius
                    hovered: actionRow.selected
                    tinted: actionRow.selected
                }

                IconImage {
                    id: actionIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: 28
                    asynchronous: true
                    source: Quickshell.iconPath(actionRow.modelData.icon || launcher.actionsEntry.icon, "application-x-executable")
                }

                Text {
                    anchors.left: actionIcon.right
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: actionRow.modelData.name
                    color: actionRow.selected ? "#cba6f7" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
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
