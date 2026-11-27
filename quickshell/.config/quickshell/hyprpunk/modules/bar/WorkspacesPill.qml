import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.modules.workspaces
import qs.theme

// The workspaces pill: your workspaces as dots, and a preview of the others in a card
// that grows out of it, on hover or with its shortcut (super+w). With the island alone in
// the bar, the preview is one of its cards.
Pill {
    id: workspacePill

    required property var bar
    readonly property alias popup: workspacePopup
    // Your other workspaces, by id, every one with a dot, empty or not, and which one the
    // preview card opens on (0 for the first).
    readonly property var previewIds: workspaceSwitcher.shownIds.filter((id) => {
        return workspaceSwitcher.focusedWorkspace === null || id !== workspaceSwitcher.focusedWorkspace.id;
    })
    property int previewId: 0
    // The workspace you were on before this one, which the preview opens on when you
    // ask for it with the keyboard: the one you most likely want back.
    property int lastId: 0
    property int shownId: 0
    readonly property var activeWorkspace: workspaceSwitcher.hyprlandMonitor !== null ? workspaceSwitcher.hyprlandMonitor.activeWorkspace : null
    // A snapshot of the bar for the previews (keeping grabToImage's result keeps it alive).
    property var barSnapshot: null
    readonly property int previewWidth: 400
    // The screen's shape, 16:9 until Hyprland has told which monitor the bar is on.
    readonly property int previewHeight: {
        const monitor = Hyprland.monitorFor(workspacePill.bar.screen);
        return Math.round(previewWidth * (monitor !== null && monitor.width > 0 ? monitor.height / monitor.width : 9 / 16));
    }

    onActiveWorkspaceChanged: {
        lastId = shownId;
        shownId = activeWorkspace !== null ? activeWorkspace.id : 0;
    }
    covered: workspacePill.bar.pillHidden("workspaces")

    onHoveredChanged: {
        if (!hovered)
            workspacePopup.hoverEnded();

    }

    WorkspaceSwitcher {
        id: workspaceSwitcher

        screen: workspacePill.bar.screen
        // Waits like the other pills. No need to preview the workspace you're on.
        onHoveredIdChanged: {
            if (workspacePill.previewIds.includes(hoveredId) && !workspacePopup.mapped)
                workspacePopup.hoverStarted();
            else
                workspacePopup.cancelOpen();
        }
    }

    PillPopup {
        id: workspacePopup

        cardLayer: workspacePill.bar.cardLayer
        pill: workspacePill.bar.islandOnly ? workspacePill.bar.islandItem : workspacePill
        pillName: workspacePill.bar.islandOnly ? "island" : "workspaces"
        frame: workspacePill.bar.islandOnly ? workspacePill.bar.islandFrame : null
        align: workspacePill.bar.islandOnly ? Qt.AlignHCenter : Qt.AlignLeft
        panelName: "workspaces"
        screenState: workspacePill.bar.screenState
        // Nothing to preview while other screens hold every other workspace.
        requestable: workspacePill.previewIds.length > 0
        opensOnHover: true
        openable: workspaceSwitcher.hoveredId !== 0
        implicitWidth: workspacePill.previewWidth + 2 * Metrics.spacing.large
        implicitHeight: workspacePill.previewHeight + 2 * Metrics.spacing.large
        // Ask Hyprland where the windows are (it only says when asked), and
        // snapshot the bar to lay over every preview.
        onOpening: {
            Hyprland.refreshToplevels();
            workspacePill.bar.content.grabToImage((result) => {
                workspacePill.barSnapshot = result;
            });
            if (workspaceSwitcher.hoveredId !== 0)
                workspacePill.previewId = workspaceSwitcher.hoveredId;
            else
                workspacePill.previewId = workspacePill.previewIds.includes(workspacePill.lastId) ? workspacePill.lastId : 0;
        }
        // Opened with its shortcut: the arrows (Vim's too) or Tab go through
        // the workspaces, Enter takes you there.
        onKeyPressed: (key) => {
            const card = previewLoader.item;
            if (card === null)
                return ;

            if (key === Qt.Key_Left || key === Qt.Key_Backtab || key === Session.vimKeyCodes[0])
                card.step(-1);
            else if (key === Qt.Key_Right || key === Qt.Key_Tab || key === Session.vimKeyCodes[1])
                card.step(1);
            else if (key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space)
                card.choose();
        }

        // Rebuilt on every opening, so the windows are captured fresh.
        Loader {
            id: previewLoader

            x: Metrics.spacing.large
            y: Metrics.spacing.large
            width: workspacePill.previewWidth
            height: workspacePill.previewHeight
            active: workspacePopup.mapped
            opacity: workspacePopup.showing ? 1 : 0

            sourceComponent: WorkspacePreviewCard {
                workspaceIds: workspacePill.previewIds
                initialId: workspacePill.previewId
                monitor: workspaceSwitcher.hyprlandMonitor
                wallpaper: Session.wallpaper
                barImage: workspacePill.barSnapshot !== null ? workspacePill.barSnapshot.url : ""
                barRect: Qt.rect(workspacePill.bar.content.x, workspacePill.bar.content.y, workspacePill.bar.content.width, workspacePill.bar.content.height)
                // An empty workspace has nothing to activate yet: Hyprland makes it.
                onWorkspaceChosen: (id) => {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
                    workspacePopup.close();
                }
            }

            Behavior on opacity {
                Anim {
                    token: Motion.color.small
                }

            }

        }

    }

}
