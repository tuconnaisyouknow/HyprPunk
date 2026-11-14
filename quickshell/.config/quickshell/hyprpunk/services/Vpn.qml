pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

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

        FileChooser.ask({
            "title": "Import a VPN",
            "filters": [{
                "name": "VPN configurations",
                "globs": ["*.conf", "*.ovpn", "*.pcf"]
            }, {
                "name": "All files",
                "globs": ["*"]
            }],
            "filter": 0
        }, (paths) => {
            importError = "";
            importing = true;
            importProcess.command = [Session.scripts + "/vpnctl.sh", "import", paths[0]];
            importProcess.running = true;
        });
    }

    // onDone({serviceType, server, address}): what the profile's full listing tells,
    // the address only while it's up.
    function readDetails(uuid, onDone) {
        detailsProcess.createObject(vpn, {
            "uuid": uuid,
            "onDone": onDone
        });
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

    // One per reading, so a page switching VPN never gets the last one's details.
    Component {
        id: detailsProcess

        Process {
            id: reader

            property string uuid
            property var onDone

            // One "key:value" a line; the values keep their colons (an endpoint's port).
            command: ["nmcli", "-t", "connection", "show", "uuid", uuid]
            running: true

            stdout: StdioCollector {
                onStreamFinished: {
                    const values = {
                    };
                    for (const line of text.split("\n")) {
                        const colon = line.indexOf(":");
                        if (colon > 0)
                            values[line.slice(0, colon)] = line.slice(colon + 1);

                    }
                    // "org.freedesktop.NetworkManager.openvpn" reads OpenVPN.
                    const service = (values["vpn.service-type"] || "").split(".").pop();
                    const names = {
                        "openvpn": "OpenVPN",
                        "openconnect": "OpenConnect",
                        "vpnc": "Cisco VPNC",
                        "l2tp": "L2TP",
                        "pptp": "PPTP",
                        "strongswan": "IPsec (strongSwan)",
                        "libreswan": "IPsec (Libreswan)",
                        "fortisslvpn": "Fortinet SSL VPN",
                        "sstp": "SSTP"
                    };
                    // WireGuard's first peer, or the plugin's own setting for its server.
                    const endpoint = /endpoint=(\S+)/.exec(values["wireguard.peers"] || "");
                    const remote = /\b(?:remote|gateway)\s*=\s*([^,]+)/.exec(values["vpn.data"] || "");
                    reader.onDone({
                        "serviceType": names[service] || service,
                        "server": endpoint !== null ? endpoint[1] : remote !== null ? remote[1].trim() : "",
                        "address": (values["IP4.ADDRESS[1]"] || values["IP6.ADDRESS[1]"] || "").split("/")[0]
                    });
                    reader.destroy();
                }
            }

        }

    }

    Process {
        id: importProcess

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
