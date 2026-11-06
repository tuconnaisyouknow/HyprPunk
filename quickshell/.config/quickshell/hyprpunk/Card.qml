import QtQuick

// What every card that grows out of a pill tells the screen it's drawn on (ScreenShell):
// the bar's cards, the control center, the island's panels, notifications and AirPods
// card. The screen hides the pill under the card, cuts the card out of the bar, lets the
// pointer through everywhere else, gives the card the keyboard and closes it on a click
// outside. The island's cards also share one shape (IslandFrame).
Item {
    // The pill it grows out of: "workspaces", "monitor", "island", "player" or "control".
    property string pillName: ""
    // Open, or opening: the island's shape (IslandFrame) heads to this card's.
    property bool opened: false
    // Drawn over its pill, from the moment it opens until folded back onto it.
    property bool covering: false
    // Its size and corners once open.
    property real cardWidth: 0
    property real cardHeight: 0
    property real openRadius: 0
    // The card's shape, in the screen's coordinates.
    property rect cardRect: Qt.rect(0, 0, 0, 0)
    property real cardRadius: 0
    // Where it takes the pointer: the card itself, unless it needs more room.
    property rect inputRect: covering ? cardRect : Qt.rect(0, 0, 0, 0)
    // It answers the keyboard: its screen's window takes it once you click in the card,
    // or right away when the card closes on a click outside (see ScreenShell).
    property bool takesKeyboard: false
    // A click outside closes it, through clickedOutside().
    property bool dismissable: false
    // Stays open when a window goes fullscreen over its screen, hidden until it's back:
    // a prompt an app is waiting on. The other cards fold back (close()).
    property bool keptUnderFullscreen: false

    function clickedOutside() {
    }

    function close() {
    }

}
