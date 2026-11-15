pragma ComponentBehavior: Bound
import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Dial: a 24-hour clock face where every hour is painted with its forecast
// temperature. Blue dots inside are the chance of rain; the hand points at now.
Item {
    id: look
    required property var w
    width: 320; height: 320
    readonly property var cur: w.cur
    readonly property var hours: w.ready ? w.data.hourly.slice(0, 24) : []
    readonly property real c: width / 2

    Rectangle {
        anchors.fill: parent; radius: width / 2
        gradient: Gradient { GradientStop { position: 0; color: "#ee1a1e2c" } GradientStop { position: 1; color: "#f50e1018" } }
        border.width: 1; border.color: "#40ffffff"
    }
    Canvas {
        id: face
        anchors.fill: parent
        property var dep: look.hours
        onDepChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), c = look.c, H = look.hours; ctx.reset();
            for (var i = 0; i < H.length; i++) {
                var hour = Number(H[i].time.slice(11, 13));
                var a0 = (hour / 24) * 2 * Math.PI - Math.PI / 2 + .02, a1 = ((hour + 1) / 24) * 2 * Math.PI - Math.PI / 2 - .02;
                ctx.strokeStyle = look.w.tempColor(H[i].temp);
                ctx.globalAlpha = i === 0 ? 1 : .85 - i * .015;
                ctx.lineWidth = 22; ctx.lineCap = "butt";
                ctx.beginPath(); ctx.arc(c, c, c - 26, a0, a1); ctx.stroke();
                if (H[i].pop > 0) {   // rain chance dots
                    var am = (a0 + a1) / 2, r = c - 54;
                    ctx.globalAlpha = .9; ctx.fillStyle = "#7fc8ff";
                    ctx.beginPath(); ctx.arc(c + Math.cos(am) * r, c + Math.sin(am) * r, 1 + H[i].pop / 100 * 4, 0, 2 * Math.PI); ctx.fill();
                }
            }
            ctx.globalAlpha = .6; ctx.fillStyle = "#ffffff"; ctx.font = "bold 11px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
            [0, 6, 12, 18].forEach(function (h) { var a = h / 24 * 2 * Math.PI - Math.PI / 2; ctx.fillText(h, c + Math.cos(a) * (c - 7), c + Math.sin(a) * (c - 7)); });
        }
    }
    Item {   // the "now" hand
        anchors.fill: parent
        rotation: (look.w.now.getHours() + look.w.now.getMinutes() / 60) / 24 * 360
        Rectangle { x: look.c - 1.5; y: 4; width: 3; height: 46; radius: 1.5; color: "#ffffff" }
        Rectangle { x: look.c - 5; y: 0; width: 10; height: 10; radius: 5; color: "#ffffff" }
    }
    Column {
        anchors.centerIn: parent; spacing: -2
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: look.cur ? look.w.glyph(look.cur.kind, look.cur.day) : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 26; color: "#ffffff" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: look.cur ? Math.round(look.cur.temp) + "°" : "-"; font.family: Rice.Theme.fontFamily; font.pixelSize: 50; font.weight: Font.Light; color: "#ffffff" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: look.cur ? look.cur.desc : ""; font.family: Rice.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#ffffff" }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: look.w.ready ? look.w.data.place : ""; font.family: Rice.Theme.fontFamily; font.pixelSize: 10; color: "#90ffffff" }
        Item { width: 1; height: 6 }
        Row {   // wind needle
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
            Text { text: "↓"; rotation: look.cur ? look.cur.windDir : 0; font.pixelSize: 13; font.weight: Font.Bold; color: "#c8ffffff" }
            Text { text: look.cur ? Math.round(look.cur.wind) + " " + look.w.data.units.wind : ""; font.family: Rice.Theme.fontFamily; font.pixelSize: 11; color: "#c8ffffff" }
        }
    }
}
