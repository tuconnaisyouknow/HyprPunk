import QtQuick
import Quickshell
import Quickshell.Wayland

// What happens once you leave the computer, step by step, after the delays you set in
// the settings (Power): the keyboard's light goes off, the screen dims, locks and turns
// off, then the computer sleeps. Caffeine and the apps that keep the screen on hold it
// all back, through Wayland's idle inhibitors.
Scope {
    id: idle

    // The OSD stays quiet for the light and brightness changes made here.
    function muteOsd(device) {
        const until = Date.now() + 2000;
        if (device === "keyboard")
            Devices.keyboardOsdMutedUntil = until;
        else
            Devices.screenOsdMutedUntil = until;
    }

    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("keyboard")
        onIsIdleChanged: {
            idle.muteOsd("keyboard");
            Quickshell.execDetached([Session.scripts + "/keyboard-backlight.sh", isIdle ? "off" : "restore"]);
        }
    }

    // brightnessctl saves the brightness before dimming and puts it back.
    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("dim")
        onIsIdleChanged: {
            idle.muteOsd("screen");
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", isIdle ? "-s" : "-r"].concat(isIdle ? ["set", "10"] : []));
        }
    }

    // Through logind, so it knows the session is locked (hypridle shows the lock for it).
    IdleMonitor {
        enabled: timeout > 0
        timeout: Power.delay("lock")
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["sh", "-c", "loginctl lock-session && hyprctl dispatch 'hl.dsp.dpms({action = \"off\"})'"]);
            else
                Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.dpms({action = \"on\"})"]);
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
