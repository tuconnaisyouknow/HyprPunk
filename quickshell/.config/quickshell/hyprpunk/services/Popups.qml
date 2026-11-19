pragma Singleton

import QtQuick
import Quickshell
import qs.state

// The notifications that pop up (Notifications.arrived): one stack for the whole shell,
// in one island at a time, whose card (IslandNotifications) draws it while you're on its
// screen. Going to another screen changes nothing here: the card folds back into its
// island with the popups in it, and the other screen's only grows out of its own once it
// has, around the same popups. Come back before, and it comes out again from where it
// was. So a single card ever moves, however often you go back and forth: two at once, on
// two screens, cost the compositor more than it can draw in time.
// They leave after the time set in the settings unless hovered or critical, and the stack
// holds three: the ones that arrive while it's full wait their turn, the oldest popup
// leaving for the next one, so each is shown however fast they come.
Singleton {
    id: popups

    readonly property int maxVisible: 3
    // The popups in the stack (PopupEntry), newest first, listed until their exit is over.
    property var entries: []
    // The ones that arrived while the stack was full, oldest first: { id, notification }.
    property var waiting: []
    // Both counted once a change is whole: read between two of its steps, they would go
    // through a count that never was, and the card following them would start over.
    // The popups not on their way out, and the ones still in sight: the room that's taken.
    property int staying: 0
    property int inSight: 0
    // Everything left to show: the card stays out between a popup and the next.
    readonly property int toShow: staying + waiting.length
    // Every screen's card. The popups' time only runs while one is out, and stops while
    // you read one of them.
    property var cards: []
    readonly property bool out: cards.some((card) => {
        return card.opened;
    })
    readonly property bool held: cards.some((card) => {
        return card.hovered;
    })
    // No card is out or still folding.
    readonly property bool folded: !cards.some((card) => {
        return card.visible;
    })
    // The screen you're on, and the one whose island has the popups: it follows you once
    // its card has folded.
    readonly property var focused: ShellState.focused()
    property var home: null
    // The screen whose card is out: the popups', while you're on it.
    readonly property var screenState: home === focused ? home : null
    // The notification center is open where you are: they're all listed there, no need
    // for a popup.
    readonly property bool listed: focused !== null && focused.islandOwner === "notifications"

    function settle() {
        if (folded)
            home = focused;

    }

    function register(card) {
        cards = cards.concat([card]);
    }

    function unregister(card) {
        cards = cards.filter((listed) => {
            return listed !== card;
        });
    }

    function count() {
        staying = entries.filter((entry) => {
            return !entry.leaving;
        }).length;
        inSight = entries.filter((entry) => {
            return !entry.vanished;
        }).length;
    }

    function show(notification) {
        if (listed)
            return ;

        // Read before it queues: the card comes out as soon as something waits.
        const joins = out;
        const id = notification.id;
        waiting = waiting.concat([{
            "id": id,
            "notification": notification
        }]);
        notification.closed.connect(() => {
            popups.waiting = popups.waiting.filter((entry) => {
                return entry.id !== id;
            });
            popups.leave([id]);
        });
        admit(joins);
    }

    // The next ones waiting come in while the stack has room. Listed before it leaves the
    // queue, so the stack never reads as having nothing left to show in between.
    // The ones a card opens with are whole from the start: the island's shape heads
    // straight to their size, where growing with their room too it first stretched into
    // a flat pill and only then took its height.
    function admit(joins) {
        while (waiting.length > 0 && inSight < maxVisible) {
            const next = waiting[0];
            entries = [entryComponent.createObject(popups, {
                "key": next.id,
                "notification": next.notification,
                "slot": joins ? 0 : 1
            })].concat(entries);
            count();
            waiting = waiting.slice(1);
        }
    }

    // Starts their exit: they're dropped once it's over.
    function leave(ids) {
        for (const entry of entries) {
            if (ids.includes(entry.key) && !entry.leaving)
                entry.leave();

        }
        count();
    }

    // Out of sight: its room goes to the next one waiting.
    function vanish(entry) {
        entry.vanished = true;
        count();
        admit(out);
    }

    function drop(entry) {
        entries = entries.filter((listed) => {
            return listed !== entry;
        });
        count();
        entry.destroy();
    }

    // The oldest popup leaves, its room going to the next one waiting.
    function passOn() {
        const staying = entries.filter((entry) => {
            return !entry.leaving;
        });
        if (staying.length > 0)
            leave([staying[staying.length - 1].key]);

    }

    // Every popup at once, critical ones and those waiting too.
    function leaveAll() {
        waiting = [];
        leave(entries.map((entry) => {
            return entry.key;
        }));
    }

    // The center opening, or already open where you go, takes the popups in. Once the
    // island has its new owner: the cards giving up their claim while the owner is still
    // changing would change it again from inside the change.
    onFocusedChanged: settle()
    // Once the card has finished folding: its island given to the next card from inside
    // the change, the fold would be read again before it's over.
    onFoldedChanged: Qt.callLater(settle)
    Component.onCompleted: settle()
    onListedChanged: {
        if (listed)
            Qt.callLater(leaveAll);

    }

    Component {
        id: entryComponent

        PopupEntry {
        }

    }

    // While others wait, the popups pass one at a time: the oldest gives its place every
    // beat, long enough to read the one that just came in, a critical one like the rest.
    // Left to their own time, the three would go together and three more come at once.
    Timer {
        interval: 1500
        repeat: true
        running: popups.waiting.length > 0 && popups.out && !popups.held
        onTriggered: popups.passOn()
    }

    Connections {
        function onArrived(notification) {
            popups.show(notification);
        }

        target: Notifications
    }

}
