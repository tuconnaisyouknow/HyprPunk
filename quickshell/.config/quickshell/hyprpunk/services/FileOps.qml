pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the file picker changes on disk: a new file or folder, a new name, the trash.
// One change at a time, run only when asked, and none ever replaces a file that's
// already there. Each tells its caller whether it worked.
Singleton {
    id: ops

    // What the change under way answers to, null when none is.
    property var answer: null

    function run(command, onDone) {
        if (answer) {
            onDone(false);
            return ;
        }
        answer = onDone;
        runner.exec(command);
    }

    function createFolder(path, onDone) {
        run(["mkdir", "--", path], onDone);
    }

    function createFile(path, onDone) {
        run(["sh", "-c", "set -C; : >\"$0\"", path], onDone);
    }

    function rename(from, to, onDone) {
        run(["mv", "-T", "--update=none-fail", "--", from, to], onDone);
    }

    // To the trash rather than gone: you can still get them back.
    function trash(paths, onDone) {
        run(["gio", "trash", "--"].concat(paths), onDone);
    }

    Process {
        id: runner

        onExited: (code) => {
            const onDone = ops.answer;
            ops.answer = null;
            onDone(code === 0);
        }
    }

}
