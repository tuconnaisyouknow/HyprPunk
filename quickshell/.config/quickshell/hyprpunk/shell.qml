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
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.Polkit
import qs.config
import qs.modules.capture
import qs.modules.lock
import qs.modules.settings
import qs.services
import qs.state
import qs.windows

// Where the shell starts. Holds the state the screens share (which panel is open
// where, screenshots, caffeine…), answers the `qs -c hyprpunk ipc call …` commands
// that the shortcuts and scripts send, and puts a bar, popups and panels on every screen.
ShellRoot {
    // The desktop's music wave runs as its own Quickshell, so the shell's stalls (building
    // the lock screen) don't freeze it. Started whenever it's wanted, it quits once it isn't
    // (VisualizerShell.qml). -n: only one, whenever the shell starts or reloads.
    function startWave() {
        if (MusicSettings.wave)
            Quickshell.execDetached(["qs", "-n", "-p", Quickshell.shellPath("VisualizerShell.qml")]);

    }

    Component.onCompleted: startWave()

    Connections {
        function onWaveChanged() {
            startWave();
        }

        target: MusicSettings
    }


    // Dims, locks and suspends once you're away.
    Idle {
    }

    // Warms the screens in the evening.
    NightLight {
    }

    // Sleeps or shuts down before the battery dies.
    CriticalBattery {
    }

    // The settings window, asked for like a panel, as "settings": Super+I through
    // `qs -c hyprpunk ipc call settings <toggle|open|close>`, and the main menu.
    SettingsWindow {
        id: settingsWindow

        fileChooser: fileChooserService
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
    // rather than playerctl, because MPRIS never says which way the track changed.
    IpcHandler {
        function skip(direction: int, command: string): void {
            ShellState.musicSkipDirection = direction;
            ShellState.musicSkipUntil = Date.now() + 2000;
            if (direction < 0)
                ShellState.musicPreviousRequests += 1;

            Quickshell.execDetached(["playerctl", command]);
        }

        function next(): void {
            skip(1, "next");
        }

        function previous(): void {
            skip(-1, "previous");
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

    NotificationServer {
        id: notificationService

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
        id: notificationArchive

        notificationServer: notificationService
    }

    // The shell answers the password prompts itself, on the focused screen.
    PolkitAgent {
        id: polkitService

        onAuthenticationRequestStarted: ShellState.requestPanel("polkit", "open")
    }

    // The apps' Open and Save dialogs, through the portal, on the focused screen too.
    FileChooser {
        id: fileChooserService

        onRequested: ShellState.requestPanel("filechooser", "open")
    }

    // What an app gets to see when it shares your screen, through
    // xdg-desktop-portal-hyprland, on the focused screen too.
    ScreenShare {
        id: screenShareService

        onRequested: ShellState.requestPanel("screenshare", "open")
    }

    // The bar and its cards on every screen.
    Variants {
        id: screens

        model: Quickshell.screens

        ScreenShell {
            required property var modelData

            screen: modelData
            notificationServer: notificationService
            notificationHistory: notificationArchive
            polkitAgent: polkitService
            fileChooser: fileChooserService
            screenShare: screenShareService
            airPods: airPodsService
        }

    }

    Lock {
        bars: screens.instances.map((shell) => {
            return shell.bar;
        })
    }

    Screenshot {
    }

    Variants {
        model: Quickshell.screens

        ScreenshotSelector {
            required property var modelData

            screen: modelData
            screenName: modelData.name
        }

    }

    AirPods {
        id: airPodsService
    }

    // A network that wants you to sign in first: a notification takes you to its page,
    // and asks to set a VPN aside when it hides that page (captive-portal.sh).
    Connections {
        function onConnectivityChanged() {
            const step = {
                [NetworkConnectivity.Portal]: "portal",
                [NetworkConnectivity.Limited]: "limited",
                [NetworkConnectivity.Full]: "online"
            }[Networking.connectivity];
            if (step)
                Quickshell.execDetached([Session.scripts + "/captive-portal.sh", step]);

        }

        target: Networking
    }

}
