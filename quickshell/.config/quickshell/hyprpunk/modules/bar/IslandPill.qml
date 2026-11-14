import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.config
import qs.modules.island
import qs.services
import qs.theme

// The dynamic island at rest: the time and its chips, or the OSD that takes it over. A
// click opens the calendar, or the screenshot or recording an OSD shows. Every card of
// the island grows out of it (IslandFrame).
Pill {
    id: clockPill

    required property var bar
    // The calendar card it opens.
    required property Item calendar
    // The time, ticking for the calendar's own copy of it too.
    readonly property alias date: clock.date
    readonly property alias timeLabel: dateTimeLabel

    // The new content fades in while the pill resizes around it.
    function fadeContent() {
        contentFade.restart();
    }

    opacity: clockPill.bar.pillHidden("island") ? 0 : 1
    // Not under the recording chip, which answers the pointer itself.
    clickable: (!clockPill.bar.islandOsdShown || clockPill.bar.osdShown.kind === "screenshot") && !islandChips.stopHovered

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

    onWidthChanged: publishGeometry()
    onHeightChanged: publishGeometry()
    onSpreadXChanged: publishGeometry()
    onSpreadYChanged: publishGeometry()
    Component.onCompleted: publishGeometry()
    // Each chip brings its own gap after the time.
    spacing: 0

    // A click opens the calendar card, or closes it, unless an OSD has the
    // island: the screenshot or recording just taken then opens in its viewer.
    // The recording chip keeps its own click, which stops the recording.
    onClicked: {
        if (!clockPill.bar.islandOsdShown) {
            clockPill.calendar.togglePinned();
        } else {
            Quickshell.execDetached(["xdg-open", clockPill.bar.osdShown.file]);
            Osd.dismiss();
        }
    }
    horizontalPadding: clockPill.bar.islandOsdShown ? Metrics.islandOsdPadding : Metrics.pillPadding
    implicitHeight: clockPill.bar.islandOsdShown ? Metrics.islandOsdHeight : Metrics.pillHeight
    // Grows two pixels at a time, so centring it on the bar and its content in it
    // never lands on a half pixel and the content stops shaking as it resizes.
    Layout.preferredWidth: 2 * Math.round(implicitWidth / 2)
    Layout.preferredHeight: 2 * Math.round(implicitHeight / 2)
    contentOpacity: 1

    Label {
        id: dateTimeLabel

        visible: !clockPill.bar.islandOsdShown
        text: Session.clockText(clock.date)

        // Ticks every second though it shows minutes: its timer stands still
        // during sleep, so on waking it would keep the old time up to a minute.
        SystemClock {
            id: clock

            precision: SystemClock.Seconds
        }

    }

    // Gone at once when an OSD takes the island, or their closing would pull
    // the OSD sideways while it grows.
    IslandChips {
        id: islandChips

        bar: clockPill.bar
        visible: !clockPill.bar.islandOsdShown
        shown: !clockPill.bar.islandOsdShown
        animated: clockPill.bar.islandAnimated
    }

    IslandOsd {
        shown: clockPill.bar.osdVisible
        content: clockPill.bar.osdShown
        visible: clockPill.bar.islandOsdShown
    }

    Behavior on implicitWidth {
        enabled: clockPill.bar.islandAnimated

        Anim {
            token: Motion.resize.normal
        }

    }

    Behavior on implicitHeight {
        enabled: clockPill.bar.islandAnimated

        Anim {
            token: Motion.resize.normal
        }

    }


    SequentialAnimation {
        id: contentFade

        PropertyAction {
            target: clockPill
            property: "contentOpacity"
            value: 0
        }

        // Halfway through its resize the pill is ~90% open, so its edges don't clip
        // the content.
        PauseAnimation {
            duration: Motion.resize.normal.duration / 2
        }

        Anim {
            target: clockPill
            property: "contentOpacity"
            to: 1
            token: Motion.color.small
        }

    }

}
