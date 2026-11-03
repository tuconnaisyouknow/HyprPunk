import QtQuick
import QtQuick.Shapes

// The music as one smooth wave rising from its bottom edge, for the desktop's visualizer
// and the lock screen. It fades in while a player plays and away when it stops.
Shape {
    id: wave

    // A CavaLevels.
    required property var music

    // Low notes in the middle, mirrored towards the edges, so the wave stays symmetric.
    // The ends are pinned to the floor so it melts into the bottom of the screen.
    function wavePath(levels, width, height) {
        if (levels.length === 0)
            return "M 0 " + height + " L " + width + " " + height + " Z";

        const values = levels.slice().reverse().concat(levels);
        const points = [{
            "x": 0,
            "y": height
        }];
        for (let i = 0; i < values.length; i++) {
            const t = (i + 1) / (values.length + 1);
            // Softens the sides, otherwise the highs would stand up as walls at the edges
            const envelope = Math.pow(Math.sin(Math.PI * t), 0.6);
            points.push({
                "x": t * width,
                "y": height - Math.max(0, Math.min(1, values[i])) * envelope * (height - 4)
            });
        }
        points.push({
            "x": width,
            "y": height
        });
        // Catmull-Rom through the levels, written as Béziers: no corner anywhere
        let path = "M " + points[0].x + " " + points[0].y;
        for (let i = 0; i < points.length - 1; i++) {
            const p0 = points[Math.max(0, i - 1)];
            const p1 = points[i];
            const p2 = points[i + 1];
            const p3 = points[Math.min(points.length - 1, i + 2)];
            path += " C " + (p1.x + (p2.x - p0.x) / 6) + " " + (p1.y + (p2.y - p0.y) / 6) + " " + (p2.x - (p3.x - p1.x) / 6) + " " + (p2.y - (p3.y - p1.y) / 6) + " " + p2.x + " " + p2.y;
        }
        return path + " Z";
    }

    preferredRendererType: Shape.CurveRenderer
    opacity: music.playing ? 1 : 0

    ShapePath {
        strokeWidth: -1

        fillGradient: LinearGradient {
            x1: 0
            y1: 0
            x2: 0
            y2: wave.height

            GradientStop {
                position: 0
                color: Theme.alpha(Theme.mauve, 0.85)
            }

            GradientStop {
                position: 1
                color: Theme.alpha(Theme.lavender, 0.15)
            }

        }

        PathSvg {
            path: wave.wavePath(wave.music.levels, wave.width, wave.height)
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: 600
            easing.type: Easing.InOutSine
        }

    }

}
