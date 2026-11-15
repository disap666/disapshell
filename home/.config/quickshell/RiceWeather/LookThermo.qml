pragma ComponentBehavior: Bound
import QtQuick
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Thermometer: a glass tube whose mercury rises to the current temperature.
// Its colour follows the temperature; today's min and max are marked on the scale.
Item {
    id: look
    required property var w
    width: 230; height: 420
    readonly property bool f: w.opts.units === "f"
    readonly property real lo: f ? -22 : -30
    readonly property real hi: f ? 104 : 40
    readonly property real step: f ? 18 : 10
    readonly property var cur: w.cur
    readonly property real temp: cur ? cur.temp : lo
    function ty(v) { return tube.y + tube.height - (Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo) * (tube.height - 16) - 8; }

    Rectangle {   // frosted body
        anchors.fill: parent; radius: 34
        gradient: Gradient { GradientStop { position: 0; color: "#e61b2030" } GradientStop { position: 1; color: "#f00f121c" } }
        border.width: 1; border.color: "#40ffffff"
        Rectangle { x: 34; y: 1; width: parent.width - 68; height: 1; color: "#59ffffff" }
    }

    // tube
    Rectangle {
        id: tube
        x: 40; y: 46; width: 26; height: 286; radius: 13
        color: "#22ffffff"; border.width: 1.5; border.color: "#55ffffff"
    }
    Rectangle {   // mercury column
        x: tube.x + 7; width: 12; radius: 6
        y: look.ty(look.temp); height: tube.y + tube.height - y + 4
        color: look.w.tempColor(look.temp)
        Behavior on y { NumberAnimation { duration: 1400; easing.type: Easing.OutCubic } }
        Rectangle { x: 2; y: 4; width: 3; height: Math.max(0, parent.height - 10); radius: 1.5; color: "#ffffff"; opacity: .35 }
    }
    Rectangle {   // bulb
        x: tube.x + tube.width / 2 - 27; y: tube.y + tube.height - 12; width: 54; height: 54; radius: 27
        color: "#22ffffff"; border.width: 1.5; border.color: "#55ffffff"
        Rectangle {
            anchors.centerIn: parent; width: 40; height: 40; radius: 20
            color: look.w.tempColor(look.temp)
            Rectangle { x: 9; y: 7; width: 10; height: 10; radius: 5; color: "#ffffff"; opacity: .45 }
        }
    }
    Rectangle { x: tube.x + 4; y: tube.y + 6; width: 3; height: tube.height - 20; radius: 1.5; color: "#ffffff"; opacity: .22 }   // glass glint

    // scale
    Repeater {
        model: Math.round((look.hi - look.lo) / (look.step / 2)) + 1
        Item {
            id: tick
            required property int index
            readonly property real v: look.lo + index * look.step / 2
            readonly property bool major: index % 2 === 0
            y: look.ty(v); x: tube.x + tube.width + 4
            Rectangle { width: tick.major ? 12 : 6; height: 1.5; color: "#80ffffff" }
            Text {
                visible: tick.major
                x: 16; y: -7
                text: Math.round(tick.v) + "°"
                font.family: Rice.Theme.fontFamily; font.pixelSize: 10; color: "#90ffffff"
            }
        }
    }
    Repeater {   // today's min / max
        model: look.w.today ? [["max", look.w.today.max], ["min", look.w.today.min]] : []
        Text {
            required property var modelData
            x: tube.x - 16; y: look.ty(modelData[1]) - 8
            text: "▸"; font.pixelSize: 13
            color: modelData[0] === "max" ? "#ffb36b" : "#8fd0ff"
        }
    }

    // readout
    Column {
        x: 112; y: 40; width: look.width - 124
        spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: look.w.ready ? look.w.data.place : "…"; font.family: Rice.Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#c8ffffff" }
        Text {
            text: look.cur ? Math.round(look.cur.temp) + "°" : "-"
            font.family: Rice.Theme.fontFamily; font.pixelSize: 54; font.weight: Font.Light; color: "#ffffff"
        }
        Text { text: look.cur ? look.w.glyph(look.cur.kind, look.cur.day) : ""; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 30; color: "#ffffff" }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: look.cur ? look.cur.desc : ""; font.family: Rice.Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: "#ffffff" }
    }
    Column {
        x: 112; anchors.bottom: parent.bottom; anchors.bottomMargin: 30
        width: look.width - 124
        spacing: 8
        Repeater {
            model: look.cur && look.w.today ? [
                ["#ffb36b", "макс", look.w.t(look.w.today.max)],
                ["#8fd0ff", "мин", look.w.t(look.w.today.min)],
                ["#ffffff", "ощущ.", look.w.t(look.cur.feels)]
            ] : []
            Row {
                required property var modelData
                spacing: 6
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: parent.modelData[0] }
                Text { width: 42; text: parent.modelData[1]; font.family: Rice.Theme.fontFamily; font.pixelSize: 11; color: "#a0ffffff" }
                Text { text: parent.modelData[2]; font.family: Rice.Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: "#ffffff" }
            }
        }
    }
}
