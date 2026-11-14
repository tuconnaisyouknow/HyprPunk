pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Creates and reads Wi-Fi profiles through wifi-connection.py, for every page that sends
// a secret or a hidden network's name, and knows what each kind of security asks for. A request goes on the script's input, so no
// secret shows in the process list. One connection at a time: the script answers once.
Singleton {
    id: profiles

    readonly property bool busy: onConnected !== null
    // What hears how the connection went, null when none is under way.
    property var onConnected: null
    property string pending: ""
    property var onRead: null

    // Enterprise networks get the full form, the others just a password.
    function enterprise(security) {
        return [WifiSecurityType.WpaEap, WifiSecurityType.Wpa2Eap, WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.DynamicWep, WifiSecurityType.Leap].includes(security);
    }

    // NetworkManager's key management for a network's password, "" when it takes none.
    function keyMgmt(security) {
        if (security === WifiSecurityType.Sae)
            return "sae";

        if (security === WifiSecurityType.WpaPsk || security === WifiSecurityType.Wpa2Psk)
            return "wpa-psk";

        if (security === WifiSecurityType.StaticWep)
            return "none";

        return "";
    }

    // NetworkManager can't connect to it without asking you something.
    function needsSecrets(network) {
        return enterprise(network.security) || keyMgmt(network.security) !== "";
    }

    // onDone(ok, error): saved and connected, or why not.
    function connect(request, onDone) {
        if (busy)
            return ;

        onConnected = onDone;
        pending = JSON.stringify(request);
        connector.running = true;
    }

    // onDone(settings): the saved enterprise settings of a network, in the request's
    // form (secrets included), or null when they can't be read.
    function read(ssid, onDone) {
        onRead = onDone;
        reader.command = ["python3", Session.scripts + "/wifi-connection.py", "--read", ssid];
        reader.running = true;
    }

    function answer(ok, error) {
        const onDone = onConnected;
        onConnected = null;
        if (onDone)
            onDone(ok, error);

    }

    Process {
        id: connector

        command: ["python3", Session.scripts + "/wifi-connection.py"]
        stdinEnabled: true
        onStarted: {
            write(profiles.pending + "\n");
            profiles.pending = "";
        }
        // Gone without an answer.
        onExited: profiles.answer(false, "Connection failed")

        stdout: SplitParser {
            onRead: (line) => {
                let result;
                try {
                    result = JSON.parse(line);
                } catch (error) {
                    return ;
                }
                profiles.answer(result.ok === true, result.error || "");
            }
        }

    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: {
                const onDone = profiles.onRead;
                profiles.onRead = null;
                let settings = null;
                try {
                    settings = JSON.parse(text);
                } catch (error) {
                }
                if (onDone)
                    onDone(settings);

            }
        }

    }

}
