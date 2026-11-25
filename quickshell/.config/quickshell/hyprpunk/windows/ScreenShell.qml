import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.modules.airpods
import qs.modules.bar
import qs.modules.capture
import qs.modules.controlcenter
import qs.modules.island
import qs.modules.notifications
import qs.state
import qs.services
import qs.theme

// Everything the shell shows on one screen, in a single window: the bar and every card
// that grows out of its pills (Card). A card and its pill drawn in the same window change
// in the same frame, so a pill never blinks as its card opens or folds back: as windows
// of their own, the compositor could show both for a frame, or neither.
// The bar's strip is kept free by Hyprland (monitors.lua), not by a window of its own.
// The window covers the screen but only takes the pointer on the bar and the open cards.
// It stays under fullscreen windows, like the bar always did.
// A second window, of the bar's size, draws nothing: it asks for the blur behind the pills.
Scope {
    id: shell

    required property var screen
    readonly property alias bar: bar
    readonly property var screenState: ShellState.forScreen(screen)
    // A window is fullscreen over the shell's window: nothing of the shell may take the
    // keyboard or the pointer there meanwhile.
    readonly property bool fullscreen: screenState !== null && screenState.fullscreen
    // Something takes the screen over, a fullscreen window or the lock: the cards fold
    // back, but the prompts an app waits on. Before the lock, so it starts from the bar
    // alone with the island at rest (Lock.engage).
    readonly property bool takenOver: fullscreen || Lock.covering

    onTakenOverChanged: {
        if (!takenOver)
            return ;

        for (const card of window.cards) {
            if (!card.keptUnderFullscreen)
                card.close();

        }
    }

    // The blur behind the pills. Hyprland blurs the whole of a window that asks for
    // blur, again at each frame something moves behind it: asked for by the shell's
    // window, every screen was blurred whole all through a new wallpaper's transition,
    // more than the graphics card could draw in time. So a window of the bar's size asks
    // for the pills' blur and draws nothing, under the shell's window, which only asks
    // for its open cards'.
    PanelWindow {
        id: glass

        screen: shell.screen
        color: "transparent"
        implicitHeight: bar.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyprpunk-glass"
        BackgroundEffect.blurRegion: pillBlur

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

        Region {
            id: pillBlur

            regions: pillBlurShapes.instances
        }

        Variants {
            id: pillBlurShapes

            model: shell.screenState !== null ? shell.screenState.blurShapes : []

            Region {
                required property var modelData

                x: modelData.place.x
                y: modelData.place.y
                width: modelData.place.width
                height: modelData.place.height
                radius: modelData.placeRadius
            }

        }

    }

    PanelWindow {
        id: window

        readonly property var cards: bar.ownCards.concat([controlCenter, sessionMenu, wallpaperPicker, themePicker, appLauncher, clipboardPanel, emojiPanel, keybindingsPanel, configPanel, screenshotMenu, polkitPrompt, fileChooserPanel, screenSharePanel, notifications, airPodsCard, islandFrame])
        readonly property bool cardOut: cards.some((card) => {
            return card.covering;
        })

        screen: shell.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hyprpunk-shell"
        // Blur behind the open cards only (the blur window has the pills').
        BackgroundEffect.blurRegion: cardBlur
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
                bar: bar
            }

            SessionMenu {
                id: sessionMenu

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            WallpaperPicker {
                id: wallpaperPicker

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            ThemePicker {
                id: themePicker

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            AppLauncher {
                id: appLauncher

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            ClipboardPanel {
                id: clipboardPanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            EmojiPanel {
                id: emojiPanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            KeybindingsPanel {
                id: keybindingsPanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            ConfigPanel {
                id: configPanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            ScreenshotMenu {
                id: screenshotMenu

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            PolkitPrompt {
                id: polkitPrompt

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            FileChooserPanel {
                id: fileChooserPanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            ScreenSharePanel {
                id: screenSharePanel

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            IslandNotifications {
                id: notifications

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
            }

            AirPodsPopup {
                id: airPodsCard

                screen: shell.screen
                bar: bar
                islandFrame: islandFrame
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

        Variants {
            model: window.cards

            Connections {
                required property var modelData

                function onOpenedChanged() {
                    window.makeRoom(modelData);
                }

                function onTakesKeyboardChanged() {
                    if (!modelData.takesKeyboard)
                        Qt.callLater(window.settleKeyboard);

                }

                target: modelData
            }

        }

        Region {
            id: cardBlur

            regions: cardBlurShapes.instances
        }

        Variants {
            id: cardBlurShapes

            model: window.cards

            Region {
                required property var modelData

                x: modelData.covering ? modelData.cardRect.x : 0
                y: modelData.covering ? modelData.cardRect.y : 0
                width: modelData.covering ? modelData.cardRect.width : 0
                height: modelData.covering ? modelData.cardRect.height : 0
                radius: modelData.cardRadius
            }

        }

        // A card never opens over another: the ones it would cover fold back first, and it
        // grows once they're gone (Card.showing). Every card hangs from the bar, so two
        // meet where their spans across the screen do. The cards of one pill take its
        // place from each other on their own (the island's shape). A prompt an app waits
        // on can't be pushed away: the card doesn't open over it.
        function makeRoom(card) {
            if (!card.opened) {
                card.coveredCards = [];
                return ;
            }
            const room = card.openRect;
            const covered = cards.filter((other) => {
                if (other.pillName === card.pillName || !(other.opened || other.covering))
                    return false;

                const place = other.opened ? other.openRect : other.cardRect;
                return room.x < place.x + place.width && place.x < room.x + room.width;
            });
            if (covered.some((other) => {
                return other.keptUnderFullscreen;
            })) {
                card.close();
                return ;
            }
            for (const other of covered)
                other.close();
            card.coveredCards = covered;
        }

        function clickedOutside() {
            for (const card of cards) {
                if (card.dismissable)
                    card.clickedOutside();

            }
        }

        // The keys always land in a card that takes them: one that closes with them (a
        // file chooser opened from the control center) hands them back to one still open.
        // Once the card that's opening, if any, has taken them first.
        function settleKeyboard() {
            const holders = cards.filter((card) => {
                return card.takesKeyboard;
            });
            const item = bar.Window.activeFocusItem;
            const held = item !== null && holders.some((card) => {
                for (let parent = item; parent !== null; parent = parent.parent) {
                    if (parent === card)
                        return true;

                }
                return false;
            });
            if (!held && holders.length > 0)
                holders[0].takeKeyboard();

        }

    }

}
