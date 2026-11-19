import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.modules.island
import qs.theme
import qs.services
import qs.state
import qs.windows

// The notifications that pop up (Popups), in a card that grows out of the dynamic island.
// The stack is in one island at a time, and its card is out while you're on that screen:
// go to another and this one folds back into its island, then the other grows out of its
// own, around the same popups. It claims the island like a card that comes on
// its own (ScreenState), so it waits while a panel or a prompt holds it.
Card {
    id: popups

    required property var screen
    // Its screen's bar, whose island it grows out of.
    required property var bar
    // The island's card shape, shared with its other cards.
    required property Item islandFrame
    readonly property rect contentRect: islandFrame.contentRect(popups)
    // The card's margin around the notifications.
    readonly property int cardPadding: Metrics.spacing.small
    readonly property var screenState: ShellState.forScreen(screen)
    property real progress: opened ? 1 : 0
    // The card's full height, kept while it folds: shrinking with the last popup's gap,
    // it would flatten into a long empty pill before narrowing.
    property real openHeight: 0
    // Where the island is.
    readonly property var island: bar.islandPill
    // You're on this screen, with something left to show: the card wants the island.
    readonly property bool wanted: screenState !== null && screenState === Popups.screenState && Popups.toShow > 0
    // Holds every popup while you read one of them.
    readonly property alias hovered: cardHover.hovered

    anchors.fill: parent
    opened: wanted && screenState.islandOwner === "popups"
    cardWidth: 400
    cardHeight: openHeight
    openRadius: Metrics.cardRadius
    // Gone while they wait, or the folded card would catch the island's clicks.
    visible: opened || progress > 0
    pillName: "island"
    covering: visible
    cardRect: Qt.rect(card.x, card.y, card.width, card.height)
    cardRadius: card.radius

    // Gives the island back once nothing is left, or you're on another screen.
    onWantedChanged: {
        if (wanted)
            screenState.claim("popups", 3);
        else
            screenState?.release("popups");
    }
    Component.onCompleted: Popups.register(popups)
    Component.onDestruction: {
        Popups.unregister(popups);
        screenState?.release("popups");
    }

    // The last popup's gap below it is the card's bottom padding.
    Binding {
        target: popups
        property: "openHeight"
        value: column.height + popups.cardPadding
        when: popups.opened
        restoreMode: Binding.RestoreNone
    }

    ClippingRectangle {
        id: card

        // Drawn in the island's shape (IslandFrame), shared with its other cards.
        x: popups.contentRect.x
        y: popups.contentRect.y
        width: popups.contentRect.width
        height: popups.contentRect.height
        radius: popups.islandFrame.shape.radius
        color: "transparent"

        HoverHandler {
            id: cardHover
        }

        // Laid out at full size, only uncovered while the card grows. It stays put on
        // screen rather than following the card's own rounding.
        Column {
            id: column

            x: Math.round(popups.width / 2 + popups.island.centerOffset - popups.cardWidth / 2) - card.x + popups.cardPadding
            y: popups.cardPadding
            width: popups.cardWidth - 2 * popups.cardPadding
            opacity: popups.opened ? 1 : 0

            Repeater {
                model: ScriptModel {
                    // Only where the stack is: drawn on every screen, each popup would
                    // be built and moved once per screen.
                    values: popups.screenState === Popups.home ? Popups.entries : []
                }

                delegate: Item {
                    id: popup

                    // Its place in the stack (PopupEntry), which moves it in every card.
                    required property var modelData

                    width: column.width
                    height: (notificationCard.implicitHeight + popups.cardPadding) * modelData.slot
                    opacity: modelData.opacity

                    NotificationCard {
                        id: notificationCard

                        width: parent.width
                        // Inside the card's padding, its corners parallel to the card's.
                        radius: Metrics.inner(Metrics.cardRadius, popups.cardPadding)
                        notification: popup.modelData.notification
                    }

                }

            }

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

    // The card covers the island, so the privacy and recording dots move to its right,
    // following its edge as it grows.
    PrivacyDot {
        x: Math.round(card.x + card.width + Metrics.spacing.normal)
        y: Math.round(popups.island.top + popups.island.height / 2 - height / 2)
        camera: Privacy.cameraInUse
        microphone: Privacy.microphoneInUse
        recording: Screenshot.recording
        opacity: active ? popups.progress : 0
        visible: opacity > 0
    }

    Behavior on progress {
        Anim {
            token: Motion.resize.large
        }

    }

}
