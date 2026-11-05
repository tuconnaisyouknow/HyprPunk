import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the notifications waiting in a file, so they come back when Quickshell is
// killed and started again. They come back without their buttons: those only work
// through the server the app sent them to. Reloading the config keeps the real ones.
Scope {
    id: history

    required property var notificationServer
    readonly property string path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/hyprpunk/notifications.json"
    readonly property var live: notificationServer.trackedNotifications.values
    // The ones from before the restart, as plain data with negative ids, so they never
    // meet a live notification's.
    property var restored: []
    // Off until the file is read, or saving would wipe it first.
    property bool ready: false
    // The restored ones as the cards take them: no actions, and their own dismiss.
    readonly property var entries: restored.map((entry) => {
        return Object.assign({
            "actions": [],
            "dismiss": () => {
                return history.dismiss(entry.id);
            }
        }, entry);
    })

    function plain(notification) {
        return {
            "appName": notification.appName,
            "appIcon": notification.appIcon,
            "desktopEntry": notification.desktopEntry,
            "summary": notification.summary,
            "body": notification.body,
            // A picture sent as data only lives in this process.
            "image": notification.image.startsWith("image://") ? "" : notification.image,
            "urgency": notification.urgency
        };
    }

    function save() {
        if (!ready)
            return ;

        file.setText(JSON.stringify({
            "run": Quickshell.instanceId,
            "live": live.map(plain),
            "restored": restored
        }));
    }

    function dismiss(id) {
        restored = restored.filter((entry) => {
            return entry.id !== id;
        });
        save();
    }

    // Same Quickshell (a reload): the live ones are still there. A new one: they all
    // come back, the oldest first like the server lists them.
    function load(text) {
        let data = {
        };
        try {
            data = JSON.parse(text);
        } catch (error) {
        }
        const kept = Array.isArray(data.restored) ? data.restored : [];
        const entries = data.run === Quickshell.instanceId ? kept : kept.concat(Array.isArray(data.live) ? data.live : []);
        restored = entries.map((entry, index) => {
            return Object.assign({
            }, entry, {
                "id": -(index + 1)
            });
        });
        ready = true;
        save();
    }

    onLiveChanged: save()

    FileView {
        id: file

        path: history.path
        printErrors: false
        // Once: saving changes the file too.
        onLoaded: {
            if (!history.ready)
                history.load(text());

        }
        onLoadFailed: {
            if (!history.ready)
                history.load("");

        }
    }

}
