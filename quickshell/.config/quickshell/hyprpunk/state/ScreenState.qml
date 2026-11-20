import QtQuick
import Quickshell
import Quickshell.Hyprland

// What belongs to one screen, made by ShellState for each of them and found with
// ShellState.forScreen(): who holds its island, and the way to its surfaces.
QtObject {
    id: screenState

    required property ShellScreen modelData
    readonly property ShellScreen screen: modelData
    // A window is fullscreen on the screen, over the shell's window (which stays in the
    // layer under fullscreen windows): the panels you ask for don't open there, the
    // prompts do (they show once it's gone). Maximized windows don't count, they leave
    // the bar its room.
    readonly property bool fullscreen: {
        const monitor = Hyprland.monitorFor(screen);
        const workspace = monitor !== null ? monitor.activeWorkspace : null;
        return workspace !== null && workspace.toplevels.values.some((toplevel) => {
            return toplevel.wayland !== null && toplevel.wayland.fullscreen;
        });
    }
    // The island's claims, in the order they came: [{ name, rank, passing }]. Rank 1 is a
    // prompt an app waits on, 2 a panel you open, 3 something that happened: a card that
    // comes on its own (the notifications, the AirPods) or an OSD. A passing one only
    // matters while it shows (a level OSD): it goes as soon as something takes its place.
    property var claims: []
    readonly property string islandOwner: ownerOf(claims)
    // The glass drawn straight on its desktop (BlurShape), for the blur behind it.
    property var blurShapes: []

    function addBlurShape(shape) {
        blurShapes = blurShapes.concat([shape]);
    }

    function removeBlurShape(shape) {
        blurShapes = blurShapes.filter((listed) => {
            return listed !== shape;
        });
    }

    // Its bar (Bar), for the lock screen to start from where its pills are.
    property Item bar: null
    // The surfaces you can open on this screen, by name (the IPC's panel names).
    property var surfaces: ({
    })

    // Who the island shows, the one rule for all of them: the first prompt, which can't be
    // pushed away; else the panel; else the latest thing that happened, over the ones it
    // interrupted, which come back once it's gone.
    function ownerOf(list) {
        const ranked = (rank) => {
            return list.filter((claim) => {
                return claim.rank === rank;
            });
        };
        const happened = ranked(3);
        const owner = ranked(1)[0] ?? ranked(2)[0] ?? happened[happened.length - 1];
        return owner !== undefined ? owner.name : "";
    }

    // False when the island won't have it: a panel while a prompt waits for an answer, or
    // something passing while it can't show. A prompt or a panel takes the island from the
    // panel there, which closes. Something that happens again comes back on top.
    function claim(name, rank, passing) {
        if (rank !== 3 && claims.some((claim) => {
            return claim.name === name;
        }))
            return true;

        if (rank === 2 && prompting())
            return false;

        const next = claims.filter((claim) => {
            return claim.name !== name && (rank === 3 || claim.rank !== 2);
        }).concat([{
            "name": name,
            "rank": rank,
            "passing": passing === true
        }]);
        const owner = ownerOf(next);
        claims = next.filter((claim) => {
            return !claim.passing || claim.name === owner;
        });
        return claims.some((claim) => {
            return claim.name === name;
        });
    }

    function release(name) {
        if (claims.some((claim) => {
            return claim.name === name;
        }))
            claims = claims.filter((claim) => {
            return claim.name !== name;
        });

    }

    // A prompt holds the island: the panels and the calendar stay shut.
    function prompting() {
        return claims.some((claim) => {
            return claim.rank === 1;
        });
    }

    // A surface answers open(), close() and toggle() through requestAction(action, origin),
    // and "return" when a panel it opened hands the island back.
    function register(name, surface) {
        surfaces[name] = surface;
    }

    function unregister(name, surface) {
        if (surfaces[name] === surface)
            delete surfaces[name];

    }

    // origin: the surface asking (the launcher for the menus it lists). Only the prompts open
    // over a fullscreen window. The settings window isn't a screen's: ShellState has it.
    function request(name, action, origin) {
        const surface = surfaces[name] ?? ShellState.surfaces[name];
        if (surface === undefined || (action !== "close" && fullscreen && surface.keptUnderFullscreen === false))
            return ;

        surface.requestAction(action, origin ?? "");
    }

    function open(name, origin) {
        request(name, "open", origin);
    }

    function close(name) {
        request(name, "close");
    }

    function toggle(name) {
        request(name, "toggle");
    }

}
