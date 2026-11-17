import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.state
import qs.theme
import qs.windows

// The control center, growing out of the bar's right-most pill. Click the pill or
// press Super+C; Escape, a click outside or the pill again closes it.
// The keys move through the controls (KeyboardFocus): Enter or Space clicks the one you're
// on, Shift+Enter its small second button (a tile's icon, a row's details), Backspace or
// Escape goes back a page. The main page is a grid the arrows move around; on the other
// pages, where you only go up and down, right clicks and left goes back.
// The pages and how you go through them are the PageStack's.
Card {
    id: controlCenter

    required property var screen
    // Its screen's bar, whose control pill it grows out of.
    required property var bar
    property real progress: opened ? 1 : 0
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

    function lerp(from, to) {
        return from + (to - from) * progress;
    }

    function close() {
        opened = false;
    }

    // Keys no control kept for itself (a field its letters, a slider its arrows).
    function keyPressed(event) {
        if (stack === null)
            return ;

        const direction = Navigation.direction(event);
        const grid = stack.current === "main";
        if (event.key === Qt.Key_Escape || Navigation.backs(event) || (!grid && direction !== null && direction[0] < 0))
            stack.back();
        else if (Navigation.accepts(event))
            activate((event.modifiers & Qt.ShiftModifier) !== 0);
        else if (!grid && direction !== null && direction[0] > 0 && keyboardFocus.current !== null)
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

    // Its shortcut, through its screen's state.
    function requestAction(action) {
        if (action === "open" || action === "toggle" && !opened)
            opened = true;
        else
            close();
    }

    onOpenedChanged: {
        if (opened) {
            settle.play(true, true);
            pagesWanted = true;
            keyboardFocus.forget();
            panel.forceActiveFocus();
        } else if (stack !== null) {
            stack.reset();
        }
    }
    anchors.fill: parent
    pillName: "control"
    covering: progress > 0
    cardRect: Qt.rect(panelSpot.x + glass.x, panelSpot.y + glass.y, glass.width, glass.height)
    cardRadius: panel.radius
    takesKeyboard: opened
    dismissable: opened
    Component.onCompleted: ShellState.forScreen(screen)?.register("controlcenter", controlCenter)
    Component.onDestruction: ShellState.forScreen(screen)?.unregister("controlcenter", controlCenter)

    // Pinned to the pill's top right corner, where the panel grows from.
    Item {
        id: panelSpot

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: controlCenter.pill.top
        anchors.rightMargin: controlCenter.pill.right
        width: panel.width
        height: panel.height

        // The panel's glass, alone so it moves freely between two pixels: on whole ones
        // its edges stepped, a few times a second as the bounce slows down.
        Item {
            id: glass

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -controlCenter.lerp(controlCenter.pill.spreadY, 0)
            anchors.rightMargin: -controlCenter.lerp(controlCenter.pill.spreadX, 0)
            visible: panel.visible
            width: panel.shapeWidth
            height: panel.shapeHeight

            // Same look as the pill it grows from, so it feels like the pill itself is
            // growing: lit under the pointer as it folds back onto the pill that is.
            GlassSurface {
                radius: panel.radius
                tinted: false
                hovered: !controlCenter.opened && controlCenter.pill.lit
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
            readonly property int startX: Math.round(controlCenter.lerp(controlCenter.pill.spreadX, 0))
            readonly property int startY: Math.round(controlCenter.lerp(controlCenter.pill.spreadY, 0))
            // The glass's size as it grows and bounces, between two pixels too.
            readonly property real shapeWidth: controlCenter.lerp(controlCenter.pill.width + 2 * controlCenter.pill.spreadX, controlCenter.panelWidth) + settle.width
            readonly property real shapeHeight: controlCenter.lerp(controlCenter.pill.height + 2 * controlCenter.pill.spreadY, fullHeight) + settle.height

            anchors.top: parent.top
            anchors.right: parent.right
            // On whole pixels, its size too, or the pages would shake as it grows and bounces
            // (they're drawn as a picture of its size).
            anchors.topMargin: -startY
            anchors.rightMargin: -startX
            visible: controlCenter.progress > 0
            width: Math.round(shapeWidth)
            height: Math.round(shapeHeight)
            // The pill's corners: rounder ones would let the pill's show under the panel.
            radius: controlCenter.pill.height / 2
            color: "transparent"
            focus: true
            Keys.onPressed: (event) => {
                return controlCenter.keyPressed(event);
            }

            // A click on the panel stays in it, away from the bar and the pill under it.
            TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
            }

            // Where the pill sits under the panel: a click there closes it, like on the
            // pill, and the pointer there keeps the pill lit, folding back too. Under the
            // pages, so it only gets the clicks no control keeps (their TapHandlers take the
            // click on press).
            Item {
                anchors.right: parent.right
                anchors.rightMargin: panel.startX
                y: panel.startY
                width: controlCenter.pill.width
                height: controlCenter.pill.height

                HoverHandler {
                    id: spotHover

                    cursorShape: Qt.PointingHandCursor
                }

                Binding {
                    target: controlCenter.bar
                    property: "controlSpotHovered"
                    value: spotHover.hovered
                }

                TapHandler {
                    onTapped: controlCenter.close()
                }

            }

            // Built bit by bit soon after the shell starts and kept, so the panel opens as
            // fast as the bar's cards, with Super+C too. Finished at once if opened before.
            Loader {
                id: pagesLoader

                active: controlCenter.pagesWanted
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: controlCenter.padding + panel.startX
                anchors.topMargin: controlCenter.padding + panel.startY
                // The pages take this width, and give the Loader their height.
                width: controlCenter.pageWidth
                asynchronous: !controlCenter.opened
                onStatusChanged: panel.heightAnimated = status === Loader.Ready

                // Laid out at full size, only uncovered while the panel grows. Each page
                // opens the ones it leads to, with their subject.
                sourceComponent: PageStack {
                    // Starts hidden even when built with the panel already opening (Super+C),
                    // so the pages still fade in.
                    property bool built: false

                    opened: controlCenter.opened
                    maxHeight: controlCenter.panelMaxHeight - 2 * controlCenter.padding
                    padding: controlCenter.padding
                    radius: panel.radius
                    opacity: built && controlCenter.opened ? 1 : 0
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

                        onPasswordSent: panel.forceActiveFocus()
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

                    TrayPage {
                        id: trayPage
                    }

                    Behavior on opacity {
                        Anim {
                            token: Motion.color.small
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

            // A page changing height. Between two pages the stack sets the pace itself.
            Behavior on fullHeight {
                enabled: panel.heightAnimated && controlCenter.stack.progress === 1

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

    CardSettle {
        id: settle
    }

    Behavior on progress {
        Anim {
            token: Motion.resize.large
        }

    }

}
