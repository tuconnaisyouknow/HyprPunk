pragma Singleton

import QtQuick
import Quickshell

// How notifications behave, saved by notificationctl.sh: how long they stay when an
// app doesn't say, and which apps pop up out of the island. Every app that has sent one
// is listed, so you can mute it; a muted app's notifications go straight to the center.
// An app goes by its desktop entry when the notification names one, which stays the
// same whatever name it sends (a browser's profile in it), or by that name otherwise.
Singleton {
    id: notificationSettings

    // Seconds, 0 until you close them. The default, until the file is read.
    property int duration: 5
    // The apps, first seen first. Only replaced when one joins or leaves, so muting one
    // doesn't rebuild the list showing them.
    property var apps: []
    property var mutedApps: []

    function identity(notification) {
        return notification.desktopEntry || notification.appName;
    }

    function muted(app) {
        return mutedApps.includes(app);
    }

    // A notification arrived: its app joins the list the first time.
    function noticed(notification) {
        const app = identity(notification);
        if (app !== "" && !apps.includes(app))
            run(["noticed", app]);

    }

    function setDuration(seconds) {
        run(["set", "duration", String(seconds)]);
    }

    function setMuted(app, mute) {
        run([mute ? "mute" : "unmute", app]);
    }

    function forget(app) {
        run(["forget", app]);
    }

    function run(args) {
        file.run(args);
    }

    // Only takes new lists when they differ, so the rows showing them aren't rebuilt.
    SettingsFile {
        id: file

        fileName: "notifications.conf"
        script: "notificationctl.sh"
        onEntriesChanged: {
            const apps = [];
            const muted = [];
            for (const [key, value] of entries) {
                if (key === "duration")
                    notificationSettings.duration = parseInt(value) || 0;
                else if ((key === "app" || key === "muted") && value !== "")
                    apps.push(value);
                if (key === "muted" && value !== "")
                    muted.push(value);

            }
            if (JSON.stringify(apps) !== JSON.stringify(notificationSettings.apps))
                notificationSettings.apps = apps;

            notificationSettings.mutedApps = muted;
        }
    }

}
