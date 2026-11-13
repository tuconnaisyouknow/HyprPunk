pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager's VPNs (plugin ones and WireGuard), which Quickshell.Networking doesn't
// tell: the control center's VPN tab lists and drives them, and the bar's network icon
// turns into a padlock while one is on.
Singleton {
    id: vpn

    // Every VPN profile, by name: [{name, uuid, type, autoconnect, state, device}], type
    // being "vpn" or "wireguard" and state "activated", "activating", "deactivating" or "".
    property var profiles: []
    // The ones up or coming up.
    readonly property var connections: profiles.filter((profile) => {
        return profile.state === "activated" || profile.state === "activating";
    })
    // The one that's up, else one coming up, else null.
    readonly property var connection: connections.find((connection) => {
        return connection.state === "activated";
    }) || connections.find((connection) => {
        return connection.state === "activating";
    }) || null
    readonly property bool active: connection !== null && connection.state === "activated"
    readonly property bool connecting: connection !== null && !active
    // The VPNs being brought up from here, by uuid: NetworkManager only shows a plugin
    // VPN as activating once it has its secrets.
    property var pending: ({
    })
    // Why each VPN last failed to come up, by uuid.
    property var errors: ({
    })
    // The VPN whose password the tab asks for, "" for none.
    property string passwordUuid: ""
    property bool importing: false
    property string importError: ""

    function profile(uuid) {
        return profiles.find((profile) => {
            return profile.uuid === uuid;
        }) || null;
    }

    // How a VPN is doing, in words, for its row and its details.
    function status(profile) {
        if (profile.state === "deactivating")
            return "Disconnecting…";

        if (profile.state === "activating" || pending[profile.uuid])
            return "Connecting…";

        if (profile.state === "activated")
            return "Connected";

        return errors[profile.uuid] !== undefined ? "Couldn't connect" : "Not connected";
    }

    function setPending(uuid, value) {
        const next = Object.assign({
        }, pending);
        if (value)
            next[uuid] = true;
        else
            delete next[uuid];
        pending = next;
    }

    function setError(uuid, message) {
        const next = Object.assign({
        }, errors);
        if (message !== "")
            next[uuid] = message;
        else
            delete next[uuid];
        errors = next;
    }

    // The password goes on stdin, "" for none.
    function connect(uuid, password) {
        setError(uuid, "");
        setPending(uuid, true);
        if (passwordUuid === uuid)
            passwordUuid = "";

        const command = [Session.scripts + "/vpnctl.sh", "up", uuid];
        if (password !== "")
            command.push("--password");

        upProcess.createObject(vpn, {
            "uuid": uuid,
            "password": password,
            "command": command
        });
    }

    function disconnect(uuid) {
        setError(uuid, "");
        if (passwordUuid === uuid)
            passwordUuid = "";

        Quickshell.execDetached(["nmcli", "connection", "down", "uuid", uuid]);
    }

    // A click on the VPN: down when it's up or coming up, up otherwise.
    function toggle(uuid) {
        const target = profile(uuid);
        if (target === null)
            return ;

        if (target.state === "activated" || target.state === "activating")
            disconnect(uuid);
        else if (!pending[uuid])
            connect(uuid, "");
    }

    function setAutoconnect(uuid, enabled) {
        Quickshell.execDetached(["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", enabled ? "yes" : "no"]);
    }

    function remove(uuid) {
        if (passwordUuid === uuid)
            passwordUuid = "";

        Quickshell.execDetached(["nmcli", "connection", "delete", "uuid", uuid]);
    }

    // Picks a configuration file (WireGuard's .conf, OpenVPN's .ovpn…) and adds it.
    function importFile() {
        if (importing)
            return ;

        importError = "";
        importing = true;
        importProcess.running = true;
    }

    // nmcli's terse fields, split on the colons it doesn't escape.
    function fields(line) {
        const result = [""];
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length)
                result[result.length - 1] += line[++i];
            else if (line[i] === ":")
                result.push("");
            else
                result[result.length - 1] += line[i];
        }
        return result;
    }

    Process {
        id: listProcess

        command: ["nmcli", "-t", "-f", "TYPE,UUID,AUTOCONNECT,STATE,DEVICE,NAME", "connection", "show"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = [];
                for (const line of text.trim().split("\n")) {
                    const values = vpn.fields(line);
                    if (values.length >= 6 && (values[0] === "vpn" || values[0] === "wireguard"))
                        profiles.push({
                        "type": values[0],
                        "uuid": values[1],
                        "autoconnect": values[2] === "yes",
                        "state": values[3],
                        "device": values[4],
                        "name": values.slice(5).join(":")
                    });

                }
                profiles.sort((a, b) => {
                    return a.name.localeCompare(b.name);
                });
                if (JSON.stringify(profiles) !== JSON.stringify(vpn.profiles))
                    vpn.profiles = profiles;

            }
        }

    }

    // Any NetworkManager change lists them again, a burst of changes only once.
    TiedProcess {
        program: ["nmcli", "monitor"]
        running: true

        stdout: SplitParser {
            onRead: refresh.restart()
        }

    }

    Timer {
        id: refresh

        interval: 250
        onTriggered: listProcess.running = true
    }

    // One per VPN brought up, so two can come up at once.
    Component {
        id: upProcess

        Process {
            id: process

            property string uuid
            property string password

            running: true
            stdinEnabled: password !== ""
            onStarted: {
                if (password !== "") {
                    write(password + "\n");
                    password = "";
                }
            }
            onExited: (code) => {
                vpn.setPending(uuid, false);
                if (code === 3)
                    vpn.passwordUuid = uuid;
                else if (code !== 0)
                    vpn.setError(uuid, errorText.text.trim() || "The VPN couldn't connect");
                refresh.restart();
                process.destroy();
            }

            stderr: StdioCollector {
                id: errorText
            }

        }

    }

    Process {
        id: importProcess

        // The file chooser speaks the current locale, not the shell's at startup.
        environment: Session.localeEnvironment
        command: ["sh", "-c", "file=$(zenity --file-selection --title='Import a VPN' --file-filter='VPN configurations | *.conf *.ovpn *.pcf' --file-filter='All files | *') || exit 0; exec \"$1\" import \"$file\"", "sh", Session.scripts + "/vpnctl.sh"]
        onExited: (code) => {
            vpn.importing = false;
            if (code !== 0)
                vpn.importError = importErrors.text.trim().split("\n").pop() || "The file couldn't be imported";

            refresh.restart();
        }

        stderr: StdioCollector {
            id: importErrors
        }

    }

}
