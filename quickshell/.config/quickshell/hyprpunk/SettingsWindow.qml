import QtQuick
import QtQuick.Layouts
import Quickshell

// The settings, in a window of their own that floats in the middle of the screen you're
// on (rules.lua): a section per subject on the left, its page on the right. Super+I
// closes it when it's the window you're on, and brings it to you from anywhere else.
// The keys move through the controls (KeyboardFocus), Escape closes it.
// The window only exists while it's open: one closed by Hyprland (Super+Q) can't be
// shown again, so every way of closing it unloads it, and opening builds a new one.
Scope {
    id: settings

    // The shell's file picker, for the pages that ask for a folder.
    required property var fileChooser
    // The shell's state, for the pages that open an island panel.
    required property var shellState
    // In the sidebar's order, each with its page (DisplaysPage.qml).
    readonly property var sections: [{
        "name": "displays",
        "icon": "󰍹",
        "label": "Displays"
    }, {
        "name": "input",
        "icon": "󰍽",
        "label": "Mouse and touchpad"
    }, {
        "name": "language",
        "icon": "󰌌",
        "label": "Keyboard and language"
    }, {
        "name": "sound",
        "icon": "󰕾",
        "label": "Sound"
    }, {
        "name": "battery",
        "icon": "󰁹",
        "label": "Battery"
    }, {
        "name": "power",
        "icon": "󰒲",
        "label": "Idle and sleep"
    }, {
        "name": "lock",
        "icon": "󰌾",
        "label": "Lock screen"
    }, {
        "name": "nightlight",
        "icon": "󰖔",
        "label": "Night light"
    }, {
        "name": "appearance",
        "icon": "󰏘",
        "label": "Appearance"
    }, {
        "name": "notifications",
        "icon": "󰂚",
        "label": "Notifications"
    }, {
        "name": "island",
        "icon": "󰍡",
        "label": "Island"
    }, {
        "name": "apps",
        "icon": "󰀻",
        "label": "Default apps"
    }, {
        "name": "launcher",
        "icon": "󱓞",
        "label": "Launcher"
    }, {
        "name": "capture",
        "icon": "󰹑",
        "label": "Screenshots"
    }, {
        "name": "history",
        "icon": "󰅌",
        "label": "Clipboard and history"
    }, {
        "name": "updates",
        "icon": "󰚰",
        "label": "Updates"
    }]
    // Kept between openings.
    property string section: "displays"

    // Built again rather than raised: a new window opens where you are.
    function open() {
        if (loader.active) {
            loader.active = false;
            Qt.callLater(() => {
                return loader.active = true;
            });
        } else {
            loader.active = true;
        }
    }

    function close() {
        loader.active = false;
    }

    function toggle() {
        if (loader.item !== null && loader.item.focused)
            close();
        else
            open();
    }

    LazyLoader {
        id: loader

        FloatingWindow {
            id: window

            // The window you're on.
            readonly property bool focused: content.Window.active

            // Keys no control kept for itself (a slider its arrows).
            function keyPressed(event) {
                const direction = Navigation.direction(event);
                if (event.key === Qt.Key_Escape || Navigation.backs(event))
                    settings.close();
                else if (Navigation.accepts(event))
                    keyboardFocus.activate(false);
                else if (direction !== null)
                    keyboardFocus.move(direction[0], direction[1]);
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    keyboardFocus.step(event.key === Qt.Key_Tab ? 1 : -1);
                else
                    return ;
                event.accepted = true;
            }

            title: "HyprPunk Settings"
            implicitWidth: 1080
            implicitHeight: 820
            color: Theme.base
            onClosed: settings.close()

            Item {
                id: content

                anchors.fill: parent
                focus: true
                Keys.onPressed: (event) => {
                    return window.keyPressed(event);
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // Its rows fill it, which would make it share the width with the page.
                    ColumnLayout {
                        Layout.preferredWidth: 250
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: 4

                        Text {
                            Layout.leftMargin: 8
                            Layout.bottomMargin: 12
                            text: "Settings"
                            color: Theme.primary
                            font.family: Theme.font
                            font.pixelSize: 22
                            font.weight: Font.Bold
                        }

                        Repeater {
                            model: settings.sections

                            // The section shown in the accent, like a chosen option; the
                            // others bare, with a glass halo under the pointer.
                            Item {
                                id: tab

                                required property var modelData
                                readonly property bool chosen: settings.section === modelData.name
                                readonly property real radius: 14

                                function activate() {
                                    tabBounce.restart();
                                    settings.section = modelData.name;
                                }

                                Layout.fillWidth: true
                                implicitHeight: 40
                                activeFocusOnTab: true

                                GlassSurface {
                                    radius: tab.radius
                                    hovered: tabHover.hovered
                                    backgroundColor: tab.chosen ? Theme.alpha(Theme.primary, 0.85) : "transparent"
                                    opacity: tab.chosen || tabHover.hovered ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 120
                                        }

                                    }

                                }

                                RowLayout {
                                    id: tabContent

                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Text {
                                        Layout.preferredWidth: 24
                                        horizontalAlignment: Text.AlignHCenter
                                        text: tab.modelData.icon
                                        color: tab.chosen ? Theme.base : Theme.secondary
                                        font.family: Theme.font
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: tab.modelData.label
                                        color: tab.chosen ? Theme.base : Theme.secondary
                                        elide: Text.ElideRight
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: tab.chosen ? Font.Bold : Font.Medium
                                    }

                                }

                                HoverHandler {
                                    id: tabHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: tab.activate()
                                }

                                BounceAnimation {
                                    id: tabBounce

                                    target: tabContent
                                }

                            }

                        }

                        Item {
                            Layout.fillHeight: true
                        }

                    }

                    // A page taller than the window scrolls. Each page starts at its top.
                    Flickable {
                        id: scroller

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: page.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Connections {
                            function onSectionChanged() {
                                scroller.contentY = 0;
                            }

                            target: settings
                        }

                        // Only the page shown exists: built as you open it, so a long
                        // list (the launcher's apps) costs nothing until then.
                        Loader {
                            id: page

                            width: scroller.width
                            sourceComponent: ({
                                "displays": displaysPage,
                                "input": inputPage,
                                "language": languagePage,
                                "sound": soundPage,
                                "battery": batteryPage,
                                "power": powerPage,
                                "lock": lockPage,
                                "nightlight": nightLightPage,
                                "appearance": appearancePage,
                                "notifications": notificationsPage,
                                "island": islandPage,
                                "apps": appsPage,
                                "launcher": launcherPage,
                                "capture": capturePage,
                                "history": historyPage,
                                "updates": updatesPage
                            })[settings.section] || null
                        }

                    }

                }

                Component {
                    id: displaysPage

                    DisplaysPage {
                    }

                }

                Component {
                    id: inputPage

                    InputPage {
                    }

                }

                Component {
                    id: languagePage

                    LanguagePage {
                    }

                }

                Component {
                    id: soundPage

                    VolumePage {
                    }

                }

                Component {
                    id: batteryPage

                    BatteryPage {
                    }

                }

                Component {
                    id: powerPage

                    PowerPage {
                    }

                }

                Component {
                    id: lockPage

                    LockPage {
                    }

                }

                Component {
                    id: nightLightPage

                    NightLightPage {
                    }

                }

                Component {
                    id: appearancePage

                    AppearancePage {
                        shellState: settings.shellState
                    }

                }

                Component {
                    id: notificationsPage

                    NotificationsPage {
                    }

                }

                Component {
                    id: islandPage

                    IslandPage {
                    }

                }

                Component {
                    id: appsPage

                    AppsPage {
                    }

                }

                Component {
                    id: launcherPage

                    LauncherPage {
                    }

                }

                Component {
                    id: capturePage

                    CapturePage {
                        fileChooser: settings.fileChooser
                    }

                }

                Component {
                    id: historyPage

                    HistoryPage {
                    }

                }

                Component {
                    id: updatesPage

                    UpdatesPage {
                    }

                }

                KeyboardFocus {
                    id: keyboardFocus

                    anchors.fill: parent
                    page: content
                    home: content
                }

            }

        }

    }

}
