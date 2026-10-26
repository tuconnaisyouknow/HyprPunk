import QtQuick
import Quickshell

// Configuration files in the dynamic island: Enter or a click opens the file in
// nvim in kitty.
SearchPanel {
    id: config

    readonly property string home: Quickshell.env("HOME")
    readonly property int rowHeight: 48
    readonly property int rowSpacing: 4
    // command, when set, is run in kitty instead of nvim on the path.
    readonly property var files: [{
        "icon": "",
        "name": "Hyprland",
        "path": "~/.config/hypr/hyprland.lua"
    }, {
        "icon": "󰌌",
        "name": "Hyprland keybindings",
        "path": "~/.config/hypr/keybindings.lua"
    }, {
        "icon": "󰷛",
        "name": "Hyprlock",
        "path": "~/.config/hypr/hyprlock.conf"
    }, {
        "icon": "",
        "name": "Hypridle",
        "path": "~/.config/hypr/hypridle.conf"
    }, {
        "icon": "",
        "name": "Neovim",
        "path": "~/.config/nvim",
        "command": ["nvim", "+lua Snacks.dashboard.pick(\"files\", { cwd = vim.fn.stdpath(\"config\") })"]
    }, {
        "icon": "",
        "name": "Starship",
        "path": "~/.config/starship.toml"
    }, {
        "icon": "",
        "name": "Kitty",
        "path": "~/.config/kitty/kitty.conf"
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
        Session.launch(["kitty"].concat(file.command || ["nvim", file.path.replace(/^~/, home)]));
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
        color: "#7f849c"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
    }

    ListView {
        id: list

        anchors.fill: parent
        interactive: false
        spacing: config.rowSpacing
        model: config.results

        delegate: Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool selected: config.selectedIndex === index

            width: ListView.view.width
            height: config.rowHeight
            radius: 14
            color: "transparent"

            GlassSurface {
                radius: parent.radius
                visible: row.selected
                hovered: true
            }

            Text {
                id: fileIcon

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: row.modelData.icon
                color: row.selected ? "#cba6f7" : "#b4befe"
                font.family: "JetBrainsMono Nerd Font"
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
                    color: row.selected ? "#cba6f7" : "#cdd6f4"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    font.weight: row.selected ? Font.Bold : Font.Normal
                }

                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    text: row.modelData.path
                    color: "#7f849c"
                    font.family: "JetBrainsMono Nerd Font"
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
