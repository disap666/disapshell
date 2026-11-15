import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import Quickshell.Widgets

// Capsule: one slim line. The fill behind the text is the song's progress,
// the round cover turns slowly like a tiny record.
Item {
    id: look
    required property var music
    width: 440; height: 76
    readonly property real progress: music.player && music.player.length > 0 ? Math.max(0, Math.min(1, music.elapsed / music.player.length)) : 0

    ClippingRectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        GlassPlate { anchors.fill: parent; radius: height / 2 }
        Rectangle {   // progress fill
            height: parent.height; width: parent.width * look.progress
            color: Rice.Theme.color("#26c5a6e9")
            Behavior on width { NumberAnimation { duration: 500 } }
        }
    }
    ClippingRectangle {
        id: disc
        x: 10; y: 10; width: 56; height: 56; radius: 28
        color: Rice.Theme.color("#35b9a3d3")
        RotationAnimation on rotation { running: look.music.playing; from: disc.rotation; to: disc.rotation + 360; duration: 8000; loops: Animation.Infinite }
        Text { anchors.centerIn: parent; text: "♫"; color: Rice.Theme.color("#e8ddf5"); font.pixelSize: 20; visible: art.status !== Image.Ready }
        Image { id: art; anchors.fill: parent; source: look.music.player ? look.music.player.trackArtUrl : ""; sourceSize: Qt.size(120, 120); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: Rice.Theme.color("#201c2a"); border.width: 1; border.color: "#40ffffff" }
    }
    Column {
        x: 80; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 80 - 150
        spacing: 1
        Text {
            width: parent.width; elide: Text.ElideRight
            text: look.music.player ? (look.music.player.trackTitle || "Без названия") : "Сейчас не играет"
            color: Rice.Theme.color("#faf6ff"); font.family: Rice.Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: look.music.player ? (look.music.player.trackArtist || look.music.player.identity) : "Включи музыку в плеере"
            color: Rice.Theme.color("#aee6ddef"); font.family: Rice.Theme.fontFamily; font.pixelSize: 11
        }
    }
    Row {
        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3; height: 18; rightPadding: 8
            Repeater {
                model: 3
                Rectangle {
                    id: bar
                    required property int index
                    width: 3; height: 5; radius: 1.5; color: Rice.Theme.color("#d8c4ef")
                    anchors.bottom: parent.bottom
                    SequentialAnimation on height {
                        running: look.music.playing; loops: Animation.Infinite
                        NumberAnimation { to: 9 + bar.index * 4; duration: 280 + bar.index * 90; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 4; duration: 380 - bar.index * 60; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
        GlyphButton { glyph: "prev"; width: 36; available: look.music.player !== null && look.music.player.canGoPrevious; onClicked: look.music.player.previous() }
        GlyphButton { glyph: look.music.playing ? "pause" : "play"; width: 40; glyphSize: 22; available: look.music.player !== null; onClicked: look.music.player.togglePlaying() }
        GlyphButton { glyph: "next"; width: 36; available: look.music.player !== null && look.music.player.canGoNext; onClicked: look.music.player.next() }
    }
}
