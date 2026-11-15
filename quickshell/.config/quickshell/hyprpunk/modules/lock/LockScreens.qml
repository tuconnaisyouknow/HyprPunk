import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The lock screens, one per screen (LockSurface), and the islands they leave behind
// (LockRelay). It's a real session lock: if the shell crashes, the screens stay locked.
// When and how it locks is the Lock service's.
Scope {
    // Decode each screen's wallpaper ahead of time (a 4K one takes a good part of a
    // second), so the lock finds it in the cache and can fade it in straight away.
    Variants {
        model: Quickshell.screens

        Image {
            required property var modelData

            source: Session.wallpaper !== "" ? "file://" + Session.wallpaper : ""
            sourceSize.width: modelData.width
            sourceSize.height: modelData.height
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

    }

    WlSessionLock {
        locked: Lock.locked
        onSecureChanged: {
            if (secure)
                Lock.secured();

        }

        LockSurface {
        }

    }

    // Each screen's island as the lock leaves it, over the bar until it draws again.
    Variants {
        model: Quickshell.screens

        LockRelay {
        }

    }

}
