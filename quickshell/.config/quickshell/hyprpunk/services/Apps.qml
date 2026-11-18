pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Your apps for the launcher: finding them as you type, ranked by how well they match and
// how often and lately you launch them (the history in launcher-history.json), and
// launching them. Also the launcher's calculations and web searches.
Singleton {
    id: apps

    readonly property string searchUrl: "https://www.startpage.com/sp/search?query="
    readonly property string historyPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/launcher-history.json"
    // { "<desktop id>": { "count": launches, "last": ms since epoch } }
    property var history: ({
    })
    // The installed apps, taken once Quickshell is done listing them. It lists them again
    // at every change in your home folder (a terminal saving its history after each
    // command), taking some out and putting them back on the way: followed step by step,
    // that rebuilt the launcher's list several times and froze whatever was moving.
    property var installed: []

    // How well a query matches a text, 0 for not at all. Best is the whole text, then
    // the start, the start of a word, anywhere, and last the letters in order, close together.
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

    // Your apps matching text, best first. Pinned apps come before every other while
    // nothing is typed, in their order; the hidden ones never show.
    function search(text) {
        const needle = text.toLowerCase();
        const pinned = LauncherSettings.pinned;
        const hidden = LauncherSettings.hidden;
        const records = history;
        const matches = [];
        for (const entry of installed) {
            if (entry.noDisplay || hidden.includes(entry.id))
                continue;

            let score = 0;
            if (needle !== "") {
                score = Math.max(matchScore(entry.name, needle, true), 0.8 * matchScore(entry.genericName, needle, false), 0.7 * Math.max(0, ...entry.keywords.map((keyword) => {
                    return matchScore(keyword, needle, false);
                })), 0.6 * matchScore(entry.id, needle, false), needle.length > 2 ? 0.4 * matchScore(entry.comment, needle, false) : 0);
                if (score === 0)
                    continue;

            }
            const pin = needle === "" ? pinned.indexOf(entry.id) : -1;
            matches.push({
                "entry": entry,
                "score": pin >= 0 ? 1000 - pin : score + Math.min(20, 4 * frecency(entry.id, records))
            });
        }
        matches.sort((a, b) => {
            return b.score - a.score || a.entry.name.localeCompare(b.entry.name);
        });
        return matches.map((match) => {
            return match.entry;
        });
    }

    // Digits, operators and parentheses only, so evaluating it can't run any code, and at
    // least one operator. Commas work as decimal points, ^ is a power.
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
        file.setText(JSON.stringify(records));
    }

    // An app, or one of its actions (null for the app itself).
    function launch(entry, action) {
        remember(entry);
        // Through Hyprland, so the app gets the current locale (Session).
        const command = action ? action.command : entry.command;
        const directory = entry.workingDirectory || Quickshell.env("HOME");
        if (entry.runInTerminal)
            Session.launchInTerminal(command, directory);
        else
            Session.launch(command, directory);
    }

    function searchWeb(text) {
        if (text !== "")
            Session.launch(["xdg-open", searchUrl + encodeURIComponent(text)]);

    }

    Component.onCompleted: installed = DesktopEntries.applications.values

    Connections {
        function onApplicationsChanged() {
            apps.installed = DesktopEntries.applications.values;
        }

        target: DesktopEntries
    }

    FileView {
        id: file

        path: apps.historyPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                apps.history = JSON.parse(text()) || {
                };
            } catch (error) {
                apps.history = {
                };
            }
        }
    }

}
