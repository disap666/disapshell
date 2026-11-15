pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Animated wallpapers. awww keeps every decoded frame of a GIF in memory (over
// 1 GB for a long one), so it only shows the first frame. The wallpaper backend
// converts the GIF to a video once and it is played here, above awww's layer.
Scope {
    id: root
    property string path: ""
    property string resize: "crop"
    property bool live: false

    function show(file, mode) {
        // a fresh surface each time, so it sits above awww's layer
        fadeOut.stop();
        live = false;
        path = file; resize = mode || "crop";
        live = path !== "";
    }

    // after a restart of this process: pick the current animation up again
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/wallpaper-picker/animation"
        preload: true; printErrors: false
        onLoaded: {
            var lines = text().split("\n");
            if (!root.live && lines[0]) root.show(lines[0], lines[1]);
        }
    }

    IpcHandler {
        target: "wallpaper"
        function set(file: string, mode: string): void { root.show(file, mode); }
        function clear(): void { if (root.live) fadeOut.restart(); }
        function status(): string { return JSON.stringify({ path: root.path, live: root.live, resize: root.resize }); }
    }
    Timer { id: fadeOut; interval: 220; onTriggered: root.live = false }

    Variants {
        model: root.live ? Quickshell.screens : []
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.namespace: "rice-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MediaPlayer {
                id: player
                source: "file://" + root.path
                videoOutput: video
                loops: MediaPlayer.Infinite
                Component.onCompleted: play()
            }
            VideoOutput {
                id: video
                readonly property bool unscaled: root.resize === "no"
                anchors.centerIn: parent
                width: unscaled ? sourceRect.width : parent.width
                height: unscaled ? sourceRect.height : parent.height
                fillMode: root.resize === "fit" ? VideoOutput.PreserveAspectFit
                        : root.resize === "crop" ? VideoOutput.PreserveAspectCrop : VideoOutput.Stretch
                opacity: player.position > 0 && !fadeOut.running ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }
}
