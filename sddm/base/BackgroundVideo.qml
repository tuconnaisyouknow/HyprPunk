import QtMultimedia
import QtQuick

// The theme's video, looping, cropped to fill the screen
Item {
    MediaPlayer {
        source: "bg.mp4"
        autoPlay: true
        loops: MediaPlayer.Infinite
        videoOutput: videoOutput
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }

}
