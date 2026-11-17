import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.state
import qs.theme

// The settings, in a window of their own that floats in the middle of the screen you're
// on (rules.lua): a section per subject on the left, its page on the right. Super+I
// closes it when it's the window you're on, and brings it to you from anywhere else.
// The keys move through the controls (KeyboardFocus), Escape closes it.
// The window only exists while it's open: one closed by Hyprland (Super+Q) can't be
// shown again, so every way of closing it unloads it, and opening builds a new one.
Scope {
    id: settings

    // In the sidebar's order, each with the file of its page.
    readonly property var sections: [{
        "name": "displays",
        "page": "DisplaysPage.qml",
        "icon": "󰍹",
        "label": "Displays"
    }, {
        "name": "input",
        "page": "InputPage.qml",
        "icon": "󰍽",
        "label": "Mouse and touchpad"
    }, {
        "name": "language",
        "page": "LanguagePage.qml",
        "icon": "󰌌",
        "label": "Keyboard and language"
    }, {
        "name": "sound",
        "page": "VolumePage.qml",
        "icon": "󰕾",
        "label": "Sound"
    }, {
        "name": "battery",
        "page": "BatteryPage.qml",
        "icon": "󰁹",
        "label": "Battery and power"
    }, {
        "name": "power",
        "page": "PowerPage.qml",
        "icon": "󰒲",
        "label": "Idle and sleep"
    }, {
        "name": "lock",
        "page": "LockPage.qml",
        "icon": "󰌾",
        "label": "Lock screen"
    }, {
        "name": "nightlight",
        "page": "NightLightPage.qml",
        "icon": "󰖔",
        "label": "Night light"
    }, {
        "name": "appearance",
        "page": "AppearancePage.qml",
        "icon": "󰏘",
        "label": "Appearance"
    }, {
        "name": "notifications",
        "page": "NotificationsPage.qml",
        "icon": "󰂚",
        "label": "Notifications"
    }, {
        "name": "island",
        "page": "IslandPage.qml",
        "icon": "󰍡",
        "label": "Island"
    }, {
        "name": "apps",
        "page": "AppsPage.qml",
        "icon": "󰀻",
        "label": "Default apps"
    }, {
        "name": "launcher",
        "page": "LauncherPage.qml",
        "icon": "󱓞",
        "label": "Launcher"
    }, {
        "name": "capture",
        "page": "CapturePage.qml",
        "icon": "󰹑",
        "label": "Screenshots"
    }, {
        "name": "history",
        "page": "HistoryPage.qml",
        "icon": "󰅌",
        "label": "Clipboard and history"
    }, {
        "name": "updates",
        "page": "UpdatesPage.qml",
        "icon": "󰚰",
        "label": "Updates"
    }]
    // Kept between openings.
    property string section: "displays"
    readonly property var current: sections.find((item) => {
        return item.name === section;
    })

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

    // Asked for like a panel, as "settings" (ScreenState.request).
    function requestAction(action) {
        if (action === "toggle")
            toggle();
        else if (action === "open")
            open();
        else
            close();
    }

    Component.onCompleted: ShellState.register("settings", settings)

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
            color: Colors.base
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
                    anchors.margins: Metrics.spacing.section
                    spacing: Metrics.spacing.section

                    // Its rows fill it, which would make it share the width with the page.
                    ColumnLayout {
                        Layout.preferredWidth: 250
                        Layout.fillWidth: false
                        Layout.fillHeight: true
                        spacing: Metrics.spacing.small

                        Text {
                            Layout.leftMargin: Metrics.spacing.normal
                            Layout.bottomMargin: Metrics.spacing.large
                            text: "Settings"
                            color: Colors.primary
                            font.family: Metrics.font
                            font.pixelSize: Metrics.text.heading
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
                                readonly property real radius: Metrics.radius.normal

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
                                    backgroundColor: tab.chosen ? Colors.alpha(Colors.primary, 0.85) : "transparent"
                                    opacity: tab.chosen || tabHover.hovered ? 1 : 0

                                    Behavior on opacity {
                                        Anim {
                                            token: Motion.color.small
                                        }

                                    }

                                }

                                RowLayout {
                                    id: tabContent

                                    anchors.fill: parent
                                    anchors.leftMargin: Metrics.spacing.large
                                    anchors.rightMargin: Metrics.spacing.large
                                    spacing: Metrics.spacing.large

                                    Text {
                                        Layout.preferredWidth: 24
                                        horizontalAlignment: Text.AlignHCenter
                                        text: tab.modelData.icon
                                        color: tab.chosen ? Colors.base : Colors.secondary
                                        font.family: Metrics.font
                                        font.pixelSize: Metrics.text.title
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: tab.modelData.label
                                        color: tab.chosen ? Colors.base : Colors.secondary
                                        elide: Text.ElideRight
                                        font.family: Metrics.font
                                        font.pixelSize: Metrics.text.emphasis
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
                            source: settings.current.page
                        }

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
