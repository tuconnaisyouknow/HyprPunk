import QtQuick

// What every card that grows out of a pill tells the screen it's drawn on (ScreenShell):
// the bar's cards, the control center, the island's panels, notifications and AirPods
// card. The screen hides the pill under the card, cuts the card out of the bar, lets the
// pointer through everywhere else, gives the card the keyboard and closes it on a click
// outside. The island's cards also share one shape (IslandFrame).
Item {
    // The pill it grows out of: "workspaces", "monitor", "island" or "control".
    property string pillName: ""
    // Open, or opening: asked for, by you or by what it shows.
    property bool opened: false
    // Where it stands once open, in the screen's coordinates: what it would cover there
    // folds back before it grows (ScreenShell).
    property rect openRect: Qt.rect(0, 0, 0, 0)
    // The cards it was opened over, folding back to make room for it.
    property var coveredCards: []
    // Opened, but still waiting for them to be gone.
    readonly property bool waitingForRoom: coveredCards.some((card) => {
        return card.covering;
    })
    // Opened and in sight: what the card draws its unfolding from, and the island's shape
    // (IslandFrame) heads to.
    readonly property bool showing: opened && !waitingForRoom
    // Drawn over its pill, from the moment it opens until folded back onto it.
    property bool covering: false
    // An island card that carries the music's cover and equalizer out of the island and
    // back (the player), drawn in their place meanwhile.
    property bool carriesMusic: false
    // An island card that carries some of the island's icons out to their places in it and
    // back, by name (the control center: "network", "caffeine", "volume"), their places in
    // the island kept empty meanwhile.
    property var carriedIcons: []
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

    // Given the keyboard back once a card it was lent to closes (a file chooser opened
    // from it): to where its keys were.
    function takeKeyboard() {
        forceActiveFocus();
    }

    function close() {
    }

}
