pragma ComponentBehavior: Bound
import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Typographic: a magazine cover. One huge number, one word in italics,
// the summary as a headline and the week as a single thin line.
Item {
    id: look
    required property var w
    width: 420; height: 280
    readonly property var cur: w.cur
    readonly property color tint: cur ? w.tempColor(cur.temp) : "#8fd0ff"
    readonly property var week: w.ready ? w.data.daily.slice(0, 7) : []

    Rectangle {
        anchors.fill: parent; radius: 6
        color: "#f3efe7"
    }
    Rectangle { x: 0; y: 0; width: 8; height: parent.height; radius: 3; color: look.tint }

    Text {
        x: 26; y: 18
        text: (look.w.ready ? look.w.data.place.toUpperCase() : "") + "   ·   " + look.w.now.toLocaleDateString(Qt.locale("ru_RU"), "d MMMM").toUpperCase()
        font.family: Rice.Theme.fontFamily; font.pixelSize: 10; font.letterSpacing: 3; font.weight: Font.DemiBold
        color: "#6b655b"
    }
    Text {
        id: bigNum
        x: 20; y: 26
        text: look.cur ? Math.round(look.cur.temp) : "-"
        font.family: "Georgia"; font.pixelSize: 150; font.weight: Font.Bold
        color: "#17140f"
    }
    Text {   // a small raised degree sign, magazine style
        x: bigNum.x + bigNum.implicitWidth + 2; y: bigNum.y + 30
        text: "°"
        font.family: "Georgia"; font.pixelSize: 56; font.weight: Font.Bold
        color: look.tint
    }
    Column {
        x: bigNum.x + bigNum.implicitWidth + 44; y: 60
        width: look.width - x - 22
        spacing: 6
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: look.cur ? look.cur.desc.toLowerCase() : ""
            font.family: "Georgia"; font.pixelSize: 26; font.italic: true
            color: "#17140f"
        }
        Rectangle { width: 40; height: 3; color: look.tint }
        Text {
            width: parent.width; wrapMode: Text.WordWrap
            text: look.w.ready ? look.w.data.summary : ""
            font.family: Rice.Theme.fontFamily; font.pixelSize: 12
            color: "#4a453d"
        }
    }

    // the week as one line
    Canvas {
        id: line
        x: 26; y: 214; width: look.width - 52; height: 34
        property var dep: look.week
        onDepChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"), W = look.week; ctx.reset();
            if (W.length < 2) return;
            var hi = Math.max.apply(null, W.map(d => d.max)), lo = Math.min.apply(null, W.map(d => d.max));
            function px(i) { return i / (W.length - 1) * (width - 10) + 5; }
            function py(v) { return hi === lo ? height / 2 : height - 5 - (v - lo) / (hi - lo) * (height - 10); }
            ctx.strokeStyle = "#17140f"; ctx.lineWidth = 1.5; ctx.beginPath();
            for (var i = 0; i < W.length; i++) i ? ctx.lineTo(px(i), py(W[i].max)) : ctx.moveTo(px(i), py(W[i].max));
            ctx.stroke();
            for (var k = 0; k < W.length; k++) { ctx.fillStyle = k === 0 ? look.tint : "#17140f"; ctx.beginPath(); ctx.arc(px(k), py(W[k].max), k === 0 ? 4 : 2.5, 0, 2 * Math.PI); ctx.fill(); }
        }
    }
    Row {
        x: 26; y: 252; width: look.width - 52
        Repeater {
            model: look.week
            Text {
                required property var modelData
                required property int index
                width: (look.width - 52) / Math.max(1, look.week.length - 1) * (index === 0 || index === look.week.length - 1 ? .5 : 1)
                horizontalAlignment: index === 0 ? Text.AlignLeft : index === look.week.length - 1 ? Text.AlignRight : Text.AlignHCenter
                text: new Date(modelData.date + "T12:00:00").toLocaleDateString(Qt.locale("ru_RU"), "ddd").toUpperCase() + " " + Math.round(modelData.max) + "°"
                font.family: Rice.Theme.fontFamily; font.pixelSize: 9; font.letterSpacing: 1; color: "#6b655b"
            }
        }
    }
}
