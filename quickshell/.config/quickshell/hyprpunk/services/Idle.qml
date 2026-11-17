pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// What happens once you leave the computer, step by step, after the delays you set in
// the settings (Power): the keyboard's light goes off, the screen dims, locks and turns
// off, then the computer sleeps. Caffeine and the apps that keep the screen on hold it
// all back, through Wayland's idle inhibitors.
Singleton {
    id: idle

    // A light lowered while you're away, back as you return. The OSD stays quiet for it.
    function light(which, on) {
        const until = Date.now() + 2000;
        if (which === "keyboard")
            Devices.keyboardOsdMutedUntil = until;
        else
            Devices.screenOsdMutedUntil = until;
        Quickshell.execDetached([Session.scripts + "/idle-lights.sh", on ? "restore" : "off", which]);
    }

    function wakeScreens() {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({action = \"on\"})"]);
    }

    // The shell starts with you here: what one that restarted while you were away left
    // lowered or off comes back, since it never saw you return.
    Component.onCompleted: {
        light("keyboard", true);
        light("screen", true);
        wakeScreens();
    }

    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("keyboard")
        onIsIdleChanged: idle.light("keyboard", !isIdle)
    }

    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("dim")
        onIsIdleChanged: idle.light("screen", !isIdle)
    }

    // Through logind, so it knows the session is locked (hypridle shows the lock for it).
    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("lock")
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["sh", "-c", "loginctl lock-session && hyprctl dispatch 'hl.dsp.dpms({action = \"off\"})'"]);
            else
                idle.wakeScreens();
        }
    }

    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("suspend")
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["systemctl", "suspend"]);

        }
    }

}
