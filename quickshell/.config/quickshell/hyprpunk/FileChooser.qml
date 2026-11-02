import QtQuick
import Quickshell
import Quickshell.Io

// Talks to ~/Scripts/filechooser-portal.py, the portal backend the apps' file dialogs
// go to: holds the dialog an app is asking for, and sends back what you picked.
Scope {
    id: chooser

    // The dialog being asked for (the "open" message in the script's header), null
    // when none. The script sends the next one once this one is answered.
    property var request: null

    // A dialog came in, for shell.qml to open the picker.
    signal requested()

    // No paths cancels. filter: the index of the filter in use, -1 when there are none.
    function answer(paths, filter) {
        if (!request)
            return ;

        daemon.write(JSON.stringify({
            "id": request.id,
            "paths": paths,
            "filter": filter
        }) + "\n");
        request = null;
    }

    function cancel() {
        answer([], -1);
    }

    Process {
        id: daemon

        command: ["python3", "-u", Quickshell.env("HOME") + "/Scripts/filechooser-portal.py"]
        running: true
        stdinEnabled: true
        onExited: {
            chooser.request = null;
            restartDelay.restart();
        }

        stdout: SplitParser {
            onRead: (line) => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (error) {
                    return ;
                }
                if (message.event === "open") {
                    chooser.request = message;
                    chooser.requested();
                } else if (message.event === "close" && chooser.request && chooser.request.id === message.id) {
                    chooser.request = null;
                }
            }
        }

        stderr: SplitParser {
            onRead: (line) => {
                return console.log(line);
            }
        }

    }

    // Restarted if it stops, so the apps never lose their file dialogs for long.
    Timer {
        id: restartDelay

        interval: 5000
        onTriggered: daemon.running = true
    }

}
