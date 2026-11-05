import QtQuick
import Quickshell

// Quick access to your own config files, opened in your editor. HyprPunk's own files
// stay out, since editing them would clash with the next git pull.
SearchPanel {
    id: config

    readonly property string home: Quickshell.env("HOME")
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 4
    // $EDITOR on the path, in your terminal. A folder in Neovim opens its file picker.
    readonly property string editScript: "if [ -d \"$1\" ] && [ \"${EDITOR:-nvim}\" = nvim ]; then exec nvim \"+lua Snacks.dashboard.pick('files', { cwd = '$1' })\"; fi; exec ${EDITOR:-nvim} \"$1\""
    readonly property var files: [{
        "icon": "",
        "name": "Hyprland",
        "path": "~/.config/hypr/personal"
    }, {
        "icon": "󰌌",
        "name": "Hyprland keybindings",
        "path": "~/.config/hypr/personal/keybindings.lua"
    }, {
        "icon": "󰖲",
        "name": "Window rules",
        "path": "~/.config/hypr/personal/rules.lua"
    }, {
        "icon": "󰍽",
        "name": "Mouse and touchpad",
        "path": "~/.config/hypr/personal/input.lua"
    }, {
        "icon": "",
        "name": "Environment variables",
        "path": "~/.config/hypr/personal/env.lua"
    }, {
        "icon": "󱓞",
        "name": "Autostart",
        "path": "~/.config/hypr/personal/autostart.lua"
    }, {
        "icon": "󰆍",
        "name": "Zsh",
        "path": "~/.personalrc"
    }, {
        "icon": "󰉹",
        "name": "Zsh completions",
        "path": "~/.completionrc"
    }, {
        "icon": "",
        "name": "Tmux",
        "path": "~/.config/tmux/personal.conf"
    }, {
        "icon": "󰄛",
        "name": "Kitty",
        "path": "~/.config/kitty/personal.conf"
    }]
    readonly property var results: {
        const words = query.toLowerCase().split(/\s+/).filter((word) => {
            return word !== "";
        });
        return files.filter((file) => {
            const text = (file.name + " " + file.path).toLowerCase();
            return words.every((word) => {
                return text.includes(word);
            });
        });
    }

    function edit(file) {
        close();
        Session.launchInTerminal(["sh", "-c", editScript, "sh", file.path.replace(/^~/, home)]);
    }

    panelName: "config"
    searchIcon: ""
    placeholder: "Search configuration files"
    count: results.length
    view: list
    cardWidth: 520
    bodyHeight: results.length > 0 ? results.length * (rowHeight + rowSpacing) - rowSpacing : 40
    onActivated: (index) => {
        return edit(results[index]);
    }

    Text {
        anchors.centerIn: parent
        visible: config.results.length === 0
        text: "No file"
        color: Theme.lavender
        font.family: Theme.font
        font.pixelSize: 14
    }

    ListView {
        id: list

        anchors.fill: parent
        interactive: false
        spacing: config.rowSpacing
        model: config.results
        currentIndex: config.selectedIndex
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
            readonly property bool selected: config.selectedIndex === index

            width: ListView.view.width
            height: config.rowHeight
            radius: 14
            color: "transparent"

            Text {
                id: fileIcon

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: row.modelData.icon
                color: row.selected ? Theme.mauve : Theme.lavender
                font.family: Theme.font
                font.pixelSize: 18
            }

            Column {
                anchors.left: fileIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name
                    color: row.selected ? Theme.mauve : Theme.lavender
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: row.selected ? Font.Bold : Font.Normal
                }

                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: row.modelData.path
                    color: Theme.lavender
                    font.family: Theme.font
                    font.pixelSize: 11
                }

            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered)
                        config.selectedIndex = row.index;

                }
            }

            TapHandler {
                onTapped: config.edit(row.modelData)
            }

        }

    }

}
