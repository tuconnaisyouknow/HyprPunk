pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// The shell's notification server, and the notifications kept from before Quickshell
// was restarted (NotificationHistory). Always on: apps send notifications whether or not
// you look.
Singleton {
    readonly property alias server: server
    readonly property alias history: history

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
        }
    }

    NotificationHistory {
        id: history

        notificationServer: server
    }

}
