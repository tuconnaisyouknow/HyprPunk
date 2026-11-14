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
    readonly property int staying: entries.length - leavingIds.length

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
        entries = notifications.map((notification) => {
            return {
                "id": notification.id,
                "notification": notification
            };
        }).concat(entries);
    }

    // Starts their exit animation: they're dropped once it's over.
    function leave(ids) {
        const fresh = ids.filter((id) => {
            return includes(id) && !leaving(id);
        });
        if (fresh.length > 0)
            leavingIds = leavingIds.concat(fresh);

    }

    function drop(id) {
        entries = entries.filter((entry) => {
            return entry.id !== id;
        });
        leavingIds = leavingIds.filter((leavingId) => {
            return leavingId !== id;
        });
    }

    function clear() {
        entries = [];
        leavingIds = [];
    }

}
