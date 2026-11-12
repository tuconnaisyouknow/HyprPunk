import QtQuick
import Quickshell.Io

// Connects to a Wi-Fi network through wifi-connection.py, for every page that sends
// a secret or a hidden network's name. The request goes on its input, so no secret
// shows in the process list. finished() says how it went.
Process {
    id: helper

    property bool busy: false
    property string pending: ""

    signal finished(bool ok, string error)

    // One request at a time: the script answers once.
    function send(request) {
        if (busy)
            return ;

        busy = true;
        pending = JSON.stringify(request);
        running = true;
    }

    command: ["python3", Session.scripts + "/wifi-connection.py"]
    stdinEnabled: true
    onStarted: {
        write(pending + "\n");
        pending = "";
    }
    // Gone without an answer
    onExited: {
        if (busy) {
            busy = false;
            finished(false, "Connection failed");
        }
    }

    stdout: SplitParser {
        onRead: (line) => {
            let result;
            try {
                result = JSON.parse(line);
            } catch (error) {
                return ;
            }
            helper.busy = false;
            helper.finished(result.ok === true, result.error || "");
        }
    }

}
