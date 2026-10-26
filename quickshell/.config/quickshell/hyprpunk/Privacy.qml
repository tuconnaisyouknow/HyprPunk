import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Whether an app records the microphone or the camera, for the privacy dot: through
// PipeWire's links, and from the camera's device for the apps opening it themselves
// (browsers, out of PipeWire's sight).
Scope {
    id: privacy

    readonly property bool microphoneInUse: recordingApps(PwNodeType.AudioSource).length > 0
    readonly property bool cameraInUse: recordingApps(PwNodeType.VideoSource).length > 0 || cameraUsers.length > 0
    // Process names of what has the camera's device open.
    property var cameraUsers: []

    // The names of the apps whose streams are linked to a device of this type, the
    // shell's own (the sound page's level meter) and the Bluetooth link's left out.
    function recordingApps(type) {
        const names = [];
        for (const group of Pipewire.linkGroups.values) {
            const source = group.source;
            const target = group.target;
            if (source === null || target === null || source.type !== type || !target.isStream)
                continue;

            const properties = target.properties;
            const binary = properties["application.process.binary"] || "";
            if (binary === "qs" || binary === "quickshell" || (properties["media.class"] || "").endsWith("/Internal"))
                continue;

            const name = properties["application.name"] || binary || target.name;
            if (name && !names.includes(name))
                names.push(name);

        }
        return names;
    }

    // Who has the camera open, every few seconds.
    Timer {
        running: true
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: cameraProcess.running = true
    }

    Process {
        id: cameraProcess

        command: ["sh", "-c", "for pid in $(fuser /dev/video* 2>/dev/null); do cat /proc/$pid/comm; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const users = text.split("\n").filter((name) => {
                    return name !== "";
                });
                if (JSON.stringify(users) !== JSON.stringify(privacy.cameraUsers))
                    privacy.cameraUsers = users;

            }
        }

    }

}
