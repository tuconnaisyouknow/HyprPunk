import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// What the island shows: one row of parts that open and close in place (IslandPart), the
// time between the music's cover and equalizer at its round ends, or the padlock in its
// place while the lock has it, the password's squares in the padlock's place as you type,
// the time's chips and why a try failed, or an OSD over it as another face (IslandFace). Its size follows its content as it changes, so
// the island around it needs no animation of its own. The bar's island and the lock's
// both draw it, so each picks up the island as it is.
Item {
    id: view

    required property var bar
    // "clock" for the row, "osd" for an OSD over it.
    property string face: "clock"
    property bool animated: true
    // The chips take the pointer: a click on the recording stops it.
    property bool interactive: true
    property date date
    // The time, gone while the lock has it, and its chips: the notifications leave with
    // it, the privacy dot and the recording stay until the lock goes.
    property bool timeShown: true
    property bool chipsShown: timeShown
    // The music's cover and equalizer, while Spotify runs. They leave with the time: the
    // lock shows its own player.
    readonly property bool musicShown: timeShown && Music.player !== null
    // The cover and the equalizer drawn elsewhere for now, their places kept: the player's,
    // as it grows out of the island and folds back into it.
    property bool musicLifted: false
    // The equalizer moves: off while the island is hidden.
    property bool live: true
    // The padlock, while the lock has the time and you've typed nothing.
    property bool padlock: false
    // The time drawn elsewhere for now, its place kept: the lock's clock, as it leaves
    // from there.
    property bool timeLifted: false
    // The password typed on the lock screen (PasswordSquares), and why the last try failed
    // (LockWords).
    property int typed: 0
    property bool checking: false
    property string lockError: ""
    // The time, where the lock's clock leaves from.
    readonly property Item timeItem: timeLabel
    // Between two faces.
    readonly property bool swapping: clockFace.moving || osdFace.moving
    // Where the time starts, from the view's left edge.
    readonly property real timeX: clockFace.x + timePart.x
    // Where the cover and the equalizer's slot are, the same way.
    readonly property real coverX: clockFace.x + coverPart.x
    readonly property real equalizerX: clockFace.x + equalizerPart.x
    readonly property bool stopHovered: chips.stopHovered
    // The pointer is on the cover or the equalizer, where a click opens the player.
    readonly property bool musicHovered: coverHover.hovered || equalizerHover.hovered
    readonly property real presence: clockFace.presence + osdFace.presence

    // Another OSD over the one shown: its content fades in again, while the face eases
    // to its size.
    function fadeOsd() {
        osdFade.restart();
    }

    // Each face's size, weighed by how much it's there.
    implicitWidth: (clockFace.presence * clockFace.islandWidth + osdFace.presence * osdFace.islandWidth) / Math.max(presence, 0.001)
    implicitHeight: (clockFace.presence * clockFace.islandHeight + osdFace.presence * osdFace.islandHeight) / Math.max(presence, 0.001)

    IslandFace {
        id: clockFace

        shown: view.face === "clock"
        animated: view.animated
        contentWidth: clockRow.implicitWidth
        contentHeight: clockRow.implicitHeight
        // The cover and the equalizer hug the round ends, as near to the edge as to the
        // top and the bottom.
        padding: Metrics.pillPadding - (Metrics.pillPadding - Metrics.islandMusicInset) * coverPart.presence
        islandHeight: Metrics.pillHeight

        // Each part opens in the place of the one before it closes: the padlock in the
        // time's, the squares in the padlock's. Each parts itself from what's before it by as
        // much as something is open there, so the island stays centred on what's left.
        RowLayout {
            id: clockRow

            anchors.centerIn: parent
            spacing: 0

            IslandCover {
                id: coverPart

                shown: view.musicShown
                animated: view.animated
                lifted: view.musicLifted
                gap: 0

                HoverHandler {
                    id: coverHover

                    enabled: view.interactive
                }

            }

            IslandPart {
                id: timePart

                shown: view.timeShown
                animated: view.animated
                gap: Metrics.spacing.normal * coverPart.presence
                openWidth: timeLabel.implicitWidth
                openHeight: timeLabel.implicitHeight

                Label {
                    id: timeLabel

                    opacity: view.timeLifted ? 0 : 1
                    text: Session.clockText(view.date)
                    font.features: {
                        "tnum": 1
                    }
                }

            }

            IslandPart {
                id: padlockPart

                shown: view.padlock
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + timePart.presence)
                // A whole, even number of pixels, the glyph on a whole pixel inside: its cell
                // is a fraction wide, and alone in the island's circle it would be drawn a
                // pixel to the left of the middle.
                openWidth: 2 * Math.round(padlockIcon.implicitWidth / 2)
                openHeight: padlockIcon.implicitHeight

                Text {
                    id: padlockIcon

                    x: Math.round((parent.width - implicitWidth) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    color: Colors.primary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.title
                }

            }

            PasswordSquares {
                id: squaresPart

                count: view.typed
                checking: view.checking
                alert: view.lockError !== "" && view.typed === 0
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + timePart.presence + padlockPart.presence)
            }

            IslandChips {
                id: chips

                bar: view.bar
                shown: view.chipsShown
                notificationsShown: view.chipsShown && view.timeShown
                animated: view.animated
                interactive: view.interactive && clockFace.shown
                lead: Math.min(1, coverPart.presence + timePart.presence + padlockPart.presence + squaresPart.presence)
            }

            IslandEqualizer {
                id: equalizerPart

                shown: view.musicShown
                animated: view.animated
                lifted: view.musicLifted
                live: view.live
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + timePart.presence + padlockPart.presence + squaresPart.presence + chips.presence)

                HoverHandler {
                    id: equalizerHover

                    enabled: view.interactive
                }

            }

            LockWords {
                label: view.lockError
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + timePart.presence + padlockPart.presence + squaresPart.presence + chips.presence + equalizerPart.presence)
            }

        }

    }

    // Its content changes at once from one OSD to the next, so the face eases to the new
    // size itself.
    IslandFace {
        id: osdFace

        shown: view.face === "osd"
        animated: view.animated
        contentWidth: osdContent.implicitWidth
        contentHeight: osdContent.implicitHeight
        padding: Metrics.islandOsdPadding
        islandHeight: Metrics.islandOsdHeight

        IslandOsd {
            id: osdContent

            anchors.centerIn: parent
            // Kept whole while the face goes.
            shown: osdFace.visible
            content: view.bar.osdShown
        }

        Behavior on contentWidth {
            enabled: view.animated && osdFace.shown

            Anim {
                token: Motion.resize.normal
            }

        }

    }

    SequentialAnimation {
        id: osdFade

        PropertyAction {
            target: osdContent
            property: "opacity"
            value: 0
        }

        // Halfway through the resize the face is ~90% of its new size, so the new
        // content isn't drawn over its old edges.
        PauseAnimation {
            duration: Motion.resize.normal.duration / 2
        }

        Anim {
            target: osdContent
            property: "opacity"
            to: 1
            token: Motion.color.small
        }

    }

}
