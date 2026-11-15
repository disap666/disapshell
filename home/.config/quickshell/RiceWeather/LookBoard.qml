pragma ComponentBehavior: Bound
import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Station board: split-flap tiles click over when numbers change,
// the next hours are listed like departures.
Item {
    id: look
    required property var w
    width: 440; height: 300
    readonly property var cur: w.cur
    function pad(s, n) { s = String(s); while (s.length < n) s = " " + s; return s.slice(-n); }
    readonly property string tempStr: cur ? pad(Math.round(cur.temp), 3) : "  -"

    Rectangle {
        anchors.fill: parent; radius: 14
        color: "#121214"
        border.width: 2; border.color: "#2b2b30"
    }
    Rectangle { x: 10; y: 10; width: parent.width - 20; height: parent.height - 20; radius: 8; color: "transparent"; border.width: 1; border.color: "#222226" }

    // header
    Row {
        x: 24; y: 22; spacing: 10
        Rectangle { width: 10; height: 10; radius: 5; color: "#ffb000"; anchors.verticalCenter: parent.verticalCenter
            SequentialAnimation on opacity { running: look.w.live; loops: Animation.Infinite; NumberAnimation { to: .3; duration: 800 } NumberAnimation { to: 1; duration: 800 } } }
        Text {
            text: "ПОГОДА · " + (look.w.ready ? look.w.data.place.toUpperCase() : "…")
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold; font.letterSpacing: 2
            color: "#ffb000"
        }
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 24; y: 22
        text: Qt.formatTime(look.w.now, "HH:mm")
        font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffb000"
    }

    // big temperature in flaps
    Row {
        x: 24; y: 52; spacing: 3
        Repeater {
            model: 3
            Flap { required property int index; size: 44; ch: look.tempStr.charAt(index) }
        }
        Flap { size: 44; ch: "°"; ink: "#ffb000" }
    }
    Column {
        x: 220; y: 58; width: look.width - 244; spacing: 4
        Text { width: parent.width; elide: Text.ElideRight; text: look.cur ? look.cur.desc.toUpperCase() : ""; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold; color: "#f4f0e6" }
        Text { text: look.cur ? "ОЩУЩАЕТСЯ " + Math.round(look.cur.feels) + "°" : ""; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#9a968c" }
        Text { text: look.w.today ? "МАКС " + Math.round(look.w.today.max) + "°  МИН " + Math.round(look.w.today.min) + "°" : ""; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#9a968c" }
        Text { text: look.cur ? "ВЕТЕР " + look.w.windDir(look.cur.windDir) + " " + Math.round(look.cur.wind) + " " + look.w.data.units.wind.toUpperCase() : ""; font.family: "JetBrains Mono"; font.pixelSize: 11; color: "#9a968c" }
    }

    // departures-style rows
    Row {
        x: 24; y: 128; spacing: 0
        Repeater {
            model: [["ВРЕМЯ", 70], ["", 34], ["ПРОГНОЗ", 190], ["T", 56], ["ОСАДКИ", 60]]
            Text { required property var modelData; width: modelData[1]; text: modelData[0]; font.family: "JetBrains Mono"; font.pixelSize: 9; font.letterSpacing: 1.5; color: "#6c6960" }
        }
    }
    Column {
        x: 24; y: 144; spacing: 4
        Repeater {
            model: look.w.ready ? look.w.data.hourly.filter((h, i) => i > 0 && i % 2 === 1).slice(0, 5) : []
            Row {
                id: row
                required property var modelData
                required property int index
                spacing: 0
                height: 24
                Text { width: 70; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.time.slice(-5); font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Bold; color: "#f4f0e6" }
                Text { width: 34; anchors.verticalCenter: parent.verticalCenter; text: look.w.glyph(row.modelData.kind, row.modelData.day); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 15; color: "#ffb000" }
                Text { width: 190; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                    text: ({ clear: "ЯСНО", partly: "ПЕРЕМ. ОБЛАЧНОСТЬ", cloudy: "ПАСМУРНО", fog: "ТУМАН", drizzle: "МОРОСЬ", rain: "ДОЖДЬ", snow: "СНЕГ", storm: "ГРОЗА" })[row.modelData.kind] || ""
                    font.family: "JetBrains Mono"; font.pixelSize: 13; color: "#f4f0e6" }
                Row { width: 56; spacing: 2
                    Repeater { model: 3; Flap { required property int index; size: 14; ch: look.pad(Math.round(row.modelData.temp), 3).charAt(index) } } }
                Text { width: 60; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight
                    text: row.modelData.pop + "%"; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold
                    color: row.modelData.pop >= 50 ? "#7fc8ff" : "#6c6960" }
            }
        }
    }
}
