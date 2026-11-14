//@ pragma UseQApplication
//@ pragma Env QT_QPA_PLATFORMTHEME = qt6ct
//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING = gray
//@ pragma IconTheme Papirus-Dark

// Gray antialiasing for the text: colored edges assume an opaque background and
// glitch through the see-through glass, worst over a light page.
// Animations keep Qt's own driver, paced by the main screen: its clock-driven one
// (QSG_USE_SIMPLE_ANIMATION_DRIVER) let each screen animate at its own rate, but made
// every screen redraw whole while anything moved on another one.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.modules.capture
import qs.modules.lock
import qs.modules.settings
import qs.services
import qs.state
import qs.windows

// Where the shell starts. Starts the services that can't wait for someone to look,
// answers the `qs -c hyprpunk ipc call …` commands that the shortcuts and scripts send,
// and puts a bar, popups and panels on every screen.
ShellRoot {
    // The desktop's music wave runs as its own Quickshell, so the shell's stalls (building
    // the lock screen) don't freeze it. Started whenever it's wanted, it quits once it isn't
    // (VisualizerShell.qml). -n: only one, whenever the shell starts or reloads.
    function startWave() {
        if (MusicSettings.wave)
            Quickshell.execDetached(["qs", "-n", "-p", Quickshell.shellPath("VisualizerShell.qml")]);

    }

    // Singletons are only made when first used: these have work to do from the start
    // (answering apps, the idle steps, the night light, the OSD, the battery's alerts and
    // the captive portals).
    Component.onCompleted: {
        Notifications.server;
        Polkit.agent;
        FileChooser.request;
        ScreenShare.request;
        AirPods.devices;
        Idle.objectName;
        NightLight.objectName;
        Osd.current;
        Screenshot.busy;
        NetworkStatus.device;
        startWave();
    }

    Connections {
        function onWaveChanged() {
            startWave();
        }

        target: MusicSettings
    }


    // The settings window, asked for like a panel, as "settings": Super+I through
    // `qs -c hyprpunk ipc call settings <toggle|open|close>`, and the main menu.
    SettingsWindow {
        id: settingsWindow
    }

    Connections {
        function onPanelRequestsChanged() {
            const request = ShellState.panelRequest;
            if (request.panel !== "settings")
                return ;

            if (request.action === "toggle")
                settingsWindow.toggle();
            else if (request.action === "open")
                settingsWindow.open();
            else
                settingsWindow.close();
        }

        target: ShellState
    }

    // The previous/next shortcuts go through `qs -c hyprpunk ipc call music <previous|next>`
    // rather than playerctl, so the bar knows which way the track changed.
    IpcHandler {
        function next(): void {
            Music.skip(1);
        }

        function previous(): void {
            Music.skip(-1);
        }

        target: "music"
    }

    // One handler per panel: `qs -c hyprpunk ipc call <panel> <toggle|open|close>`, used by the shortcuts.
    Variants {
        model: ["controlcenter", "notifications", "session", "wallpaper", "theme", "launcher", "clipboard", "emoji", "keybindings", "menu", "config", "workspaces", "systemmonitor", "player", "settings"]

        // Kept around the handler, so ipc show lists only the three functions.
        Scope {
            id: panelIpc

            required property string modelData

            IpcHandler {
                function toggle(): void {
                    ShellState.requestPanel(panelIpc.modelData, "toggle");
                }

                function open(): void {
                    ShellState.requestPanel(panelIpc.modelData, "open");
                }

                function close(): void {
                    ShellState.requestPanel(panelIpc.modelData, "close");
                }

                target: panelIpc.modelData
            }

        }

    }

    // The prompts the apps wait on open in the island of the focused screen.
    Connections {
        function onAuthenticationRequestStarted() {
            ShellState.requestPanel("polkit", "open");
        }

        target: Polkit.agent
    }

    Connections {
        function onRequested() {
            ShellState.requestPanel("filechooser", "open");
        }

        target: FileChooser
    }

    Connections {
        function onRequested() {
            ShellState.requestPanel("screenshare", "open");
        }

        target: ScreenShare
    }

    // The bar and its cards on every screen.
    Variants {
        id: screens

        model: Quickshell.screens

        ScreenShell {
            required property var modelData

            screen: modelData
        }

    }

    Lock {
        bars: screens.instances.map((shell) => {
            return shell.bar;
        })
    }

    Variants {
        model: Quickshell.screens

        ScreenshotSelector {
            required property var modelData

            screen: modelData
            screenName: modelData.name
        }

    }

}
