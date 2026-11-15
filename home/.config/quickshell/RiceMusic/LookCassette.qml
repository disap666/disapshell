import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import Quickshell.Widgets

// Cassette tape: the reels turn while playing and the tape really moves from
// the left reel to the right one as the song goes on. Title on the label.
Item {
    id: look
    required property var music
    width: 380; height: 250
    readonly property real progress: music.player && music.player.length > 0 ? Math.max(0, Math.min(1, music.elapsed / music.player.length)) : 0

    // shell
    GlassPlate { anchors.fill: parent; radius: 20 }
    Repeater {   // screws
        model: [[14, 14], [366, 14], [14, 236], [366, 236], [190, 228]]
        Rectangle {
            required property var modelData
            x: modelData[0] - 5; y: modelData[1] - 5; width: 10; height: 10; radius: 5
            color: Rice.Theme.color("#40e4d4f6")
            Rectangle { anchors.centerIn: parent; width: 6; height: 1.5; rotation: 45; color: Rice.Theme.color("#80201c2a") }
        }
    }

    // label
    ClippingRectangle {
        id: label
        x: 30; y: 22; width: 320; height: 136; radius: 10
        color: Rice.Theme.color("#e6eee5f7")
        Rectangle { y: 34; width: parent.width; height: 6; color: Rice.Theme.color("#c5a6e9") }
        Rectangle { y: 42; width: parent.width; height: 3; color: Rice.Theme.color("#80c5a6e9") }
        ClippingRectangle {   // cover as a sticker
            x: parent.width - 46; y: 4; width: 28; height: 28; radius: 5; rotation: 6
            color: Rice.Theme.color("#c5a6e9")
            Image { anchors.fill: parent; source: look.music.player ? look.music.player.trackArtUrl : ""; sourceSize: Qt.size(80, 80); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        Text {
            x: 14; y: 8; width: parent.width - 70
            text: look.music.player ? (look.music.player.trackTitle || "Без названия") : "Сейчас не играет"
            elide: Text.ElideRight
            color: Rice.Theme.color("#2a2438"); font.family: Rice.Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.italic: true
        }
        Text {
            x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 6; width: parent.width - 28
            text: (look.music.player ? (look.music.player.trackArtist || look.music.player.identity) : "") + "   ·   A"
            elide: Text.ElideRight
            color: Rice.Theme.color("#5c506e"); font.family: Rice.Theme.fontFamily; font.pixelSize: 11; font.italic: true
        }
        // tape window
        Rectangle {
            id: win
            x: 50; y: 52; width: 220; height: 58; radius: 29
            color: Rice.Theme.color("#2a2438")
            Rectangle {   // tape running between the reels
                x: 46; y: parent.height - 14; width: parent.width - 92; height: 3; color: Rice.Theme.color("#5c3d2e")
            }
            Repeater {
                model: 2
                Item {
                    id: reel
                    required property int index
                    readonly property real tape: index === 0 ? 1 - look.progress : look.progress
                    width: 50; height: 50
                    x: index === 0 ? 4 : win.width - 54; y: 4
                    Rectangle {   // wound tape
                        anchors.centerIn: parent
                        width: 22 + reel.tape * 28; height: width; radius: width / 2
                        color: Rice.Theme.color("#5c3d2e")
                        Behavior on width { NumberAnimation { duration: 800 } }
                    }
                    Item {
                        id: hub
                        anchors.centerIn: parent; width: 22; height: 22
                        RotationAnimation on rotation { running: look.music.playing; from: hub.rotation; to: hub.rotation + 360; duration: 2400 - reel.index * 300; loops: Animation.Infinite }
                        Rectangle { anchors.fill: parent; radius: 11; color: Rice.Theme.color("#eee5f7") }
                        Repeater {
                            model: 6
                            Rectangle {
                                required property int index
                                x: 10; y: 1; width: 2; height: 6; color: Rice.Theme.color("#2a2438")
                                transform: Rotation { origin.x: 1; origin.y: 10; angle: index * 60 }
                            }
                        }
                        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Rice.Theme.color("#2a2438") }
                    }
                }
            }
        }
    }

    // bottom: controls in the cassette's trapezoid
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 172
        spacing: 6
        GlyphButton { glyph: "prev"; available: look.music.player !== null && look.music.player.canGoPrevious; onClicked: look.music.player.previous() }
        GlyphButton { glyph: look.music.playing ? "pause" : "play"; glyphSize: 25; available: look.music.player !== null; onClicked: look.music.player.togglePlaying() }
        GlyphButton { glyph: "next"; available: look.music.player !== null && look.music.player.canGoNext; onClicked: look.music.player.next() }
    }
    Text {
        x: 30; y: 184
        text: look.music.clock(look.music.elapsed)
        color: Rice.Theme.color("#90eee5f7"); font.family: Rice.Theme.fontFamily; font.pixelSize: 11
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 30; y: 184
        text: "−" + look.music.clock((look.music.player ? look.music.player.length : 0) - look.music.elapsed)
        color: Rice.Theme.color("#90eee5f7"); font.family: Rice.Theme.fontFamily; font.pixelSize: 11
    }
}
