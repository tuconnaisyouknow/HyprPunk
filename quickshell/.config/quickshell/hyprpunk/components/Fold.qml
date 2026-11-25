import QtQuick
import qs.theme

// What unfolds under the thing that opens it (a drop-down's options, a tray app's menu):
// it opens past its size and back like a card out of its pill (Motion.unfold), folds
// back the same way, and glides when its content changes size while open. Its content
// fades in as it opens and out as it folds, while the height is still on its way.
// Folding, it's leaving: neither the pointer nor the keys can reach it, since what it
// holds stays in place under its clip, where the keys would find it below what follows.
Item {
    id: fold

    property bool open: false
    default property alias content: body.data
    // Its height on its way somewhere.
    readonly property bool moving: motion.running
    // From the moment it opens until it has folded back: what it shows lives until then.
    readonly property bool out: open || visible
    // Opening or folding back, rather than changing size while open.
    property bool unfolding: false
    // The page it sits in, if it's a control center page: it follows the fold's height
    // as it moves instead of easing after it.
    property Item page: null

    implicitHeight: open ? body.childrenRect.height : 0
    clip: true
    visible: implicitHeight > 0
    Component.onCompleted: {
        let item = parent;
        while (item !== null && item.folds === undefined)
            item = item.parent;
        page = item;
        if (page !== null)
            page.folds = page.folds.concat([fold]);

    }
    Component.onDestruction: {
        if (page !== null)
            page.folds = page.folds.filter((other) => {
                return other !== fold;
            });

    }
    onOpenChanged: {
        unfolding = true;
        unfolded.restart();
    }

    Timer {
        id: unfolded

        interval: Motion.unfold.height.duration
        onTriggered: fold.unfolding = false
    }

    Item {
        id: body

        width: parent.width
        height: childrenRect.height
        enabled: fold.open
        opacity: fold.open ? 1 : 0

        Behavior on opacity {
            Anim {
                token: Motion.unfold.content
            }

        }

    }

    Behavior on implicitHeight {
        Anim {
            id: motion

            token: fold.unfolding ? Motion.unfold.height : Motion.unfold.glideHeight
        }

    }

}
