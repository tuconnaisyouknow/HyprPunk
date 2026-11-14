pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.state

// The shell's notification server, and the notifications kept from before Quickshell
// was restarted (NotificationHistory). Always on: apps send notifications whether or not
// you look.
Singleton {
    id: notifications

    readonly property alias server: server
    readonly property alias history: history
    // Everything waiting: the ones from before a restart, then the live ones, oldest
    // first.
    readonly property var waiting: history.entries.concat(server.trackedNotifications.values)
    readonly property int count: waiting.length

    // A new notification that pops up: not one carried over by a config reload, nor one
    // that Focus (all but the critical ones) or its app muted in the settings keeps away.
    // Those wait in the notification center without popping up.
    signal arrived(var notification)

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: (notification) => {
            notification.tracked = true;
            NotificationSettings.noticed(notification);
            if (notification.lastGeneration)
                return ;

            if (ShellState.doNotDisturb && notification.urgency !== NotificationUrgency.Critical)
                return ;

            if (NotificationSettings.muted(NotificationSettings.identity(notification)))
                return ;

            notifications.arrived(notification);
        }
    }

    NotificationHistory {
        id: history

        notificationServer: server
    }

}
