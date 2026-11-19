import QtQuick

// Notifications listed until their exit animation is over, so several can leave at once
// and a closed one keeps its card while it goes: the island's popups and the notification
// center's list. An entry is { id, notification }: the id is kept apart because a closed
// notification is destroyed, and lingers as an empty object with no id to tell it by.
QtObject {
    id: exiting

    // Newest first.
    property var entries: []
    // The ones playing their exit animation.
    property var leavingIds: []
    // The leaving ones already out of sight, their gap still closing.
    property var vanishedIds: []
    // Both counted once a change is whole: read between two of its lists, they would
    // step through a count that never was, and the card following them would start over.
    property int staying: 0
    // Still in sight, those on their way out included: the room that's taken.
    property int inSight: 0

    function count() {
        staying = entries.length - leavingIds.length;
        inSight = entries.length - vanishedIds.length;
    }

    function includes(id) {
        return entries.some((entry) => {
            return entry.id === id;
        });
    }

    function leaving(id) {
        return leavingIds.includes(id);
    }

    // On top, newest first.
    function add(notifications) {
        if (notifications.length === 0)
            return ;

        entries = notifications.map((notification) => {
            return {
                "id": notification.id,
                "notification": notification
            };
        }).concat(entries);
        count();
    }

    // Starts their exit animation: they're dropped once it's over.
    function leave(ids) {
        const fresh = ids.filter((id) => {
            return includes(id) && !leaving(id);
        });
        if (fresh.length === 0)
            return ;

        leavingIds = leavingIds.concat(fresh);
        count();
    }

    // Out of sight: what's left of its exit only gives its room back.
    function vanish(id) {
        vanishedIds = vanishedIds.concat([id]);
        count();
    }

    function drop(ids) {
        if (ids.length === 0)
            return ;

        const gone = new Set(ids);
        const kept = (id) => {
            return !gone.has(id);
        };
        vanishedIds = vanishedIds.filter(kept);
        leavingIds = leavingIds.filter(kept);
        entries = entries.filter((entry) => {
            return kept(entry.id);
        });
        count();
    }

    function clear() {
        vanishedIds = [];
        leavingIds = [];
        entries = [];
        count();
    }

}
