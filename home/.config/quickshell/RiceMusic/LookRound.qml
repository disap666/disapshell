import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import Quickshell.Widgets

// Circle: round cover inside a progress ring that you can grab to seek.
// Hover shows the controls in the middle; the title rides underneath.
Item {
    id: look
    required property var music
    width: 250; height: 300
    readonly property real progress: music.player && music.player.length > 0 ? Math.max(0, Math.min(1, music.elapsed / music.player.length)) : 0
    HoverHandler { id: hover }

    GlassPlate { x: 0; y: 0; width: 250; height: 250; radius: 125 }
    Canvas {
        id: ring
        x: 10; y: 10; width: 230; height: 230
        property real p: look.progress
        onPChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), c = width / 2, r = c - 5; ctx.reset();
            ctx.lineCap = "round"; ctx.lineWidth = 6;
            ctx.strokeStyle = "rgba(255,255,255,0.12)"; ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke();
            ctx.strokeStyle = Rice.Theme.color("#c5a6e9"); ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.max(.01, p) * 2 * Math.PI); ctx.stroke();
            var a = -Math.PI / 2 + p * 2 * Math.PI;
            ctx.fillStyle = "#ffffff"; ctx.beginPath(); ctx.arc(c + Math.cos(a) * r, c + Math.sin(a) * r, 6, 0, 2 * Math.PI); ctx.fill();
        }
        MouseArea {   // seek by grabbing the ring
            anchors.fill: parent
            enabled: look.music.player !== null && look.music.player.canSeek && look.music.player.length > 0
            function seek(mx, my) {
                var a = Math.atan2(my - height / 2, mx - width / 2) + Math.PI / 2;
                if (a < 0) a += 2 * Math.PI;
                look.music.player.position = a / (2 * Math.PI) * look.music.player.length;
            }
            onPressed: mouse => { var d = Math.hypot(mouse.x - width / 2, mouse.y - height / 2); if (d < width / 2 - 22) { mouse.accepted = false; return; } seek(mouse.x, mouse.y); }
            onPositionChanged: mouse => { if (pressed) seek(mouse.x, mouse.y); }
        }
    }
    ClippingRectangle {
        x: 30; y: 30; width: 190; height: 190; radius: 95
        color: Rice.Theme.color("#35b9a3d3")
        Text { anchors.centerIn: parent; text: "♫"; color: Rice.Theme.color("#e8ddf5"); font.pixelSize: 48; visible: art.status !== Image.Ready }
        Image { id: art; anchors.fill: parent; source: look.music.player ? look.music.player.trackArtUrl : ""; sourceSize: Qt.size(300, 300); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle {
            anchors.fill: parent; color: "#000000"
            opacity: hover.hovered ? .45 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
    Row {
        x: 125 - width / 2; y: 125 - height / 2
        spacing: 0
        opacity: hover.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        GlyphButton { glyph: "prev"; available: look.music.player !== null && look.music.player.canGoPrevious; onClicked: look.music.player.previous() }
        GlyphButton { glyph: look.music.playing ? "pause" : "play"; glyphSize: 28; width: 50; height: 46; available: look.music.player !== null; onClicked: look.music.player.togglePlaying() }
        GlyphButton { glyph: "next"; available: look.music.player !== null && look.music.player.canGoNext; onClicked: look.music.player.next() }
    }
    Rectangle {   // title capsule under the disc
        anchors.horizontalCenter: parent.horizontalCenter; y: 260
        width: Math.min(250, titleText.implicitWidth + 28); height: 34; radius: 17
        color: Rice.Theme.color("#552a2438"); border.width: 1; border.color: Rice.Theme.color("#40e4d4f6")
        Text {
            id: titleText
            anchors.centerIn: parent; width: Math.min(implicitWidth, 222); elide: Text.ElideRight
            text: look.music.player ? (look.music.player.trackTitle || "Без названия") + "  ·  " + (look.music.player.trackArtist || "") : "Сейчас не играет"
            color: Rice.Theme.color("#faf6ff"); font.family: Rice.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
        }
    }
}
