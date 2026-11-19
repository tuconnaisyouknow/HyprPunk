import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.modules.island
import qs.services

// The dynamic island in the bar: the time and its chips between the music's cover and
// equalizer, or an OSD that takes it over (IslandView). A click opens the calendar, the
// player from the music's ends, or the screenshot or recording an OSD shows. Every card
// of the island grows out of it (IslandFrame).
Pill {
    id: clockPill

    required property var bar
    // The calendar card it opens, and the player.
    required property Item calendar
    required property Item player
    // The time, which also tells the calendar what day it is.
    readonly property alias date: clock.date
    // What it shows (IslandView.face).
    readonly property string face: bar.islandOsdShown ? "osd" : "clock"
    // Where its time starts, from its left edge.
    readonly property real timeX: view.parent.x + view.x + view.timeX
    // Where the music's cover and equalizer are, the same way.
    readonly property real coverX: view.parent.x + view.x + view.coverX
    readonly property real equalizerX: view.parent.x + view.x + view.equalizerX
    // Between the time and an OSD.
    readonly property bool swapping: view.swapping

    // Another OSD over the one shown.
    function fadeContent() {
        view.fadeOsd();
    }

    // Hidden under the lock, which has it, and covered by its relay as the lock goes
    // (Lock.islandAway).
    opacity: covered || Lock.islandAway ? 0 : 1
    covered: clockPill.bar.pillHidden("island")
    // Not under the recording chip, which answers the pointer itself.
    clickable: (face === "clock" && !clockPill.bar.lockShown || face === "osd" && clockPill.bar.osdShown.kind === "screenshot") && !view.stopHovered
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
            Quickshell.execDetached(["xdg-open", clockPill.bar.osdShown.file]);
            Osd.dismiss();
        }
    }
    // The view sizes the island, padding included.
    horizontalPadding: 0
    implicitHeight: view.implicitHeight
    // Grows two pixels at a time, so centring it on the bar and its content in it
    // never lands on a half pixel and the content stops shaking as it resizes.
    Layout.preferredWidth: 2 * Math.round(implicitWidth / 2)
    Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)

    IslandView {
        id: view

        bar: clockPill.bar
        face: clockPill.face
        animated: clockPill.bar.islandAnimated
        live: clockPill.bar.islandAnimated
        // The player has them while it covers the island.
        musicLifted: clockPill.covered && clockPill.bar.islandFrame.lastOwner !== null && clockPill.bar.islandFrame.lastOwner.carriesMusic
        date: clock.date

        // Ticks every second though it shows minutes: its timer stands still
        // during sleep, so on waking it would keep the old time up to a minute.
        SystemClock {
            id: clock

            precision: SystemClock.Seconds
        }

    }

}
