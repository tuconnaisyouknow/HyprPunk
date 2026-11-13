import QtQuick
import Quickshell
import Quickshell.Io

// One of the settings files in ~/.local/state/hyprpunk, key=value lines written by its
// script (powerctl.sh, notificationctl.sh, capturectl.sh), read again whenever it
// changes. One that was never saved is written by its script, with its defaults.
// Read on the spot: the singletons holding these are only built when first used, by a
// capture or a notification that needs the setting right then.
Scope {
    id: settingsFile

    // "power.conf", and the script that writes it, "powerctl.sh".
    required property string fileName
    required property string script
    // Each line as [key, value], in order.
    readonly property var entries: file.text().split("\n").filter((line) => {
        return line.indexOf("=") > 0;
    }).map((line) => {
        const split = line.indexOf("=");
        return [line.slice(0, split), line.slice(split + 1)];
    })
    // The last value of each key.
    readonly property var values: {
        const values = {
        };
        for (const [key, value] of entries)
            values[key] = value;
        return values;
    }

    // Hands a change to the script: run(["set", "media", "true"]).
    function run(args) {
        Quickshell.execDetached([Session.scripts + "/" + script].concat(args));
    }

    FileView {
        id: file

        path: Session.stateDir + "/" + settingsFile.fileName
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: ensure.running = true
    }

    Process {
        id: ensure

        command: [Session.scripts + "/" + settingsFile.script, "ensure"]
        onExited: file.reload()
    }

}
