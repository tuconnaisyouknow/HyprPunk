import QtQuick
import Quickshell
import qs.theme

// An icon on its way to another of its family (Icon, Icons.family). Both are the font's
// own glyphs, drawn just as the icon at rest so nothing moves or thickens when it hands
// over; only what shows of each changes. The new icon spreads from where the two differ:
// a battery's or a Wi-Fi's level rises or falls, a slash cuts across, a padlock or a bolt
// opens out where it sits, the player's buttons change from their middle. The volume
// slides instead: its speaker moves where Material centres it, and its waves come and go
// around it.
Item {
    id: morph

    // The icon at rest it draws for.
    required property Text glyph
    // The icon it comes from and the one it goes to, and how far it has gone.
    property string from
    property string to
    property real progress: 0
    // The volume's speaker and waves where it set off from, when it turned on its way to
    // somewhere else (a wheel turned on and on).
    property var start: null
    readonly property bool running: travel.running

    // The font's square (960 units, y going down) in the glyph's box: as wide as the
    // font is tall, standing on the baseline, in the middle.
    readonly property real unit: glyph.font.pixelSize / 960
    readonly property point square: Qt.point((glyph.width - glyph.contentWidth) / 2, glyph.baselineOffset - glyph.font.pixelSize)
    readonly property string kind: Icons.family[from] ?? ""
    readonly property bool sliding: kind === "volume" && from !== "volume_off" && to !== "volume_off"

    // The top of each battery's charge, measured on the font in its square.
    readonly property var batteryLevel: ({
        "battery_0_bar": 800,
        "battery_1_bar": 720,
        "battery_2_bar": 640,
        "battery_3_bar": 560,
        "battery_4_bar": 480,
        "battery_5_bar": 400,
        "battery_6_bar": 320,
        "battery_full": 240,
        "battery_charging_20": 722,
        "battery_charging_30": 644,
        "battery_charging_50": 560,
        "battery_charging_60": 480,
        "battery_charging_80": 400,
        "battery_charging_90": 320,
        "battery_charging_full": 800
    })
    // Where a Wi-Fi's fill spreads from.
    readonly property point wifiTip: Qt.point(480, 790)
    // A volume icon is its speaker and, past the speaker's mouth, its waves. Material
    // moves the speaker right as the waves go, so what's left stays centred, further at
    // the smallest optical sizes; the waves show out to a distance from volume_up's
    // middle, which moves with the speaker.
    readonly property real mouth: 515
    readonly property real small: Math.max(0, Math.min(1, (24 - glyph.font.variableAxes.opsz) / 4))
    readonly property var voices: ({
        "volume_up": {
            "shift": 0,
            "reach": 430
        },
        "volume_down": {
            "shift": 80 + 16 * small,
            "reach": 220
        },
        "volume_mute": {
            "shift": 160 - 16 * small,
            "reach": 100
        }
    })
    // The speaker and waves on their way, from where they set off to the icon's place.
    readonly property var voice: {
        const start = morph.start ?? voices[from] ?? voices.volume_up;
        const end = voices[to] ?? voices.volume_up;
        return {
            "shift": start.shift + (end.shift - start.shift) * progress,
            "reach": start.reach + (end.reach - start.reach) * progress
        };
    }
    // Where the new icon shows, in the font's square: a band across a direction or around
    // a point, from where it starts to how far it has gone.
    readonly property var band: {
        if (!running || sliding)
            return null;

        const whole = spread(from, to);
        return {
            "circular": whole.circular,
            "origin": whole.origin,
            "from": whole.from,
            "to": whole.from + (whole.to - whole.from) * progress
        };
    }

    // Sets off from the icon shown to another, or turns to it on the way.
    function go(shown, icon) {
        if (running && icon === from) {
            // Back where it came from: the same way, in reverse.
            [from, to] = [to, from];
            start = null;
            progress = 1 - progress;
        } else {
            // Somewhere else: the volume carries on from where it stands, any other icon
            // from the one it was heading to.
            start = running && sliding ? voice : null;
            from = shown;
            to = icon;
            progress = 0;
        }
        travel.duration = Motion.move.normal.duration * (1 - progress);
        travel.restart();
    }

    function stop() {
        travel.stop();
        start = null;
    }

    // A pixel in the font's units: a band starts and ends that far past the edges it
    // goes between, so its soft edge never lands on an icon's own.
    function pixel() {
        return 1 / unit;
    }

    // Out from a point, as far as the icons reach from it.
    function around(point, reach) {
        return {
            "circular": true,
            "origin": point,
            "from": -pixel(),
            "to": reach + pixel()
        };
    }

    // Down a slash, from its top left to its bottom right, as far as the icon goes.
    function slash(first, last) {
        return {
            "circular": false,
            "origin": Qt.point(Math.SQRT1_2, Math.SQRT1_2),
            "from": first - pixel(),
            "to": last + pixel()
        };
    }

    function wifiLevel(icon) {
        return icon === "signal_wifi_0_bar" ? 0 : icon.startsWith("signal_wifi_4") ? 4 : parseInt(icon.match(/_(\d)_bar/)[1]);
    }

    // Where a change from one icon to the other happens, and how far the icons reach from
    // there at any fill and optical size, measured on the font.
    function spread(from, to) {
        const middle = Qt.point(480, 480);
        if (kind === "volume")
            return slash(134, 1214);

        if (kind === "battery") {
            if (from.includes("charging") !== to.includes("charging"))
                return around(Qt.point(680, 720), 690);

            // A line rising or falling from one charge to the other.
            const rising = batteryLevel[to] < batteryLevel[from];
            return {
                "circular": false,
                "origin": Qt.point(0, -1),
                "from": -batteryLevel[from] + (rising ? -pixel() : pixel()),
                "to": -batteryLevel[to] + (rising ? pixel() : -pixel())
            };
        }
        if (kind === "wifi") {
            if ((from === "signal_wifi_off") !== (to === "signal_wifi_off"))
                return slash(112, 1245);

            if (from.includes("lock") !== to.includes("lock"))
                return around(Qt.point(760, 680), 810);

            // A ring sweeping the whole icon out from the tip as the level rises, or back
            // in as it falls: each level draws its frame a touch differently, so all of it
            // changes, and the level moves as the ring goes through it.
            const rising = wifiLevel(to) > wifiLevel(from);
            const whole = around(wifiTip, 660);
            return {
                "circular": true,
                "origin": wifiTip,
                "from": rising ? whole.from : whole.to,
                "to": rising ? whole.to : whole.from
            };
        }
        // Brightness spreads out to its ring, which the medium icon only half draws.
        if (kind === "brightness")
            return around(middle, 240);

        return around(middle, kind === "play" ? 380 : 600);
    }

    width: Math.ceil(glyph.width)
    height: Math.ceil(glyph.height)
    visible: running

    NumberAnimation {
        id: travel

        target: morph
        property: "progress"
        to: 1
        easing.type: Motion.move.normal.easing
        onFinished: morph.start = null
    }

    // The icon as the glyph at rest draws it.
    component Glyph: Text {
        property string icon

        width: morph.glyph.width
        height: morph.glyph.height
        text: morph.running ? icon : ""
        color: morph.glyph.color
        font: morph.glyph.font
        renderType: morph.glyph.renderType
        style: morph.glyph.style
        styleColor: morph.glyph.styleColor
        horizontalAlignment: morph.glyph.horizontalAlignment
        verticalAlignment: morph.glyph.verticalAlignment
    }

    // The new drawing inside a band, over the old one outside it if any, or over all of it
    // by an amount. The band is in the font's square; the item it masks stands right of
    // the glyph's box by offset.
    component Reveal: ShaderEffect {
        property var region: null
        property real offset: 0
        property var before: null
        property var after: null
        property real fade: 0
        readonly property vector2d size: Qt.vector2d(width, height)
        readonly property real circular: region?.circular ? 1 : 0
        readonly property point origin: !region ? Qt.point(0, 0) : region.circular ? Qt.point(morph.square.x - offset + region.origin.x * morph.unit, morph.square.y + region.origin.y * morph.unit) : region.origin
        // Along a direction, the band runs from where the square's corner stands on it.
        readonly property real corner: !region || region.circular ? 0 : (morph.square.x - offset) * region.origin.x + morph.square.y * region.origin.y
        // No band: nowhere near the icon.
        readonly property real from: region ? corner + region.from * morph.unit : -1e6
        readonly property real to: region ? corner + region.to * morph.unit : -1e6

        fragmentShader: Qt.resolvedUrl(Quickshell.shellPath("shaders/reveal.frag.qsb"))
    }

    // One end of the way. A volume that slides is its own speaker and waves moved where
    // they stand on the way, so it leaves from its own drawing and lands on the next's.
    component Side: Item {
        id: side

        property string icon
        readonly property bool parted: morph.sliding && morph.voices[icon] !== undefined
        readonly property real shift: parted ? morph.voices[icon].shift : 0
        // Where its speaker's mouth ends in the glyph's box, on a whole pixel so the waves'
        // mask lies on the pixels the glyph is drawn on.
        readonly property real cut: Math.round(morph.square.x + (morph.mouth + shift) * morph.unit)

        anchors.fill: parent

        Item {
            x: (morph.voice.shift - side.shift) * morph.unit
            width: parent.width
            height: parent.height
            visible: side.parted

            Item {
                width: side.cut
                height: parent.height
                clip: true

                Glyph {
                    icon: side.parted ? side.icon : ""
                }

            }

            // Its waves, out to their reach.
            Item {
                x: side.cut
                width: parent.width - side.cut
                height: parent.height
                clip: true
                layer.enabled: side.parted && morph.running
                layer.smooth: false
                layer.samplerName: "after"

                Glyph {
                    x: -side.cut
                    icon: side.parted ? side.icon : ""
                }

                layer.effect: Reveal {
                    offset: side.cut
                    region: ({
                        "circular": true,
                        "origin": Qt.point(480 + side.shift, 480),
                        "from": -morph.pixel(),
                        "to": morph.voice.reach
                    })
                }

            }

        }

        Glyph {
            icon: side.parted ? "" : side.icon
        }

    }

    Side {
        id: leaving

        icon: morph.from
    }

    Side {
        id: arriving

        icon: morph.to
    }

    // Both ends mixed across the band, each pixel as it is in one or the other. A volume
    // that slides goes from one end to the other everywhere at once.
    Reveal {
        anchors.fill: parent
        region: morph.band
        fade: morph.sliding ? morph.progress : 0

        before: ShaderEffectSource {
            sourceItem: morph.running ? leaving : null
            hideSource: true
            smooth: false
        }

        after: ShaderEffectSource {
            sourceItem: morph.running ? arriving : null
            hideSource: true
            smooth: false
        }

    }

}
