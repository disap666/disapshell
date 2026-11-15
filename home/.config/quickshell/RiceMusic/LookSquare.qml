import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import Quickshell.Widgets

// Album tile: the cover is the whole widget. Title sits on a soft shade at
// the bottom; controls fade in when the pointer is over it.
Item {
    id: look
    required property var music
    width: 260; height: 260
    HoverHandler { id: hover }

    ClippingRectangle {
        anchors.fill: parent
        radius: 28
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Rice.Theme.color("#555c506e") }
                GradientStop { position: 1; color: Rice.Theme.color("#70201c2a") }
            }
        }
        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -24; text: "♫"; color: Rice.Theme.color("#e8ddf5"); font.pixelSize: 64; visible: art.status !== Image.Ready }
        Image {
            id: art
            anchors.fill: parent
            source: look.music.player ? look.music.player.trackArtUrl : ""
            asynchronous: true; sourceSize: Qt.size(400, 400); fillMode: Image.PreserveAspectCrop
            scale: hover.hovered ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: hover.hovered ? "#66000000" : "#00000000" }
                GradientStop { position: .45; color: hover.hovered ? "#40000000" : "#00000000" }
                GradientStop { position: 1; color: "#d0000000" }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        Rectangle {   // progress along the very bottom edge
            anchors.bottom: parent.bottom
            height: 4; color: Rice.Theme.color("#c8c5a6e9")
            width: parent.width * (look.music.player && look.music.player.length > 0 ? Math.min(1, look.music.elapsed / look.music.player.length) : 0)
        }
        Rectangle { anchors.fill: parent; radius: 28; color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#30ffffff") }
    }

    Row {   // equalizer, top-right
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16
        spacing: 3; height: 16
        Repeater {
            model: 3
            Rectangle {
                id: bar
                required property int index
                width: 3; height: 5; radius: 1.5; color: "#ffffff"
                anchors.bottom: parent.bottom
                SequentialAnimation on height {
                    running: look.music.playing; loops: Animation.Infinite
                    NumberAnimation { to: 9 + bar.index * 4; duration: 280 + bar.index * 90; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 4; duration: 380 - bar.index * 60; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    Row {
        anchors.centerIn: parent; anchors.verticalCenterOffset: -18
        spacing: 4
        opacity: hover.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        GlyphButton { glyph: "prev"; available: look.music.player !== null && look.music.player.canGoPrevious; onClicked: look.music.player.previous() }
        GlyphButton { glyph: look.music.playing ? "pause" : "play"; glyphSize: 30; width: 56; height: 50; available: look.music.player !== null; onClicked: look.music.player.togglePlaying() }
        GlyphButton { glyph: "next"; available: look.music.player !== null && look.music.player.canGoNext; onClicked: look.music.player.next() }
    }

    Column {
        x: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        width: parent.width - 36
        spacing: 1
        Text {
            width: parent.width; elide: Text.ElideRight
            text: look.music.player ? (look.music.player.trackTitle || "Без названия") : "Сейчас не играет"
            color: "#ffffff"; font.family: Rice.Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold
        }
        Text {
            width: parent.width; elide: Text.ElideRight
            text: look.music.player ? (look.music.player.trackArtist || look.music.player.identity) : "Включи музыку в плеере"
            color: "#d8ffffff"; font.family: Rice.Theme.fontFamily; font.pixelSize: 12
        }
    }
}
