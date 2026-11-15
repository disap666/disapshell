pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

// Window: the live sky seen through a four-pane window. Rain runs down the
// glass, frost creeps into the corners below zero, fog mists it over.
// The forecast is chalked on the sill.
Item {
    id: look
    required property var w
    width: 300; height: 360
    readonly property var cur: w.cur
    readonly property string kind: w.demoSky ? w.opts.demo : cur ? cur.kind : "cloudy"
    readonly property bool wet: ["rain", "drizzle", "storm"].indexOf(kind) >= 0
    readonly property real celsius: cur ? (w.opts.units === "f" ? (cur.temp - 32) / 1.8 : cur.temp) : 5
    readonly property color frame: "#efe6d8"

    // frame + sky
    Rectangle { x: 6; y: 8; width: 288; height: 278; radius: 14; color: "#30000000" }   // shadow
    Rectangle {
        id: frameRect
        x: 0; y: 0; width: 300; height: 282; radius: 14
        color: look.frame
        border.width: 1; border.color: "#c9bda9"
    }
    ClippingRectangle {
        id: glass
        x: 16; y: 16; width: 268; height: 250; radius: 6
        color: "#20304a"
        Sky {
            anchors.fill: parent
            kind: look.kind
            cloud: look.w.demoSky ? look.w.demoSky[0] : look.cur ? look.cur.cloud : 50
            precip: look.w.demoSky ? look.w.demoSky[1] : look.cur ? look.cur.precip : 0
            wind: look.cur ? (look.w.opts.wind === "kmh" ? look.cur.wind / 3.6 : look.cur.wind) : 2
            sunrise: look.w.today ? look.w.today.sunrise : "07:00"
            sunset: look.w.today ? look.w.today.sunset : "17:00"
            live: look.w.live
            now: look.w.now
        }
        // raindrops on the glass: bead, then slide down leaving a trail
        Repeater {
            model: look.wet ? 16 : 0
            Item {
                id: bead
                required property int index
                readonly property real s: ((index * 7919) % 1000) / 1000
                readonly property real s2: ((index * 3571 + 211) % 997) / 997
                x: s * glass.width; width: 8; height: 8
                Rectangle { id: trail; anchors.bottom: dropDot.top; anchors.horizontalCenter: dropDot.horizontalCenter; width: 2; height: 0; radius: 1; color: "#30ffffff" }
                Rectangle {
                    id: dropDot
                    width: 5 + bead.s * 4; height: width * 1.15; radius: width / 2
                    color: "#55ffffff"; border.width: 1; border.color: "#90ffffff"
                    Rectangle { x: 1; y: 1; width: 2; height: 2; radius: 1; color: "#ffffff" }
                }
                SequentialAnimation {
                    running: look.w.live; loops: Animation.Infinite
                    PropertyAction { target: bead; property: "y"; value: bead.s2 * glass.height * .7 }
                    PropertyAction { target: trail; property: "height"; value: 0 }
                    PauseAnimation { duration: 600 + bead.s2 * 4000 }
                    ParallelAnimation {
                        NumberAnimation { target: bead; property: "y"; to: glass.height + 10; duration: 1600 + bead.s * 1600; easing.type: Easing.InQuad }
                        NumberAnimation { target: trail; property: "height"; to: 40; duration: 1600 + bead.s * 1600 }
                    }
                }
            }
        }
        // frost in the corners below zero
        Repeater {
            model: look.celsius < 0 ? 4 : 0
            Rectangle {
                required property int index
                readonly property real r: 70 + Math.min(60, -look.celsius * 6)
                width: r * 2; height: r * 2; radius: r
                x: (index % 2 ? glass.width : 0) - r; y: (index > 1 ? glass.height : 0) - r
                color: "#ffffff"; opacity: .35
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 40 }
            }
        }
        // mist when foggy
        Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: look.kind === "fog" ? .28 : 0; Behavior on opacity { NumberAnimation { duration: 800 } } }
        // window glare
        Rectangle {
            x: -40; y: -60; width: 70; height: 420; rotation: 28; opacity: .07
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#00ffffff" } GradientStop { position: .5; color: "#ffffff" } GradientStop { position: 1; color: "#00ffffff" } }
        }
    }
    // mullions: the cross that splits the window into four panes
    Rectangle { x: 146; y: 16; width: 8; height: 250; color: look.frame; border.width: 1; border.color: "#d8ccb8" }
    Rectangle { x: 16; y: 137; width: 268; height: 8; color: look.frame; border.width: 1; border.color: "#d8ccb8" }
    Rectangle { x: 168; y: 150; width: 6; height: 22; radius: 3; color: "#b8a98f" }   // handle

    // sill with chalk writing
    Rectangle {
        x: -6; y: 276; width: 312; height: 18; radius: 6
        color: "#e3d6c2"; border.width: 1; border.color: "#c9bda9"
    }
    Rectangle {
        x: 18; y: 300; width: 264; height: 56; radius: 10
        color: "#2e3a33"; border.width: 3; border.color: "#7a5a3c"
        Column {
            anchors.centerIn: parent; spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: look.cur ? Math.round(look.cur.temp) + "°  " + look.cur.desc.toLowerCase() : "…"
                font.family: Rice.Theme.fontFamily; font.pixelSize: 16; font.italic: true; font.weight: Font.DemiBold
                color: "#eef2ea"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 240; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                text: look.w.ready ? look.w.data.summary : ""
                font.family: Rice.Theme.fontFamily; font.pixelSize: 11; font.italic: true
                color: "#b8c4b6"
            }
        }
    }
}
