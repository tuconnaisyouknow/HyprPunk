import QtQuick

// Notifications listed until their exit animation is over, so several can leave at once
// and a closed one keeps its card while it goes: the notification center's list (the
// island's popups have their own stack, Popups). An entry is { id, notification }: the
// id is kept apart because a closed notification is destroyed, and lingers as an empty
// object with no id to tell it by.
QtObject {
    id: exiting

    // Newest first.
    property var entries: []
    // The ones playing their exit animation.
    property var leavingIds: []
    // Not counting the ones on their way out.
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
        if (notifications.length === 0)
            return ;

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
        if (fresh.length === 0)
            return ;

        leavingIds = leavingIds.concat(fresh);
    }

    function drop(ids) {
        if (ids.length === 0)
            return ;

        const gone = new Set(ids);
        const kept = (id) => {
            return !gone.has(id);
        };
        leavingIds = leavingIds.filter(kept);
        entries = entries.filter((entry) => {
            return kept(entry.id);
        });
    }

}
