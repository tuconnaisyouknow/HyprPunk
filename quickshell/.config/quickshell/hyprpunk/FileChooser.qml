import QtQuick
import Quickshell
import Quickshell.Io

// Talks to filechooser-portal.py, the portal backend the apps' file dialogs
// go to: holds the dialog an app is asking for, and sends back what you picked. The
// shell asks through it too (the settings' folders), answered here instead.
Scope {
    id: chooser

    // The dialog being asked for (the "open" message in the script's header), null
    // when none. The script sends the next one once this one is answered.
    property var request: null
    // What gets the paths of the shell's own dialog, null for an app's.
    property var shellAnswer: null

    // A dialog came in, for shell.qml to open the picker.
    signal requested()

    // The shell's own dialog, like an app's ("open" message) with only what differs in
    // options. Not while an app's is open; an app's coming in drops it.
    function ask(options, onPicked) {
        if (request)
            return ;

        shellAnswer = onPicked;
        request = Object.assign({
            "id": "shell",
            "mode": "open",
            "title": "",
            "acceptLabel": "",
            "app": "",
            "multiple": false,
            "directory": false,
            "folder": Quickshell.env("HOME"),
            "name": "",
            "files": [],
            "filters": [],
            "filter": -1
        }, options);
        requested();
    }

    // No paths cancels. filter: the index of the filter in use, -1 when there are none.
    function answer(paths, filter) {
        if (!request)
            return ;

        if (shellAnswer) {
            const onPicked = shellAnswer;
            shellAnswer = null;
            request = null;
            if (paths.length > 0)
                onPicked(paths);

            return ;
        }
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

        command: ["python3", "-u", Session.scripts + "/filechooser-portal.py"]
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
                    chooser.shellAnswer = null;
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
