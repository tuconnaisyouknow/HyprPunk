pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The names and availability of the sound cards' outputs and inputs, which PipeWire's
// nodes don't tell: an HDMI output with nothing plugged in isn't there. Read from pactl
// each time someone looks (ServiceRef), and followed meanwhile.
Singleton {
    id: ports

    property int refCount: 0
    // By sink and source name: {label (the port's name, for a sound card), available
    // (false for an HDMI output with nothing plugged in)}.
    property var info: ({
    })

    // Adds the ports of pactl's sinks or sources to info.
    function read(text) {
        let devices;
        try {
            devices = JSON.parse(text);
        } catch (error) {
            return ;
        }
        const next = Object.assign({
        }, info);
        for (const device of devices) {
            const port = (device.ports || []).find((item) => {
                return item.name === device.active_port;
            });
            next[device.name] = {
                "label": port !== undefined && device.properties["device.bus"] !== "bluetooth" ? port.description : "",
                "available": port === undefined || port.availability !== "not available"
            };
        }
        info = next;
    }

    function probe() {
        sinks.running = true;
        sources.running = true;
    }

    onRefCountChanged: {
        if (refCount === 1)
            probe();

    }

    Process {
        id: sinks

        command: ["pactl", "-f", "json", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: ports.read(text)
        }

    }

    Process {
        id: sources

        command: ["pactl", "-f", "json", "list", "sources"]

        stdout: StdioCollector {
            onStreamFinished: ports.read(text)
        }

    }

    // A screen, headphones or a microphone plugged in while someone looks.
    TiedProcess {
        running: ports.refCount > 0
        program: ["pactl", "subscribe"]

        stdout: SplitParser {
            onRead: (line) => {
                if (/ on (sink|source|card) /.test(line))
                    refresh.restart();

            }
        }

    }

    // Waits for a burst of events to end.
    Timer {
        id: refresh

        interval: 300
        onTriggered: ports.probe()
    }

}
