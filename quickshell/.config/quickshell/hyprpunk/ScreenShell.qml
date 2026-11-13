import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Everything the shell shows on one screen, in a single window: the bar and every card
// that grows out of its pills (Card). A card and its pill drawn in the same window change
// in the same frame, so a pill never blinks as its card opens or folds back: as windows
// of their own, the compositor could show both for a frame, or neither.
// The window covers the screen but only takes the pointer on the bar and the open cards.
// It stays under fullscreen windows, like the bar always did.
Scope {
    id: shell

    required property var screen
    required property var shellState
    required property var notificationServer
    required property var notificationHistory
    required property var polkitAgent
    required property var fileChooser
    required property var screenShare
    required property var airPods
    readonly property alias bar: bar
    // A window is fullscreen on the screen, over the shell's window (which stays in the
    // layer under fullscreen windows, like the bar always did): nothing of the shell may
    // take the keyboard or the pointer there meanwhile. Maximized windows don't count,
    // they leave the bar its room.
    readonly property bool fullscreen: {
        const monitor = Hyprland.monitorFor(screen);
        const workspace = monitor !== null ? monitor.activeWorkspace : null;
        return workspace !== null && workspace.toplevels.values.some((toplevel) => {
            return toplevel.wayland !== null && toplevel.wayland.fullscreen;
        });
    }

    onFullscreenChanged: {
        const others = shellState.fullscreenScreens.filter((name) => {
            return name !== screen.name;
        });
        shellState.fullscreenScreens = fullscreen ? others.concat([screen.name]) : others;
        if (!fullscreen)
            return ;

        for (const card of window.cards) {
            if (!card.keptUnderFullscreen)
                card.close();

        }
    }

    // Keeps the bar's room at the top free of windows, which the shell's own window
    // can't do while it covers the whole screen.
    PanelWindow {
        screen: shell.screen
        implicitHeight: 1
        exclusiveZone: 50
        color: "transparent"
        WlrLayershell.namespace: "hyprpunk-exclusion"

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

    }

    PanelWindow {
        id: window

        readonly property var cards: bar.ownCards.concat([controlCenter, sessionMenu, wallpaperPicker, themePicker, appLauncher, clipboardPanel, emojiPanel, keybindingsPanel, configPanel, mainMenu, screenshotMenu, polkitPrompt, fileChooserPanel, screenSharePanel, notifications, airPodsCard, islandFrame])
        readonly property bool cardOut: cards.some((card) => {
            return card.covering;
        })

        screen: shell.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyprpunk-shell"
        // On demand rather than exclusive: the focus grab already hands it the keyboard
        // while a card that closes on a click outside is open, and with both, Hyprland
        // held back the window's frames (a card took seconds to open).
        WlrLayershell.keyboardFocus: !shell.fullscreen && cards.some((card) => {
            return card.takesKeyboard;
        }) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Bar {
            id: bar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            screen: shell.screen
            shellState: shell.shellState
            notificationServer: shell.notificationServer
            notificationHistory: shell.notificationHistory
            cardLayer: cardLayer
            islandFrame: islandFrame
            cards: window.cards

            // A click on the bar, outside the cards, closes those that close on a click
            // outside, as a click anywhere else does (focusGrab). The pill still gets it.
            // A tap rather than a point handler, which also takes the hover and kept the
            // pills from opening their cards under the pointer.
            TapHandler {
                onPressedChanged: {
                    if (pressed)
                        window.clickedOutside();

                }
            }

        }

        // While a card is open, the bar is drawn cut out under it: the compositor's blur
        // only softens what's behind the window, so the card's glass would let the pills
        // under it show through sharp.
        ShaderEffectSource {
            id: barImage

            sourceItem: bar
            hideSource: window.cardOut
            live: window.cardOut
            visible: false
        }

        MultiEffect {
            anchors.fill: bar
            visible: window.cardOut
            source: barImage
            maskEnabled: true
            maskInverted: true
            maskSource: shapesImage
            // The cards' rounded corners stay smooth.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        // The open cards' shapes over the bar, for the cut-out. Taken live like the bar:
        // a layer isn't redrawn when the shapes in it change.
        ShaderEffectSource {
            id: shapesImage

            sourceItem: cardShapes
            hideSource: true
            live: window.cardOut
            visible: false
        }

        Item {
            id: cardShapes

            width: bar.width
            height: bar.height

            Repeater {
                model: window.cards

                Rectangle {
                    required property var modelData

                    visible: modelData.covering
                    x: modelData.cardRect.x
                    y: modelData.cardRect.y
                    width: modelData.cardRect.width
                    height: modelData.cardRect.height
                    radius: modelData.cardRadius
                }

            }

        }

        Item {
            id: cardLayer

            anchors.fill: parent

            IslandFrame {
                id: islandFrame

                bar: bar
                cards: window.cards.filter((card) => {
                    return card.pillName === "island" && card !== islandFrame;
                })
            }

            ControlCenter {
                id: controlCenter

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                airPods: shell.airPods
            }

            SessionMenu {
                id: sessionMenu

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            WallpaperPicker {
                id: wallpaperPicker

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            ThemePicker {
                id: themePicker

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            AppLauncher {
                id: appLauncher

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            ClipboardPanel {
                id: clipboardPanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            EmojiPanel {
                id: emojiPanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            KeybindingsPanel {
                id: keybindingsPanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            ConfigPanel {
                id: configPanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            MainMenu {
                id: mainMenu

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            ScreenshotMenu {
                id: screenshotMenu

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
            }

            PolkitPrompt {
                id: polkitPrompt

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
                agent: shell.polkitAgent
            }

            FileChooserPanel {
                id: fileChooserPanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
                chooser: shell.fileChooser
            }

            ScreenSharePanel {
                id: screenSharePanel

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
                share: shell.screenShare
            }

            IslandNotifications {
                id: notifications

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
                notificationServer: shell.notificationServer
            }

            AirPodsPopup {
                id: airPodsCard

                screen: shell.screen
                shellState: shell.shellState
                bar: bar
                islandFrame: islandFrame
                airPods: shell.airPods
            }

        }

        // A click anywhere outside the window closes the cards that close on a click
        // outside: the compositor tells, as long as one of them is open.
        HyprlandFocusGrab {
            windows: [window]
            active: !shell.fullscreen && window.cards.some((card) => {
                return card.dismissable;
            })
            onCleared: window.clickedOutside()
        }

        // The pointer goes through everywhere but the bar and the open cards.
        mask: shell.fullscreen ? noInput : input

        Region {
            id: input

            width: bar.width
            height: bar.height
            regions: cardRegions.instances
        }

        Region {
            id: noInput
        }

        Variants {
            id: cardRegions

            model: window.cards

            Region {
                required property var modelData

                x: modelData.inputRect.x
                y: modelData.inputRect.y
                width: modelData.inputRect.width
                height: modelData.inputRect.height
            }

        }

        function clickedOutside() {
            for (const card of cards) {
                if (card.dismissable)
                    card.clickedOutside();

            }
        }

    }

}
