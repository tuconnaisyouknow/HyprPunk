import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// What an app gets to see when it shares your screen: a screen or a window, picked on
// their live previews, or a region you draw. Grown out of the island on the focused
// screen; shell.qml holds the request (ScreenShare) and opens it. The arrows or the Vim
// keys move, Tab switches between screens and windows, Enter shares, Escape cancels.
IslandPanel {
    id: picker

    required property var share
    // Kept from the request, so the card still reads right while it folds away.
    property var request: null
    property bool answered: false
    property string tab: "screens"
    property bool remember: false
    // The windows the app may share, each with its Hyprland window for the preview.
    property var windows: []
    readonly property var entries: tab === "screens" ? Quickshell.screens : windows
    readonly property int cardPadding: 18
    readonly property int sectionSpacing: 14
    readonly property int headerHeight: 38
    readonly property int footerHeight: 38
    readonly property int columns: 3
    readonly property int tileWidth: 236
    readonly property int tileHeight: 170
    // The selection's glass in its cell, and the preview inside it.
    readonly property int highlightInset: 4
    readonly property int highlightRadius: 18
    // The same room above the preview and on its sides.
    readonly property int previewInset: 14
    readonly property int labelSpacing: 8
    // One row, or two with a scroll past them.
    readonly property int rows: Math.max(1, Math.min(2, Math.ceil(entries.length / columns)))

    function setup() {
        request = share.request;
        answered = false;
        remember = request ? request.allowToken : false;
        Hyprland.refreshToplevels();
        const toplevels = Hyprland.toplevels.values;
        windows = (request ? request.windows : []).map((item) => {
            return {
                "handle": item.handle,
                "title": item.title,
                "class": item.class,
                "toplevel": toplevels.find((toplevel) => {
                    return toplevel.address.replace(/^0x/, "").toLowerCase() === item.address;
                }) || null
            };
        });
        switchTab("screens");
    }

    function switchTab(name) {
        tab = name;
        // The screen you're on, the first window.
        grid.currentIndex = name === "screens" ? Math.max(0, Quickshell.screens.indexOf(screen)) : windows.length > 0 ? 0 : -1;
        grid.positionViewAtIndex(Math.max(0, grid.currentIndex), GridView.Contain);
    }

    function accept() {
        const entry = entries[grid.currentIndex];
        if (!entry)
            return ;

        answered = true;
        share.answer(tab === "screens" ? "screen:" + entry.name : "window:" + entry.handle, remember);
        close();
    }

    function drawRegion() {
        answered = true;
        share.pickRegion(screen.name, remember);
        close();
    }

    panelName: "screenshare"
    keyTargets: [keys]
    cardWidth: columns * tileWidth + 2 * cardPadding
    cardHeight: 2 * cardPadding + headerHeight + 2 * sectionSpacing + rows * tileHeight + footerHeight
    onOpening: setup()
    onOpenedChanged: {
        if (!opened && !answered && request && share.request === request)
            share.cancel();

    }

    // Switching to a tab with more or fewer rows.
    Behavior on cardHeight {
        enabled: picker.opened

        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }

    }

    // The app asked again (or another one did): the card shows the new request.
    Connections {
        function onRequestChanged() {
            if (!picker.opened)
                return ;

            if (picker.share.request === null) {
                picker.answered = true;
                picker.close();
            } else if (picker.share.request !== picker.request) {
                picker.setup();
            }
        }

        target: picker.share
    }

    Item {
        id: keys

        Keys.onPressed: (event) => {
            const move = picker.horizontalKey(event);
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                picker.accept();
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                picker.switchTab(picker.tab === "screens" ? "windows" : "screens");
            else if (event.key === Qt.Key_Left || move < 0)
                grid.moveCurrentIndexLeft();
            else if (event.key === Qt.Key_Right || move > 0)
                grid.moveCurrentIndexRight();
            else if (event.key === Qt.Key_Up || event.key === (picker.keyboardLayout === "fr" ? Qt.Key_L : Qt.Key_K))
                grid.moveCurrentIndexUp();
            else if (event.key === Qt.Key_Down || event.key === (picker.keyboardLayout === "fr" ? Qt.Key_K : Qt.Key_J))
                grid.moveCurrentIndexDown();
            else
                return ;
            event.accepted = true;
        }
    }

    // What's asked on the left, screens or windows on the right.
    Item {
        id: header

        x: picker.cardPadding
        y: picker.cardPadding
        width: picker.cardWidth - 2 * picker.cardPadding
        height: picker.headerHeight

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                text: "󰹑"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 14
            }

            Text {
                text: "Share your screen"
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

        }

        SegmentedControl {
            anchors.right: parent.right
            width: 260
            height: parent.height
            compact: true
            value: picker.tab
            options: [{
                "value": "screens",
                "icon": "󰍹",
                "label": "Screens"
            }, {
                "value": "windows",
                "icon": "󰖯",
                "label": "Windows"
            }]
            onSelected: (value) => {
                return picker.switchTab(value);
            }
        }

    }

    GridView {
        id: grid

        x: picker.cardPadding
        anchors.top: header.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.columns * picker.tileWidth
        height: picker.rows * picker.tileHeight
        clip: true
        cellWidth: picker.tileWidth
        cellHeight: picker.tileHeight
        model: picker.entries
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds

        highlight: SelectionHighlight {
            view: grid
            inset: picker.highlightInset
            radius: picker.highlightRadius
        }

        delegate: Item {
            id: tile

            required property var modelData
            required property int index
            readonly property bool isScreen: picker.tab === "screens"
            // What gets captured: the screen, or the window's own surface.
            readonly property var source: isScreen ? modelData : modelData.toplevel ? modelData.toplevel.wayland : null

            width: grid.cellWidth
            height: grid.cellHeight

            // Fainter than the selection's glass, which a click moves here.
            GlassSurface {
                anchors.margins: picker.highlightInset
                radius: picker.highlightRadius
                opacity: tileHover.hovered && grid.currentIndex !== tile.index ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }

                }

            }

            // The room the preview has, under the selection's glass.
            Item {
                id: area

                x: picker.previewInset
                y: picker.previewInset
                width: parent.width - 2 * picker.previewInset
                // What's left once the name has its own room below.
                height: parent.height - picker.previewInset - picker.highlightInset - label.height - 2 * picker.labelSpacing

                // At the screen's or the window's own shape, its corners following the
                // glass around it.
                ClippingRectangle {
                    id: preview

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: capture.hasContent ? capture.implicitWidth : parent.width
                    height: capture.hasContent ? capture.implicitHeight : parent.height
                    radius: picker.highlightRadius - (picker.previewInset - picker.highlightInset)
                    color: Theme.alpha(Theme.crust, 0.6)
                    border.width: 1
                    border.color: grid.currentIndex === tile.index ? Theme.primary : Theme.alpha(Theme.secondary, 0.25)

                    // Before the first frame, or for a window that can't be captured.
                    IconImage {
                        anchors.centerIn: parent
                        visible: !capture.hasContent
                        implicitSize: 40
                        source: {
                            if (tile.isScreen)
                                return Quickshell.iconPath("video-display", "image-missing");

                            const entry = DesktopEntries.heuristicLookup(tile.modelData.class);
                            return Quickshell.iconPath(entry !== null ? entry.icon : "", "application-x-executable");
                        }
                    }

                    ScreencopyView {
                        id: capture

                        anchors.fill: parent
                        constraintSize: Qt.size(area.width, area.height)
                        captureSource: picker.shown ? tile.source : null
                        // Only the screens move: a live capture of every window would cost too much.
                        live: tile.isScreen && picker.opened
                    }

                }

            }

            Text {
                id: label

                // Halfway between the preview and the bottom of the glass.
                readonly property real previewBottom: area.y + preview.height

                x: picker.previewInset
                y: Math.round((previewBottom + tile.height - picker.highlightInset - height) / 2)
                width: parent.width - 2 * picker.previewInset
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.isScreen ? tile.modelData.name : tile.modelData.title || tile.modelData.class
                color: grid.currentIndex === tile.index ? Theme.primary : Theme.secondary
                font.family: Theme.font
                font.pixelSize: 12
            }

            HoverHandler {
                id: tileHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: grid.currentIndex = tile.index
                onDoubleTapped: {
                    grid.currentIndex = tile.index;
                    picker.accept();
                }
            }

        }

    }

    Text {
        anchors.centerIn: grid
        visible: picker.entries.length === 0
        text: "No window to share"
        color: Theme.secondary
        font.family: Theme.font
        font.pixelSize: 13
    }

    // Remembering and the region on the left, Cancel and Share on the right.
    Item {
        x: picker.cardPadding
        anchors.top: grid.bottom
        anchors.topMargin: picker.sectionSpacing
        width: picker.cardWidth - 2 * picker.cardPadding
        height: picker.footerHeight

        Row {
            anchors.left: parent.left
            height: parent.height
            spacing: 8

            // The app can share the same thing again next time without asking.
            Rectangle {
                id: rememberChip

                // The switch sits as far from the right edge as from the top and bottom.
                readonly property real inset: (height - 24) / 2

                implicitWidth: 16 + rememberRow.implicitWidth + inset
                height: parent.height
                radius: height / 2
                color: "transparent"

                GlassSurface {
                    radius: parent.radius
                    hovered: rememberHover.hovered
                    backgroundColor: picker.remember ? Theme.alpha(Theme.primary, 0.14) : "transparent"

                    Behavior on backgroundColor {
                        ColorAnimation {
                            duration: 160
                        }

                    }

                }

                Row {
                    id: rememberRow

                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰁯  Remember"
                        color: picker.remember ? Theme.primary : Theme.secondary
                        font.family: Theme.font
                        font.pixelSize: 13

                        Behavior on color {
                            ColorAnimation {
                                duration: 160
                            }

                        }

                    }

                    // Only shows the state: the whole pill takes the click.
                    ToggleSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: false
                        checked: picker.remember
                    }

                }

                HoverHandler {
                    id: rememberHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        rememberBounce.restart();
                        picker.remember = !picker.remember;
                    }
                }

                BounceAnimation {
                    id: rememberBounce

                    target: rememberChip
                }

            }

            Chip {
                icon: "󰩭"
                label: "Region"
                onClicked: picker.drawRegion()
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
                label: "Share"
                accent: true
                onClicked: picker.accept()
            }

        }

    }

    // The footer's pill buttons: glass with words in the secondary color, or the accent for Share.
    component Chip: Rectangle {
        id: chip

        property string icon: ""
        property string label: ""
        property bool accent: false

        signal clicked()

        implicitWidth: chipLabel.implicitWidth + 32
        height: parent.height
        radius: height / 2
        color: "transparent"

        GlassSurface {
            radius: parent.radius
            hovered: chipHover.hovered
            backgroundColor: chip.accent ? Theme.alpha(Theme.primary, chipHover.hovered ? 0.95 : 0.8) : "transparent"
        }

        Text {
            id: chipLabel

            anchors.centerIn: parent
            text: (chip.icon !== "" ? chip.icon + "  " : "") + chip.label
            color: chip.accent ? Theme.base : Theme.secondary
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
