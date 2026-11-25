import QtQuick
import qs.components
import qs.config
import qs.modules.workspaces
import qs.services
import qs.theme

// What the island shows: one row of parts that open and close in place (IslandPart), the
// time between the music's cover and equalizer at its round ends, or the padlock in its
// place while the lock has it, the password's squares in the padlock's place as you type,
// the time's chips and why a try failed, or an OSD over it as another face (IslandFace).
// Alone in the bar, it opens under the pointer (open), and the time stays: it grows a
// little over the date between two sides as wide as each other, so it stays in the middle
// (IslandSide). On its left your workspaces over the wallpaper and its theme, on its right
// the control center's icons over the machine's load. The music's ends make way, the chips
// move under the date, and an OSD takes the time's place there rather than closing it.
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
    // How far the chips have gone from their place in the row to theirs under the date,
    // across and down, never past either: the island going past its size doesn't move
    // the time they sit under.
    readonly property real chipsAcross: Math.max(0, Math.min(1, openWidthShare))
    readonly property real chipsDown: Math.max(0, Math.min(1, openness))
    // Open, or on its way open or closed.
    readonly property bool unfolded: open || openingWidth.running || opening.running
    // An OSD while the island is open: in the time's place, the island staying open.
    property bool osdInside: false
    // The update packages waiting, as a chip (Bar.islandOnly).
    property bool updatesShown: false
    // Each side of the open time: room for the workspaces and the icons, and for a title
    // under them.
    readonly property real sideWidth: 2 * Math.ceil(Math.max(200, workspaceSwitcher.fullWidth + 2 * Metrics.spacing.large, controlBlock.implicitWidth) / 2)
    // The cover's and the equalizer's slot, and the cover as it grows in or shrinks away.
    readonly property real musicSlot: Metrics.pillHeight - 2 * Metrics.islandMusicInset
    readonly property real coverSize: musicSlot * coverPart.arrival
    // How much bigger the time is, open.
    readonly property real timeScale: 1 + openness * (Metrics.text.heading / Metrics.text.title - 1)
    // The time's place at rest, even, eased as the minutes change its ink. Open, its block
    // around the time and the date, even too.
    property real timeWidth: 2 * Math.ceil(timeInk.tightBoundingRect.width / 2)
    readonly property real openTimeWidth: 2 * Math.ceil(Math.max(timeInk.tightBoundingRect.width * Metrics.text.heading / Metrics.text.title, dateLabel.implicitWidth, chips.width) / 2) + 2 * Metrics.spacing.large

    signal timeClicked()
    // A click on the screenshot an OSD shows in the open island.
    signal osdClicked()
    // The time, where the lock's clock leaves from.
    readonly property Item timeItem: timeLabel
    // Between two faces.
    readonly property bool swapping: clockFace.moving || osdFace.moving || openingWidth.running || opening.running
    // Where the time starts, from the view's left edge.
    readonly property real timeX: clockFace.x + timePart.placeX
    // Where the cover and the equalizer's slot are in the island's ends, from the view's
    // corner, and the cover's corners.
    readonly property real coverX: clockFace.x + clockRow.x + coverPart.placeX + (coverPart.presence * musicSlot - coverSize) / 2
    readonly property real coverY: clockFace.y + clockRow.y + (clockRow.height - coverSize) / 2
    readonly property real coverRadius: coverSize / 2
    readonly property real equalizerX: clockFace.x + clockRow.x + equalizerPart.placeX + (equalizerPart.presence - 1) * musicSlot / 2
    readonly property real equalizerY: clockFace.y + clockRow.y + (clockRow.height - musicSlot) / 2
    // Where the equalizer's bars sit in its slot.
    readonly property real equalizerInset: equalizerPart.slack
    // The pointer is on a chip with its own click (the recording, the updates).
    readonly property bool chipHovered: chips.chipHovered
    // The pointer is on the cover or the equalizer, where a click opens the player.
    readonly property bool musicHovered: coverHover.hovered || equalizerHover.hovered
    readonly property real presence: clockFace.presence + osdFace.presence

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

            IslandCover {
                id: coverPart

                shown: view.musicShown
                room: 1 - view.openWidthShare
                animated: view.animated
                lifted: view.musicLifted
                gap: 0

                HoverHandler {
                    id: coverHover

                    enabled: view.interactive
                }

            }

            IslandSide {
                id: wallpaperSide

                shown: view.open
                animated: view.animated
                gap: Metrics.spacing.normal * coverPart.presence
                openWidth: view.sideWidth
                upper: WorkspaceSwitcher {
                    id: workspaceSwitcher

                    x: Math.round((view.sideWidth - implicitWidth) / 2)
                    y: (Metrics.islandBlockHeight - implicitHeight) / 2
                    screen: view.bar.screen
                    compact: true
                    interactive: view.interactive && view.open
                }
                lower: IslandWallpaperLine {
                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    interactive: view.interactive && view.open
                    onClicked: view.bar.screenState.toggle("wallpaper")
                }
            }

            IslandPart {
                id: timePart

                shown: view.timeShown && !view.osdInside
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence)
                // Its place is the time's ink, so the gaps on both sides are measured from
                // what's drawn: the digits fill their cells unevenly (a 1 leaves far more
                // room on its right than a 0), and the cover and the equalizer sat unevenly
                // around it, differently from one minute to the next.
                // Rounded up to an even width, the ink in its middle. Open, its block's.
                openWidth: view.timeWidth + view.openWidthShare * (view.openTimeWidth - view.timeWidth)
                openHeight: timeLabel.implicitHeight * view.timeScale + view.openness * (dateLabel.implicitHeight + chips.presence * (Metrics.spacing.small + chips.height))
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
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence)
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
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence)
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
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence + padlockPart.presence)
            }

            // The chips' place in the row, which they leave for theirs under the date as
            // the island opens.
            Item {
                id: chipsPlace

                readonly property real presence: chips.presence * (1 - view.chipsAcross)

                width: chips.width * (1 - view.chipsAcross)
                height: chips.height
                anchors.verticalCenter: parent.verticalCenter
            }

            IslandSide {
                id: statsSide

                shown: view.open
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chipsPlace.presence)
                openWidth: view.sideWidth
                upper: IslandControls {
                    id: controlBlock

                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    bar: view.bar
                    interactive: view.interactive && view.open
                    lifted: view.controlsLifted
                }
                lower: IslandStatsLine {
                    width: view.sideWidth
                    height: Metrics.islandBlockHeight
                    interactive: view.interactive && view.open
                    onClicked: view.bar.screenState.toggle("systemmonitor")
                }
            }

            IslandEqualizer {
                id: equalizerPart

                shown: view.musicShown
                room: 1 - view.openWidthShare
                animated: view.animated
                lifted: view.musicLifted
                live: view.live
                gap: (Metrics.spacing.normal - slack) * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chipsPlace.presence + statsSide.presence)

                HoverHandler {
                    id: equalizerHover

                    enabled: view.interactive
                }

            }

            LockWords {
                label: view.lockError
                animated: view.animated
                gap: Metrics.spacing.normal * Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence + chipsPlace.presence + statsSide.presence + equalizerPart.presence)
            }

        }

        // After the time in the row, or centred under the date in the open island: the same
        // chips going from one place to the other, the updates and the notifications kept
        // in sight. An OSD in the open island has the time's place, and they leave it.
        IslandChips {
            id: chips

            readonly property real restX: clockRow.x + chipsPlace.x
            readonly property real restY: clockRow.y + (clockRow.height - height) / 2
            readonly property real openX: clockRow.x + (clockRow.width - width) / 2
            readonly property real openY: clockRow.y + timePart.y + timeLabel.implicitHeight * view.timeScale + dateLabel.implicitHeight + Metrics.spacing.small

            x: restX + (openX - restX) * view.chipsAcross
            y: restY + (openY - restY) * view.chipsDown
            bar: view.bar
            shown: view.chipsShown && !view.osdInside
            notificationsShown: view.chipsShown && view.timeShown && !view.osdInside
            updatesShown: view.updatesShown && !view.osdInside
            animated: view.animated
            interactive: view.interactive && clockFace.shown
            // Under the date, nothing before them to part them from.
            lead: Math.min(1, coverPart.presence + wallpaperSide.presence + timePart.presence + osdPart.presence + padlockPart.presence + squaresPart.presence) * (1 - view.chipsAcross)
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
