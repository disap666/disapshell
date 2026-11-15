import QtQuick
import QtQuick.Effects
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import Quickshell.Widgets

// Turntable: the cover is the record's label, the platter spins while playing
// and the tonearm swings onto the record. Click the record to play/pause.
Item {
    id: look
    required property var music
    width: 300; height: 380

    GlassPlate { anchors.fill: parent; radius: 26 }

    Item {
        id: deck
        x: 22; y: 22; width: 256; height: 256
        Rectangle { anchors.fill: parent; radius: width / 2; color: Rice.Theme.color("#40000000") }   // platter shadow
        Item {
            id: disc
            anchors.fill: parent; anchors.margins: 6
            RotationAnimation on rotation { running: look.music.playing; from: disc.rotation; to: disc.rotation + 360; duration: 1800; loops: Animation.Infinite }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#121016" }
            Repeater {
                model: 10
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: disc.width * (.95 - index * .055); height: width; radius: width / 2
                    color: "transparent"; border.width: 1; border.color: index % 3 ? "#16ffffff" : "#2affffff"
                }
            }
            Rectangle {
                anchors.centerIn: parent; width: disc.width * .92; height: width; radius: width / 2; rotation: 40
                gradient: Gradient { GradientStop { position: 0; color: "#00ffffff" } GradientStop { position: .5; color: "#12ffffff" } GradientStop { position: 1; color: "#00ffffff" } }
            }
            ClippingRectangle {
                anchors.centerIn: parent
                width: disc.width * .4; height: width; radius: width / 2
                color: Rice.Theme.color("#35b9a3d3")
                Text { anchors.centerIn: parent; text: "♫"; color: Rice.Theme.color("#e8ddf5"); font.pixelSize: 26; visible: art.status !== Image.Ready }
                Image { id: art; anchors.fill: parent; source: look.music.player ? look.music.player.trackArtUrl : ""; asynchronous: true; sourceSize: Qt.size(200, 200); fillMode: Image.PreserveAspectCrop }
            }
            Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: "#d6d0de" }
        }
        MouseArea {
            anchors.centerIn: parent; width: parent.width * .8; height: width
            cursorShape: Qt.PointingHandCursor
            onClicked: if (look.music.player) look.music.player.togglePlaying()
        }
        Item {   // tonearm
            x: deck.width - 14; y: -8; width: 12; height: deck.height * .5
            transformOrigin: Item.Top
            rotation: look.music.playing ? 27 : 6
            Behavior on rotation { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 18; radius: 9; color: Rice.Theme.color("#c9c0d6"); border.width: 3; border.color: Rice.Theme.color("#8a7d9c") }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 4; height: parent.height - 8; radius: 2; color: Rice.Theme.color("#e2dbea") }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 11; height: 18; radius: 3; color: Rice.Theme.color("#a99cbb") }
        }
    }

    Text {
        x: 24; y: 292; width: parent.width - 48
        text: look.music.player ? (look.music.player.trackTitle || "Без названия") : "Сейчас не играет"
        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        color: Rice.Theme.color("#faf6ff"); font.family: Rice.Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
    }
    Text {
        x: 24; y: 312; width: parent.width - 48
        text: look.music.player ? (look.music.player.trackArtist || look.music.player.identity) : "Включи музыку в плеере"
        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        color: Rice.Theme.color("#aee6ddef"); font.family: Rice.Theme.fontFamily; font.pixelSize: 12
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 332
        spacing: 6
        GlyphButton { glyph: "prev"; available: look.music.player !== null && look.music.player.canGoPrevious; onClicked: look.music.player.previous() }
        GlyphButton { glyph: look.music.playing ? "pause" : "play"; glyphSize: 25; available: look.music.player !== null; onClicked: look.music.player.togglePlaying() }
        GlyphButton { glyph: "next"; available: look.music.player !== null && look.music.player.canGoNext; onClicked: look.music.player.next() }
    }
}
