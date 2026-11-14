pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Creates and reads Wi-Fi profiles through wifi-connection.py, for every page that sends
// a secret or a hidden network's name. A request goes on the script's input, so no
// secret shows in the process list. One connection at a time: the script answers once.
Singleton {
    id: profiles

    readonly property bool busy: onConnected !== null
    // What hears how the connection went, null when none is under way.
    property var onConnected: null
    property string pending: ""
    property var onRead: null

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
