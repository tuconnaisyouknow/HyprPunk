import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.state
import qs.theme
import qs.windows

// The control center, growing out of the bar's right-most pill, or out of the island when
// it's alone in the bar: one of its cards then, in its shape (IslandFrame), holding the
// island like a panel. Out of the open island, it carries the network, caffeine and volume
// icons there to their tiles, and back as it folds. Click the pill, the island's icons, or
// press Super+C; Escape, a click outside or Super+C closes it, the pill being under it.
// The keys move through the controls (KeyboardFocus): Enter or Space clicks the one you're
// on, Shift+Enter its small second button (a tile's icon, a row's details), Backspace or
// Escape goes back a page. The main page is a grid the arrows move around; on the other
// pages, where you only go up and down, right clicks and left goes back.
// The pages and how you go through them are the PageStack's.
Card {
    id: controlCenter

    required property var screen
    // Its screen's bar, whose control pill or island it grows out of.
    required property var bar
    // The island's card shape, which it's drawn in when the island is alone.
    required property Item islandFrame
    readonly property bool inIsland: bar.islandOnly
    readonly property rect frameContent: islandFrame.contentRect(controlCenter)
    // The pages are built once the bar has its first values, or right away if you open
    // the panel before. Kept from then on.
    property bool pagesWanted: false
    readonly property int padding: Metrics.spacing.large
    readonly property int pageWidth: 424
    readonly property int panelWidth: pageWidth + 2 * padding
    // The panel's tallest: a page taller than that scrolls.
    readonly property int panelMaxHeight: 680
    // Where that pill is.
    readonly property var pill: bar.controlPill
    readonly property Item stack: pagesLoader.item
    readonly property Item mainPage: stack !== null ? stack.pages["main"] ?? null : null
    // How far the carried icons have gone, settled before the shape bounces.
    readonly property real flight: Math.max(0, Math.min(1, unfold.heightProgress / 0.8))
    readonly property var flights: [networkFlight, caffeineFlight, volumeFlight]

    // Which of the open island's icons it carries, noted as it opens and as it closes: those
    // shown there and on the main page alike. None on another page, where they aren't, or
    // when the island isn't open, or won't stay open as it folds back (you've left it).
    function noteCarried() {
        const status = bar.islandItem.controlStatus;
        const islandOpen = opened ? bar.islandItem.open : bar.islandItem.pointed;
        const carries = inIsland && islandOpen && mainPage !== null && stack.current === "main";
        carriedIcons = !carries ? [] : flights.filter((flight) => {
            const from = status.icons[flight.name];
            const to = mainPage.icons[flight.name];
            return from.visible && from.text === to.text;
        }).map((flight) => {
            return flight.name;
        });
        for (const flight of flights) {
            flight.from = status.icons[flight.name] ?? null;
            flight.to = mainPage !== null ? mainPage.icons[flight.name] : null;
            if (carriedIcons.includes(flight.name))
                flight.measure();

        }
    }

    function close() {
        opened = false;
    }

    // In the island, it takes it from the card there, and doesn't open while a prompt
    // holds it.
    function open() {
        if (inIsland && !bar.screenState.claim("controlcenter", 2))
            return ;

        opened = true;
    }

    // Keys no control kept for itself (a field its letters, a slider its arrows).
    function keyPressed(event) {
        if (stack === null)
            return ;

        const direction = Navigation.direction(event);
        // In a page's list, a control alone on its line takes right as OK and left as
        // back; one in a row (hours, choices) moves along it. The main page is a grid.
        const sideways = stack.current !== "main" && direction !== null && direction[0] !== 0 && !keyboardFocus.inRow();
        if (event.key === Qt.Key_Escape || Navigation.backs(event) || (sideways && direction[0] < 0))
            stack.back();
        else if (Navigation.accepts(event))
            activate((event.modifiers & Qt.ShiftModifier) !== 0);
        else if (sideways && direction[0] > 0 && keyboardFocus.current !== null)
            activate(false);
        else if (direction !== null)
            keyboardFocus.move(direction[0], direction[1]);
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
            keyboardFocus.step(event.key === Qt.Key_Tab ? 1 : -1);
        else
            return ;
        event.accepted = true;
    }

    // The keys' click: the page it opens is entered through the control you're on.
    function activate(alternative) {
        if (keyboardFocus.current !== null)
            stack.pointAt(keyboardFocus.current);

        keyboardFocus.activate(alternative);
    }

    function clickedOutside() {
        close();
    }

    // Back on the control you were on, or the panel if you'd only clicked.
    function takeKeyboard() {
        keyboardFocus.settle();
    }

    // Its shortcut, through its screen's state.
    function requestAction(action) {
        if (action === "open" || action === "toggle" && !opened)
            open();
        else
            close();
    }

    onOpenedChanged: {
        noteCarried();
        if (opened) {
            pagesWanted = true;
            keyboardFocus.forget();
            panel.forceActiveFocus();
        } else {
            bar.screenState.release("controlcenter");
        }
    }
    // It folds back on the page you were on, and only then goes back to the main one.
    onCoveringChanged: {
        if (!covering && stack !== null)
            stack.reset();

    }
    anchors.fill: parent
    pillName: inIsland ? "island" : "control"
    covering: unfold.out
    openRect: inIsland ? islandFrame.openRect(controlCenter) : Qt.rect(width - pill.right - panelWidth, pill.top, panelWidth, panelMaxHeight)
    cardRect: inIsland ? Qt.rect(panelSpot.x + panel.x, panelSpot.y + panel.y, panel.width, panel.height) : Qt.rect(panelSpot.x + glass.x, panelSpot.y + glass.y, glass.width, glass.height)
    cardRadius: panel.radius
    // Its size in the island's shape, which follows it as a page changes height.
    cardWidth: panelWidth
    cardHeight: panel.fullHeight
    // The island's corners: rounder ones would let the island's show under the card.
    openRadius: bar.islandPill.radius
    takesKeyboard: opened
    dismissable: opened
    Component.onCompleted: ShellState.forScreen(screen)?.register("controlcenter", controlCenter)
    Component.onDestruction: ShellState.forScreen(screen)?.unregister("controlcenter", controlCenter)

    // Pinned to the pill's top right corner, where the panel grows from. In the island,
    // where the island's shape shows it.
    Item {
        id: panelSpot

        x: controlCenter.inIsland ? controlCenter.frameContent.x : controlCenter.width - controlCenter.pill.right - width
        y: controlCenter.inIsland ? controlCenter.frameContent.y : controlCenter.pill.top
        width: panel.width
        height: panel.height

        // The panel's glass, alone so it moves freely between two pixels: on whole ones
        // its edges stepped, a few times a second as the bounce slows down.
        Item {
            id: glass

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -unfold.lerp(controlCenter.pill.spreadY, 0, unfold.heightProgress)
            anchors.rightMargin: -unfold.lerp(controlCenter.pill.spreadX, 0, unfold.widthProgress)
            // The island's shape draws its own.
            visible: panel.visible && !controlCenter.inIsland
            width: panel.shapeWidth
            height: panel.shapeHeight

            // Same look as the pill it grows from, so it feels like the pill itself is
            // growing: lit under the pointer as it folds back onto the pill that is.
            GlassSurface {
                radius: panel.radius
                tinted: false
                hovered: !controlCenter.showing && controlCenter.pill.lit
                backgroundColor: Colors.panel
            }

        }

        // Grows out of the pill like the calendar and the player do: the pages' place in
        // the glass.
        ClippingRectangle {
            id: panel

            property real fullHeight: (controlCenter.stack !== null ? controlCenter.stack.implicitHeight : 0) + 2 * controlCenter.padding
            // Off until the pages are built, so the panel starts at its real height instead
            // of growing from an empty one.
            property bool heightAnimated: false

            // It grows from the pill as you see it, zoomed past its place, to its own place:
            // how far its shape still starts past that place. The pages and the pill's spot
            // stay on that place, still while the shape heads to it.
            readonly property int startX: Math.round(unfold.lerp(controlCenter.pill.spreadX, 0, unfold.widthProgress))
            readonly property int startY: Math.round(unfold.lerp(controlCenter.pill.spreadY, 0, unfold.heightProgress))
            // The glass's size as it unfolds and bounces, between two pixels too.
            readonly property real shapeWidth: unfold.lerp(controlCenter.pill.width + 2 * controlCenter.pill.spreadX, controlCenter.panelWidth, unfold.widthProgress)
            readonly property real shapeHeight: unfold.lerp(controlCenter.pill.height + 2 * controlCenter.pill.spreadY, fullHeight, unfold.heightProgress)

            anchors.top: parent.top
            anchors.right: parent.right
            // On whole pixels, its size too, or the pages would shake as it grows and bounces
            // (they're drawn as a picture of its size). In the island, its content's place in
            // the island's shape, already on whole pixels.
            anchors.topMargin: controlCenter.inIsland ? 0 : -startY
            anchors.rightMargin: controlCenter.inIsland ? 0 : -startX
            visible: controlCenter.covering
            width: controlCenter.inIsland ? controlCenter.frameContent.width : Math.round(shapeWidth)
            height: controlCenter.inIsland ? controlCenter.frameContent.height : Math.round(shapeHeight)
            // The pill's corners: rounder ones would let the pill's show under the panel.
            radius: controlCenter.inIsland ? controlCenter.islandFrame.shape.radius : controlCenter.pill.height / 2
            color: "transparent"
            focus: true
            Keys.onPressed: (event) => {
                return controlCenter.keyPressed(event);
            }

            // A click on the panel stays in it, away from the bar and the pill under it.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
            }

            // Where the pill sits under the panel: the pointer there keeps the pill lit, so
            // the panel folds back onto it as you'll see it. Open, the panel is all there
            // is: the pill doesn't answer, and a click there stays in the panel. The island's
            // shape carries the island's content itself.
            Item {
                visible: !controlCenter.inIsland
                anchors.right: parent.right
                anchors.rightMargin: panel.startX
                y: panel.startY
                width: controlCenter.pill.width
                height: controlCenter.pill.height

                HoverHandler {
                    id: spotHover
                }

                Binding {
                    target: controlCenter.bar
                    property: "controlSpotHovered"
                    value: spotHover.hovered
                }

                PillContent {
                    pill: controlCenter.bar.controlItem
                    active: controlCenter.covering
                    share: 1 - unfold.contentProgress
                }

            }

            // Built bit by bit soon after the shell starts and kept, so the panel opens as
            // fast as the bar's cards, with Super+C too. Finished at once if opened before.
            Loader {
                id: pagesLoader

                active: controlCenter.pagesWanted
                // On the pill's side, or in the island still on screen around its middle
                // while the shape grows around them, like the island's panels.
                x: controlCenter.inIsland ? Math.round(controlCenter.width / 2 + controlCenter.bar.islandPill.centerOffset - controlCenter.panelWidth / 2) - panelSpot.x + controlCenter.padding : panel.width - controlCenter.padding - panel.startX - width
                anchors.top: parent.top
                anchors.topMargin: controlCenter.padding + (controlCenter.inIsland ? 0 : panel.startY)
                // The pages take this width, and give the Loader their height.
                width: controlCenter.pageWidth
                asynchronous: !controlCenter.opened
                onStatusChanged: panel.heightAnimated = status === Loader.Ready

                // Laid out at full size, only uncovered while the panel grows. Each page
                // opens the ones it leads to, with their subject.
                sourceComponent: PageStack {
                    // Starts hidden even when built with the panel already opening (Super+C),
                    // so the pages still fade in, as the pill's content fades out (Unfold).
                    property bool built: false

                    opened: controlCenter.opened
                    maxHeight: controlCenter.panelMaxHeight - 2 * controlCenter.padding
                    padding: controlCenter.padding
                    radius: panel.radius
                    opacity: built && controlCenter.showing ? 1 : 0
                    Component.onCompleted: built = true
                    onCloseRequested: controlCenter.close()
                    onCurrentChanged: Qt.callLater(keyboardFocus.settle)

                    MainPage {
                        onTrayRequested: (item) => {
                            return trayPage.show(item);
                        }
                    }

                    WifiPage {
                        id: wifiPage

                        onHiddenRequested: hiddenPage.show()
                        onDetailsRequested: (network) => {
                            return wifiDetailPage.show(network);
                        }
                        onEnterpriseRequested: (network) => {
                            return enterprisePage.ask(network);
                        }
                        onVpnDetailsRequested: (uuid) => {
                            return vpnDetailPage.show(uuid);
                        }
                    }

                    VpnDetailPage {
                        id: vpnDetailPage
                    }

                    BluetoothPage {
                        onDetailsRequested: (device) => {
                            return bluetoothDetailPage.show(device);
                        }
                    }

                    EnterpriseWifiPage {
                        id: enterprisePage
                    }

                    HiddenWifiPage {
                        id: hiddenPage

                        onEnterpriseRequested: (network) => {
                            return enterprisePage.ask(network);
                        }
                    }

                    WifiDetailPage {
                        id: wifiDetailPage

                        onConnectRequested: wifiPage.select(network)
                        onModifyRequested: enterprisePage.edit(network)
                    }

                    BluetoothDetailPage {
                        id: bluetoothDetailPage
                    }

                    SoundPage {
                        onBluetoothDetailsRequested: (device) => {
                            return bluetoothDetailPage.show(device);
                        }
                    }

                    CaffeinePage {
                    }

                    NightLightPage {
                    }

                    TrayPage {
                        id: trayPage
                    }

                    Behavior on opacity {
                        Anim {
                            token: Motion.unfold.content
                        }

                    }

                }

            }

            // Over the pages, for its ring.
            KeyboardFocus {
                id: keyboardFocus

                anchors.fill: parent
                page: controlCenter.stack !== null ? controlCenter.stack.currentPage : null
                home: panel
            }

            // A page changing height. Between two pages the stack sets the pace itself, and
            // a page moving its own height sets it too. Folded away, it takes the main
            // page's at once, ready for the next opening.
            Behavior on fullHeight {
                enabled: panel.heightAnimated && controlCenter.covering && controlCenter.stack.progress === 1 && !controlCenter.stack.currentPage?.resizing

                Anim {
                    token: Motion.resize.normal
                }

            }

        }

    }

    // Building them takes the shell's time bit by bit, which delayed the bar's values
    // when it began at startup.
    Timer {
        interval: 1500
        running: true
        onTriggered: controlCenter.pagesWanted = true
    }

    // The carried icons, over everything until they land.
    component CarriedIcon: IconFlight {
        required property string name

        z: 1
        progress: controlCenter.flight
        bounds: controlCenter.islandFrame.steadyShape
        visible: controlCenter.covering && controlCenter.flight < 1 && controlCenter.carriedIcons.includes(name)
    }

    CarriedIcon {
        id: networkFlight

        name: "network"
    }

    CarriedIcon {
        id: caffeineFlight

        name: "caffeine"
    }

    CarriedIcon {
        id: volumeFlight

        name: "volume"
    }

    // Their places on the main page stay empty until they land.
    Binding {
        target: controlCenter.mainPage
        property: "lifted"
        value: controlCenter.covering && controlCenter.flight < 1 ? controlCenter.carriedIcons : []
        when: controlCenter.mainPage !== null
    }

    Unfold {
        id: unfold

        open: controlCenter.showing
    }

    // In the island, something else takes it (a panel, a prompt): it folds back.
    Connections {
        function onIslandOwnerChanged() {
            if (controlCenter.opened && controlCenter.bar.screenState.islandOwner !== "controlcenter")
                controlCenter.close();

        }

        target: controlCenter.bar.screenState
        enabled: controlCenter.inIsland
    }

}
