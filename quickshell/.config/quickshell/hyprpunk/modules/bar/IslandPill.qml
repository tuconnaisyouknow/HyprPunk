import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.modules.island
import qs.services
import qs.theme

// The dynamic island in the bar: the time and its chips between the music's cover and
// equalizer, or an OSD that takes it over (IslandView). A click opens the calendar, the
// player from the music's ends, or the screenshot or recording an OSD shows. Every card
// of the island grows out of it (IslandFrame).
// Alone in the bar, it opens under the pointer onto your workspaces, the wallpaper, the
// control center's icons and the machine's load, whose blocks take the clicks then: the
// time opens the calendar, the wallpaper its picker, the load the system monitor, the
// icons the control center. The music's ends make way: its shortcut opens the player.
Pill {
    id: clockPill

    required property var bar
    // The calendar card it opens, and the player.
    required property Item calendar
    required property Item player
    // The time, which also tells the calendar what day it is.
    readonly property alias date: clock.date
    // What it shows (IslandView.face). Under a card that holds the island's shape it
    // keeps the face it had, which the card grew out of; it takes the next one as the
    // shape heads back to it, so the card folds onto what the island shows next.
    property string face: "clock"
    // Where its time starts, from its left edge.
    readonly property real timeX: view.parent.x + view.x + view.timeX
    // Where the music's cover and equalizer are, the same way and from its top, and the
    // cover's corners: the player flies them from there.
    readonly property real coverX: view.parent.x + view.x + view.coverX
    readonly property real coverY: view.parent.y + view.y + view.coverY
    readonly property real coverRadius: view.coverRadius
    readonly property real equalizerX: view.parent.x + view.x + view.equalizerX
    readonly property real equalizerY: view.parent.y + view.y + view.equalizerY
    readonly property real equalizerInset: view.equalizerInset
    // Between the time and an OSD, or opening and closing.
    readonly property bool swapping: view.swapping
    // The pointer is on it, or left it a moment ago: it opens as soon as the pointer comes,
    // and doesn't close as you only cross an edge.
    property bool pointed: false
    // Covered by a card opened out of it while open: it stays open under the card, which
    // grows out of it as you saw it. Once the card folds back it's held no more, so the
    // card folds straight onto the island as it closes, unless you're still on it.
    property bool held: false
    // Open while you point at it or it's held, never while the lock has it.
    readonly property bool open: clockPill.bar.islandOnly && !clockPill.bar.lockShown && (pointed || held)
    // The control center's icons in it, which the control center carries out.
    readonly property Item controlStatus: view.controlStatus

    // Hidden under the lock, which has it, and covered by its relay as the lock goes
    // (Lock.islandAway).
    opacity: covered || Lock.islandAway ? 0 : 1
    covered: clockPill.bar.pillHidden("island")
    // Not under a chip that answers the pointer itself, nor open, where its blocks do, but
    // on the music's ends.
    clickable: (face === "clock" && !clockPill.bar.lockShown && (!open || view.musicHovered) || face === "osd" && clockPill.bar.osdShown.kind === "screenshot") && !view.chipHovered
    // Alone in the bar, it opens rather than lighting up, like a card out of it, blurred
    // like one meanwhile.
    lights: !clockPill.bar.islandOnly
    // Open, a card's corners: round ends would cut into its sides' lines.
    radius: height / 2 - view.openness * (height / 2 - Metrics.cardRadius)
    blurredAsCard: view.unfolded
    onCoveredChanged: held = covered && open
    onHoveredChanged: {
        if (hovered)
            pointed = true;
        else
            leaving.restart();
    }
    // A click opens the calendar card, or closes it, or the player from the music's
    // ends, unless an OSD has the island: the screenshot or recording just taken then
    // opens in its viewer. The recording chip keeps its own click, which stops the
    // recording.
    onClicked: {
        if (face === "clock") {
            if (view.musicHovered)
                clockPill.player.togglePinned();
            else
                clockPill.calendar.togglePinned();
        } else {
            openShot();
        }
    }
    // The view sizes the island, padding included.
    horizontalPadding: 0
    implicitHeight: view.implicitHeight
    // The view grows two pixels at a time, so centred on the bar the island never lands
    // on a half pixel. Its height the same way.
    Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)

    // The screenshot or recording an OSD shows, in its viewer.
    function openShot() {
        Quickshell.execDetached(["xdg-open", clockPill.bar.osdShown.file]);
        clockPill.bar.osdTimeline.dismiss();
    }

    Connections {
        function onOwnerChanged() {
            if (clockPill.bar.islandFrame.owner === null)
                clockPill.held = false;

        }

        target: clockPill.bar.islandFrame
    }

    Timer {
        id: leaving

        interval: Motion.hoverCloseDelay
        onTriggered: clockPill.pointed = clockPill.hovered
    }

    Binding {
        target: clockPill
        property: "face"
        // Open, the island keeps the time's face and shows the OSD in the time's place.
        value: clockPill.bar.islandOsdShown && !clockPill.open ? "osd" : "clock"
        when: clockPill.bar.islandFrame.owner === null
        restoreMode: Binding.RestoreNone
    }

    IslandView {
        id: view

        bar: clockPill.bar
        face: clockPill.face
        animated: clockPill.bar.islandAnimated
        live: clockPill.bar.islandAnimated
        // The player has them while it covers the island.
        musicLifted: clockPill.covered && clockPill.bar.islandFrame.lastOwner !== null && clockPill.bar.islandFrame.lastOwner.carriesMusic
        controlsLifted: clockPill.covered && clockPill.bar.islandFrame.lastOwner !== null ? clockPill.bar.islandFrame.lastOwner.carriedIcons : []
        date: clock.date
        open: clockPill.open
        updatesShown: clockPill.bar.islandOnly && BarSettings.shows("updates")
        onTimeClicked: clockPill.calendar.togglePinned()
        onOsdClicked: clockPill.openShot()
        osdInside: clockPill.open && clockPill.bar.islandOsdShown

        // Ticks every second though it shows minutes: its timer stands still
        // during sleep, so on waking it would keep the old time up to a minute.
        SystemClock {
            id: clock

            precision: SystemClock.Seconds
        }

    }

}
