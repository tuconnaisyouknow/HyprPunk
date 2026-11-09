import QtQuick

// The little bounce of a card's shape as it finishes growing: it goes a few pixels past
// its size along the sides it grows, then settles back. The same pixels for every card,
// whatever its size, and only the shape: the content is already at its full size. Played
// as a card opens, or takes the island from a smaller one; never as a shape shrinks.
SequentialAnimation {
    id: settle

    // How far past its size the shape is: 0 at rest.
    property real amount: 0
    // The sides it grows along.
    property bool wider: false
    property bool taller: false
    readonly property real width: wider ? amount : 0
    readonly property real height: taller ? amount : 0

    // Bounces along the sides that grow, if any.
    function play(growsWider, growsTaller) {
        if (!growsWider && !growsTaller)
            return ;

        wider = growsWider;
        taller = growsTaller;
        restart();
    }

    // Peaks as the card reaches its size (Theme.cardFold).
    PauseAnimation {
        duration: 110
    }

    NumberAnimation {
        target: settle
        property: "amount"
        to: Theme.cardSettle
        duration: 150
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        target: settle
        property: "amount"
        to: 0
        duration: 320
        easing.type: Easing.InOutQuad
    }

}
