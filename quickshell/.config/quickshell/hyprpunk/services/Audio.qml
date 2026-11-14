pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// The default output's volume and the microphone's mute, setting the volume, and when you
// change them. Always on: the island shows your changes whenever they happen. A device's
// first values are a baseline, not a change: switching output (AirPods coming or going)
// brings its own volume, so it's only reported once the device has settled.
Singleton {
    id: audio

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property int volume: sink !== null && sink.audio !== null ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool muted: sink !== null && sink.audio !== null && sink.audio.muted
    readonly property bool micMuted: source !== null && source.audio !== null && source.audio.muted
    // The output whose changes are reported, and whether it has settled.
    property var reportedSink: sink
    property bool sinkReady: false
    property bool sourceReady: false

    // You changed the volume or muted the output.
    signal volumeAdjusted()
    // You muted or unmuted the microphone.
    signal micToggled()

    function reportVolume() {
        // The volume can change (dropping to 0 as an output goes away) before the output
        // itself does.
        if (sink !== reportedSink) {
            settleSink();
            return ;
        }
        if (sinkReady && sink !== null && sink.ready && sink.audio !== null)
            volumeAdjusted();

    }

    // A volume from 0 to 1, unmuting, up to the limit set in the settings.
    function setVolume(value) {
        if (sink === null || sink.audio === null)
            return ;

        sink.audio.muted = false;
        sink.audio.volume = Math.min(value, (SoundSettings.limit || 100) / 100);
    }

    function toggleMute() {
        if (sink !== null && sink.audio !== null)
            sink.audio.muted = !sink.audio.muted;

    }

    function settleSink() {
        reportedSink = sink;
        sinkReady = false;
        sinkDelay.restart();
    }

    onVolumeChanged: reportVolume()
    onMutedChanged: reportVolume()
    onSinkChanged: settleSink()
    onSourceChanged: {
        sourceReady = false;
        sourceDelay.restart();
    }
    onMicMutedChanged: {
        if (sourceReady)
            micToggled();

    }

    PwObjectTracker {
        objects: [audio.sink, audio.source].filter((node) => {
            return node !== null;
        })
    }

    Timer {
        id: sinkDelay

        interval: 600
        running: true
        onTriggered: audio.sinkReady = true
    }

    Timer {
        id: sourceDelay

        interval: 500
        running: true
        onTriggered: audio.sourceReady = true
    }

}
