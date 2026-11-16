import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.modules.island
import qs.services
import qs.theme

// The dynamic island in the bar: the time and its chips, or an OSD that takes it over
// (IslandView). A click opens the calendar, or the screenshot or recording an OSD shows.
// Every card of the island grows out of it (IslandFrame).
Pill {
    id: clockPill

    required property var bar
    // The calendar card it opens.
    required property Item calendar
    // The time, ticking for the calendar's own copy of it too.
    readonly property alias date: clock.date
    // What it shows (IslandView.face).
    readonly property string face: bar.islandOsdShown ? "osd" : "clock"
    // Where its time starts, from its left edge.
    readonly property real timeX: view.parent.x + view.x + view.timeX
    // Between the time and an OSD.
    readonly property bool swapping: view.swapping

    // Another OSD over the one shown.
    function fadeContent() {
        view.fadeOsd();
    }

    // Where it rests in its row, and its zoom apart.
    function publishGeometry() {
        const origin = parent.mapToItem(null, x, y);
        clockPill.bar.islandPill = {
            "centerOffset": origin.x + width / 2 - clockPill.bar.width / 2,
            "top": origin.y,
            "width": width,
            "height": height,
            "spreadX": spreadX,
            "spreadY": spreadY
        };
    }

    // Hidden under the lock, which has it, and covered by its relay as the lock goes
    // (Lock.islandAway).
    opacity: clockPill.bar.pillHidden("island") || Lock.islandAway ? 0 : 1
    // Squeezed under the time landing back from the lock screen, as the lock hands it over
    // (Lock.relays): the bar takes it squeezed, unseen, and springs it back once it draws
    // again.
    scale: Lock.relays[clockPill.bar.screen.name] !== undefined ? Motion.squeeze(width) : 1
    // Not under the recording chip, which answers the pointer itself.
    clickable: (face === "clock" && !clockPill.bar.lockShown || face === "osd" && clockPill.bar.osdShown.kind === "screenshot") && !view.stopHovered
    onWidthChanged: publishGeometry()
    onHeightChanged: publishGeometry()
    onSpreadXChanged: publishGeometry()
    onSpreadYChanged: publishGeometry()
    Component.onCompleted: publishGeometry()
    // A click opens the calendar card, or closes it, unless an OSD has the
    // island: the screenshot or recording just taken then opens in its viewer.
    // The recording chip keeps its own click, which stops the recording.
    onClicked: {
        if (face === "clock") {
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

    Behavior on scale {
        enabled: !clockPill.bar.sessionLocked

        NumberAnimation {
            duration: Motion.bounce.releaseDuration
            easing.type: Motion.bounce.releaseEasing
            easing.overshoot: Motion.bounce.overshoot
        }

    }

    IslandView {
        id: view

        bar: clockPill.bar
        face: clockPill.face
        animated: clockPill.bar.islandAnimated
        date: clock.date

        // Ticks every second though it shows minutes: its timer stands still
        // during sleep, so on waking it would keep the old time up to a minute.
        SystemClock {
            id: clock

            precision: SystemClock.Seconds
        }

    }

}
