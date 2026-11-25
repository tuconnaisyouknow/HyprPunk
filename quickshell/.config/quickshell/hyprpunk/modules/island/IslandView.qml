import QtQuick
import qs.components
import qs.config
import qs.modules.music
import qs.modules.workspaces
import qs.services
import qs.theme

// What the island shows: one row of parts that open and close in place (IslandPart), the
// time between the music's cover and equalizer at its round ends, or the padlock in its
// place while the lock has it, the password's squares in the padlock's place as you type,
// the time's chips and why a try failed, or an OSD over it as another face (IslandFace).
// Alone in the bar, it opens under the pointer (open), and the time stays: it grows a
// little over the date between two sides as wide as each other, so it stays in the middle
// (IslandSide). On its left the window you're on over your workspaces, on its right the
// music over the control center's icons: the cover and the equalizer fly there from the
// island's ends. The chips make way, and an OSD takes the time's place there rather than
// closing it.
// Its size follows its content as it changes, so the island around it needs no animation
// of its own. The bar's island and the lock's both draw it, so each picks up the island as
// it is.
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
    // The music's cover and equalizer, while a player runs. They leave with the time: the
    // lock shows its own player.
    readonly property bool musicShown: timeShown && Music.player !== null
    // The cover and the equalizer drawn elsewhere for now, their places kept: the player's,
    // as it grows out of the island and folds back into it.
    property bool musicLifted: false
    // The control center's icons a card carries out of the open island for now, by name
    // (Card.carriedIcons), and the icons themselves.
    property var controlsLifted: []
    readonly property Item controlStatus: controlBlock.status
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
    // Open wide under the pointer (Bar.islandOnly), and how far across and down. It
    // unfolds like a card out of the island (Motion.unfold): its width and its height each
    // going past and coming back. The parts it opens onto and the time's block follow the
    // width, the time's size, the date and the island's height the height.
    property bool open: false
    property real openWidthShare: open ? 1 : 0
    property real openness: open ? 1 : 0
    // How far the cover and the equalizer have flown across and down, between their place
    // in the island's ends and on the music's line, never past either: the island going
    // past its size moves those places, which they ride, but their own way doesn't go past.
    readonly property real flightAcross: Math.max(0, Math.min(1, openWidthShare))
    readonly property real flightDown: Math.max(0, Math.min(1, openness))
    // Open, or on its way open or closed.
    readonly property bool unfolded: open || openingWidth.running || opening.running
    // An OSD while the island is open: in the time's place, the island staying open.
    property bool osdInside: false
    // The update packages waiting, as a chip (Bar.islandOnly).
    property bool updatesShown: false
    // Each side of the open time: room for a title on its line, and for the workspaces
    // and the icons under it.
    readonly property real sideWidth: 2 * Math.ceil(Math.max(200, workspaceBars.fullWidth + 2 * Metrics.spacing.large, controlBlock.implicitWidth) / 2)
    // The cover's and the equalizer's slot.
    readonly property real musicSlot: Metrics.pillHeight - 2 * Metrics.islandMusicInset
    // How much bigger the time is, open.
    readonly property real timeScale: 1 + openness * (Metrics.text.heading / Metrics.text.title - 1)
    // The time's place at rest, even, eased as the minutes change its ink. Open, its block
    // around the time and the date, even too.
    property real timeWidth: 2 * Math.ceil(timeInk.tightBoundingRect.width / 2)
    readonly property real openTimeWidth: 2 * Math.ceil(Math.max(timeInk.tightBoundingRect.width * Metrics.text.heading / Metrics.text.title, dateLabel.implicitWidth) / 2) + 2 * Metrics.spacing.large

    signal timeClicked()
    signal musicClicked()
    // A click on the screenshot an OSD shows in the open island.
    signal osdClicked()
    // The time, where the lock's clock leaves from.
    readonly property Item timeItem: timeLabel
    // Between two faces.
    readonly property bool swapping: clockFace.moving || osdFace.moving || openingWidth.running || opening.running
    // Where the time starts, from the view's left edge.
    readonly property real timeX: clockFace.x + timePart.placeX
    // Where the cover and the equalizer's slot are, from the view's corner, as you see them:
    // in the island's ends, on the music's line, or on their way. The cover's corners, and
    // how round the equalizer's bars are, to fit its round end.
    readonly property real coverX: clockFace.x + flyingCover.x
    readonly property real coverY: clockFace.y + flyingCover.y
    readonly property real coverRadius: flyingCover.radius
    readonly property real equalizerX: clockFace.x + flyingEqualizer.x
    readonly property real equalizerY: clockFace.y + flyingEqualizer.y
    readonly property real equalizerRoundness: flyingBars.roundness
    // Where the equalizer's bars sit in its slot.
    readonly property real equalizerInset: equalizerPart.slack
    // The pointer is on a chip with its own click (the recording, the updates).
    readonly property bool chipHovered: chips.chipHovered
    // The pointer is on the cover or the equalizer, where a click opens the player.
    readonly property bool musicHovered: coverHover.hovered || equalizerHover.hovered
    readonly property real presence: clockFace.presence + osdFace.presence

    // How far down something in the island's middle is on its way to a place on the music's
    // line (given from the line's top), as the island opens: both in the clock's row.
    function flightY(lineY) {
        const middle = clockRow.height / 2;
        const onLine = musicSide.y + musicSide.openHeight / 2 + (lineY - musicSide.openHeight / 2) * musicSide.presence;
        return middle + (onLine - middle) * flightDown;
    }

    // Each face's size, weighed by how much it's there. The width grows two pixels at a
    // time, the one thing rounded here: centred on the island's middle, a whole pixel, it
    // stays on whole pixels, and the faces inside follow their exact place.
    implicitWidth: 2 * Math.round((clockFace.presence * clockFace.islandWidth + osdFace.presence * osdFace.islandWidth) / Math.max(presence, 0.001) / 2)
    implicitHeight: (clockFace.presence * clockFace.islandHeight + osdFace.presence * osdFace.islandHeight) / Math.max(presence, 0.001)

    Behavior on openWidthShare {
        enabled: view.animated

        Anim {
            id: openingWidth

            token: Motion.unfold.width
        }

    }

    Behavior on openness {
        enabled: view.animated

        Anim {
            id: opening

            token: Motion.unfold.height
        }

    }

    Behavior on timeWidth {
        enabled: view.animated && timePart.visible

        Anim {
            token: Motion.resize.small
        }

    }

    IslandFace {
        id: clockFace

        shown: view.face === "clock"
        animated: view.animated
        contentWidth: clockRow.implicitWidth
        contentHeight: clockRow.implicitHeight
        // The cover and the equalizer hug the round ends, as near to the edge as to the
        // top and the bottom.
        padding: Metrics.pillPadding - (Metrics.pillPadding - Metrics.islandMusicInset) * coverPart.presence
        islandHeight: Metrics.pillHeight + view.openness * (Metrics.islandOpenHeight - Metrics.pillHeight)

        // Each part opens in the place of the one before it closes: the padlock in the
        // time's, the squares in the padlock's. Each parts itself from what's before it by as
        // much as something is open there, so the island stays centred on what's left: the
        // same gap between any two, from what one draws to what the next does.
        Row {
            id: clockRow

            anchors.centerIn: parent

            // Out of the way while the island is open, the cover flown to the music's line.
            IslandCover {
                id: coverPart

                shown: view.musicShown
                room: 1 - view.openWidthShare
                animated: view.animated
                lifted: view.musicLifted || view.unfolded
                gap: 0

                HoverHandler {
                    id: coverHover

                    enabled: view.interactive
                }

            }

            IslandSide {
                id: windowSide

                shown: view.open
                animated: view.animated
                gap: Metrics.spacing.normal * coverPart.presence
                openWidth: view.sideWidth
                line: IslandWindowLine {
                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    screen: view.bar.screen
                    interactive: view.interactive && view.open
                    onClicked: view.bar.screenState.toggle("workspaces")
                }
                row: WorkspaceBars {
                    id: workspaceBars

                    x: (view.sideWidth - implicitWidth) / 2
                    screen: view.bar.screen
                    interactive: view.interactive && view.open
                }
            }

            IslandPart {
                id: timePart

                shown: view.timeShown && !view.osdInside
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence)
                // Its place is the time's ink, so the gaps on both sides are measured from
                // what's drawn: the digits fill their cells unevenly (a 1 leaves far more
                // room on its right than a 0), and the cover and the equalizer sat unevenly
                // around it, differently from one minute to the next.
                // Rounded up to an even width, the ink in its middle. Open, its block's.
                openWidth: view.timeWidth + view.openWidthShare * (view.openTimeWidth - view.timeWidth)
                openHeight: timeLabel.implicitHeight * view.timeScale + view.openness * dateLabel.implicitHeight
                resizes: false

                // Lit under the pointer once open: a click opens the calendar.
                IslandBlock {
                    anchors.fill: parent
                    anchors.topMargin: -Metrics.spacing.small
                    anchors.bottomMargin: -Metrics.spacing.small
                    interactive: view.interactive && view.open
                    onClicked: view.timeClicked()
                }

                RollingText {
                    id: timeLabel

                    x: (timePart.openWidth - timeInk.tightBoundingRect.width * view.timeScale) / 2 - timeInk.tightBoundingRect.x * view.timeScale
                    opacity: view.timeLifted ? 0 : 1
                    animated: view.animated
                    text: Session.shortTime(view.date)
                    transformOrigin: Item.TopLeft
                    scale: view.timeScale
                    font.features: {
                        "tnum": 1
                    }
                }

                // The day, under the time once open.
                Text {
                    id: dateLabel

                    x: (timePart.openWidth - implicitWidth) / 2
                    y: timeLabel.implicitHeight * view.timeScale
                    opacity: view.openness * view.openness
                    visible: opacity > 0
                    text: {
                        const day = view.date.toLocaleDateString(Session.regionalFormats, "ddd d MMM");
                        return day.charAt(0).toUpperCase() + day.slice(1);
                    }
                    color: Colors.secondary
                    font.family: Metrics.font
                    font.pixelSize: Metrics.text.small
                    font.weight: Font.DemiBold
                }

                TextMetrics {
                    id: timeInk

                    font: timeLabel.font
                    text: timeLabel.text
                }
            }

            // An OSD in the open island, in the time's place. Kept whole while it goes, the
            // way it was.
            IslandPart {
                id: osdPart

                shown: view.osdInside
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence)
                openWidth: 2 * Math.ceil(osdInside.implicitWidth / 2) + 2 * Metrics.spacing.large
                openHeight: Metrics.islandBlockHeight

                // The screenshot just taken opens in its viewer.
                IslandBlock {
                    anchors.fill: parent
                    interactive: view.interactive && view.osdInside && view.bar.osdShown.kind === "screenshot"
                    onClicked: view.osdClicked()
                }

                IslandOsd {
                    id: osdInside

                    x: (parent.width - implicitWidth) / 2
                    y: (parent.height - implicitHeight) / 2
                    shown: osdPart.presence > 0
                    content: view.bar.osdShown
                }

            }

            IslandPart {
                id: padlockPart

                shown: view.padlock
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence)
                // A whole, even number of pixels, the glyph on a whole pixel inside: its cell
                // is a fraction wide, and alone in the island's circle it would be drawn a
                // pixel to the left of the middle.
                openWidth: 2 * Math.round(padlockIcon.implicitWidth / 2)
                openHeight: padlockIcon.implicitHeight

                Icon {
                    id: padlockIcon

                    x: Math.round((parent.width - implicitWidth) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    color: Colors.primary
                    size: Metrics.text.title
                }

            }

            PasswordSquares {
                id: squaresPart

                count: view.typed
                checking: view.checking
                alert: view.lockError !== "" && view.typed === 0
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence + padlockPart.presence)
            }

            IslandChips {
                id: chips

                bar: view.bar
                shown: view.chipsShown
                notificationsShown: view.chipsShown && view.timeShown
                updatesShown: view.updatesShown
                room: 1 - view.openWidthShare
                animated: view.animated
                interactive: view.interactive && clockFace.shown
                lead: Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence)
            }

            IslandSide {
                id: musicSide

                shown: view.open
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chips.presence)
                openWidth: view.sideWidth
                line: IslandMusicLine {
                    id: musicLine

                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    presence: coverPart.arrival
                    interactive: view.interactive && view.open && Music.player !== null
                    onClicked: view.musicClicked()
                }
                row: IslandControls {
                    id: controlBlock

                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    bar: view.bar
                    interactive: view.interactive && view.open
                    lifted: view.controlsLifted
                }
            }

            IslandEqualizer {
                id: equalizerPart

                shown: view.musicShown
                room: 1 - view.openWidthShare
                animated: view.animated
                lifted: view.musicLifted || view.unfolded
                live: view.live
                gap: (Metrics.spacing.normal - slack) * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chips.presence + musicSide.presence)

                HoverHandler {
                    id: equalizerHover

                    enabled: view.interactive
                }

            }

            LockWords {
                label: view.lockError
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + windowSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chips.presence + musicSide.presence + equalizerPart.presence)
            }

        }

        // The cover and the equalizer while the island opens, is open or closes: each flies
        // from its end of the island to its place on the music's line, across with the
        // island's width and down with its height, the cover squaring off and the bars
        // standing up straight on the way. The ends keep them otherwise.
        CoverArt {
            id: flyingCover

            readonly property real size: view.musicSlot * coverPart.arrival
            readonly property real restX: coverPart.placeX + coverPart.presence * view.musicSlot / 2
            readonly property real lineX: musicSide.placeX + musicSide.presence * (musicLine.coverX + view.musicSlot / 2)

            x: clockRow.x + restX + (lineX - restX) * view.flightAcross - size / 2
            y: clockRow.y + view.flightY(view.musicSlot / 2) - size / 2
            width: size
            height: size
            radius: size / 2 + (musicLine.radius - size / 2) * view.flightDown
            visible: view.unfolded && !view.musicLifted && size > 0
            decodeSize: 2 * Math.ceil(view.musicSlot)
            rolls: view.animated && visible

            // The last cover stays while it goes after the player quits.
            Binding on source {
                when: Music.player !== null
                value: Music.player?.trackArtUrl ?? ""
                restoreMode: Binding.RestoreNone
            }

        }

        Item {
            id: flyingEqualizer

            readonly property real restX: equalizerPart.placeX + equalizerPart.presence * view.musicSlot / 2
            readonly property real lineX: musicSide.placeX + musicSide.presence * (musicLine.equalizerX + view.musicSlot / 2)

            x: clockRow.x + restX + (lineX - restX) * view.flightAcross - width / 2
            y: clockRow.y + view.flightY(view.musicSlot / 2) - height / 2
            width: view.musicSlot
            height: view.musicSlot
            visible: view.unfolded && !view.musicLifted && equalizerPart.arrival > 0

            // In its slot as in the island's end (IslandEqualizer).
            Equalizer {
                id: flyingBars

                x: 2 * Math.round((parent.width - width) / 4)
                y: (parent.height - height) / 2
                scale: equalizerPart.arrival
                roundness: 1 - view.flightDown
                playing: Music.playing
                running: view.live && flyingEqualizer.visible && MusicSettings.equalizer
            }

        }

    }

    // Its content changes at once from one OSD to the next, never fading out for it: the
    // face eases to the new size itself, and the pill around it cuts what doesn't fit yet.
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
            // Kept whole while the face goes, and while a card hides the island: the card
            // folds back onto the OSD's size, not an empty island's.
            shown: osdFace.presence > 0
            content: view.bar.osdShown
        }

        Behavior on contentWidth {
            enabled: view.animated && osdFace.shown

            Anim {
                token: Motion.resize.normal
            }

        }

    }

}
