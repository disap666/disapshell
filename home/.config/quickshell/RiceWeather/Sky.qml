pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// Animated sky driven by the forecast:
//  - colours follow the sun: night -> dawn -> day -> dusk, using today's
//    sunrise/sunset, and fade toward grey as cloud cover grows
//  - the sun (or the moon, in its real phase) travels along an arc
//  - clouds by cloud cover, rain/drizzle/snow by intensity, slanted by wind
//  - fog banks drift, storms flash
Item {
    id: sky
    property string kind: "clear"          // clear partly cloudy fog drizzle rain snow storm
    property int cloud: 0                   // %
    property real precip: 0                 // mm/h
    property real wind: 0                   // m/s (or km/h / 3.6)
    property string sunrise: "07:00"
    property string sunset: "17:00"
    property bool live: true
    property date now: new Date()
    clip: true

    function mins(hhmm) { var p = hhmm.split(":"); return Number(p[0]) * 60 + Number(p[1]); }
    readonly property real m: now.getHours() * 60 + now.getMinutes()
    readonly property real sr: mins(sunrise)
    readonly property real ss: mins(sunset)
    readonly property bool isDay: m >= sr && m < ss
    readonly property real arcT: isDay ? (m - sr) / Math.max(1, ss - sr) : ((m >= ss ? m - ss : m + 1440 - ss) / Math.max(1, 1440 - ss + sr))

    // colours
    function mix(a, b, t) { a = Qt.color(a); b = Qt.color(b); t = Math.max(0, Math.min(1, t)); return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }
    readonly property var palettes: ({
        night: ["#070b1e", "#1a2350"], dawn: ["#3c4a8f", "#f5a07a"],
        day: ["#2f6fd1", "#8cc0f2"],   dusk: ["#2a2860", "#ef8a5c"]
    })
    function phaseColor(i) {
        var w = 55, P = palettes;
        if (m < sr - w || m > ss + w) return P.night[i];
        if (m < sr) return mix(P.night[i], P.dawn[i], (m - (sr - w)) / w);
        if (m < sr + w) return mix(P.dawn[i], P.day[i], (m - sr) / w);
        if (m < ss - w) return P.day[i];
        if (m < ss) return mix(P.day[i], P.dusk[i], (m - (ss - w)) / w);
        return mix(P.dusk[i], P.night[i], (m - ss) / w);
    }
    readonly property real gloom: Math.min(.8, cloud / 100 * .55 + (["rain", "storm"].indexOf(kind) >= 0 ? .25 : kind === "drizzle" || kind === "fog" ? .15 : 0))
    readonly property color skyTop: mix(phaseColor(0), isDay ? "#5b6676" : "#15181f", gloom)
    readonly property color skyBottom: mix(phaseColor(1), isDay ? "#8a94a3" : "#262a33", gloom)

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: sky.skyTop; Behavior on color { ColorAnimation { duration: 2000 } } }
            GradientStop { position: 1; color: sky.skyBottom; Behavior on color { ColorAnimation { duration: 2000 } } }
        }
    }

    // stars
    Repeater {
        model: !sky.isDay ? Math.round(34 * (1 - sky.cloud / 100)) : 0
        Rectangle {
            id: star
            required property int index
            readonly property real r: ((index * 7919) % 1000) / 1000
            width: r > .85 ? 2.5 : 1.5; height: width; radius: width / 2; color: "#ffffff"
            x: ((index * 7331) % 1000) / 1000 * sky.width
            y: r * sky.height * .55
            opacity: .35 + r * .5
            SequentialAnimation on opacity {
                running: sky.live && star.index % 3 === 0; loops: Animation.Infinite
                NumberAnimation { to: .1; duration: 900 + star.r * 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: .85; duration: 900 + star.r * 1600; easing.type: Easing.InOutSine }
            }
        }
    }

    // sun / moon
    Item {
        id: body
        readonly property real size: Math.max(30, Math.min(sky.width, sky.height) * .17)
        width: size; height: size
        x: sky.width * (.44 + .5 * sky.arcT) - size / 2   // right half: text lives on the left
        y: sky.height * .62 - Math.sin(Math.PI * sky.arcT) * sky.height * .48 - size / 2
        opacity: ["rain", "storm", "snow", "fog", "drizzle"].indexOf(sky.kind) >= 0 ? 0 : sky.cloud > 85 ? .2 : sky.cloud > 60 ? .6 : 1
        Behavior on opacity { NumberAnimation { duration: 800 } }
        Behavior on x { NumberAnimation { duration: 1500 } }
        Behavior on y { NumberAnimation { duration: 1500 } }
        // sun
        Item {
            anchors.fill: parent
            visible: sky.isDay
            Rectangle { anchors.centerIn: parent; width: parent.width * 3; height: width; radius: width / 2; color: "#fff2c4"; opacity: .14 }
            Rectangle { anchors.centerIn: parent; width: parent.width * 1.8; height: width; radius: width / 2; color: "#ffe9a6"; opacity: .22 }
            Item {
                anchors.fill: parent
                RotationAnimation on rotation { running: sky.live && sky.isDay; from: 0; to: 360; duration: 60000; loops: Animation.Infinite }
                Repeater {
                    model: 12
                    Rectangle {
                        required property int index
                        width: 2.5; height: body.size * .32; radius: 1.25
                        color: "#fff1b8"; opacity: .7
                        x: body.size / 2 - 1.25; y: -body.size * .42
                        transform: Rotation { origin.x: 1.25; origin.y: body.size * .92; angle: index * 30 }
                    }
                }
            }
            Rectangle {
                anchors.fill: parent; radius: width / 2
                gradient: Gradient { GradientStop { position: 0; color: "#fff6cf" } GradientStop { position: 1; color: "#ffc94d" } }
            }
        }
        // moon with its real phase
        Item {
            anchors.fill: parent
            visible: !sky.isDay
            readonly property real phase: { var d = (sky.now - new Date(Date.UTC(2000, 0, 6, 18, 14))) / 86400000; return ((d % 29.530588) + 29.530588) % 29.530588 / 29.530588; }
            readonly property real lit: (1 - Math.cos(2 * Math.PI * phase)) / 2
            Rectangle { anchors.centerIn: parent; width: parent.width * 2.2; height: width; radius: width / 2; color: "#dfe6ff"; opacity: .02 + .14 * parent.lit }
            Rectangle {
                id: moonDisc
                anchors.fill: parent; radius: width / 2; color: "#eef1ff"
                clip: true
                Rectangle { x: parent.width * .25; y: parent.height * .3; width: parent.width * .18; height: width; radius: width / 2; color: "#d4d9ee" }
                Rectangle { x: parent.width * .55; y: parent.height * .58; width: parent.width * .12; height: width; radius: width / 2; color: "#d4d9ee" }
            }
            Rectangle {   // the shadow that carves the phase
                width: parent.width * 1.02; height: width; radius: width / 2
                y: -parent.height * .01
                x: (parent.phase < .5 ? -1 : 1) * parent.width * parent.lit * 1.06 - parent.width * .01
                color: sky.mix(sky.skyTop, sky.skyBottom, (body.y + body.size / 2) / sky.height)   // sky colour at the moon's height
                visible: parent.lit < .97
            }
        }
    }

    // clouds
    Repeater {
        model: Math.round(sky.cloud / 100 * 5) + (sky.kind === "partly" ? 1 : 0)
        Item {
            id: puff
            required property int index
            readonly property real s: ((index * 431) % 100) / 100
            readonly property real pad: 18
            width: sky.width * (.36 + s * .3) + pad * 2; height: (width - pad * 2) * .4 + pad * 2
            y: sky.height * (-.04 + (index % 3) * .1) - pad
            readonly property bool heavy: sky.gloom > .35
            opacity: (sky.isDay ? (heavy ? .5 : .62) : .26) * (.75 + s * .25)
            readonly property color tone: sky.isDay ? (heavy ? "#d3d8df" : "#ffffff") : "#9aa3b8"
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: .7; blurMax: 22 }
            Item {
                x: puff.pad; y: puff.pad; width: puff.width - puff.pad * 2; height: puff.height - puff.pad * 2
                Rectangle { y: parent.height * .45; width: parent.width; height: parent.height * .55; radius: height / 2; color: puff.tone }
                Rectangle { x: parent.width * .14; y: parent.height * .12; width: parent.height * .75; height: width; radius: width / 2; color: puff.tone }
                Rectangle { x: parent.width * .4; y: 0; width: parent.height * .95; height: width; radius: width / 2; color: puff.tone }
                Rectangle { x: parent.width * .66; y: parent.height * .25; width: parent.height * .6; height: width; radius: width / 2; color: puff.tone }
            }
            NumberAnimation on x {
                running: sky.live; loops: Animation.Infinite
                from: -puff.width + puff.s * sky.width; to: sky.width
                duration: Math.max(20000, (70000 + puff.s * 50000) / Math.max(1, sky.wind / 3))
            }
        }
    }

    // fog
    Repeater {
        model: sky.kind === "fog" ? 4 : 0
        Rectangle {
            id: bank
            required property int index
            width: sky.width * 1.4; height: sky.height * .16; radius: height / 2
            y: sky.height * (.3 + index * .17)
            color: "#ffffff"; opacity: .2
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 32 }
            SequentialAnimation on x {
                running: sky.live; loops: Animation.Infinite
                NumberAnimation { from: -sky.width * .4; to: 0; duration: 9000 + bank.index * 2500; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0; to: -sky.width * .4; duration: 9000 + bank.index * 2500; easing.type: Easing.InOutSine }
            }
        }
    }

    // precipitation
    readonly property bool snowing: kind === "snow"
    readonly property int drops: kind === "rain" ? Math.min(90, 34 + precip * 16)
        : kind === "storm" ? 90 : kind === "drizzle" ? 30 : snowing ? Math.min(70, 30 + precip * 20) : 0
    readonly property real slant: Math.min(24, wind * 2.4)
    Repeater {
        model: sky.drops
        Rectangle {
            id: drop
            required property int index
            readonly property real s: ((index * 9301 + 49297) % 233280) / 233280
            readonly property real s2: ((index * 7177 + 1013) % 1000) / 1000
            width: sky.snowing ? 3 + s * 3 : 1.4; height: sky.snowing ? width : (sky.kind === "drizzle" ? 7 : 14 + s * 8)
            radius: sky.snowing ? width / 2 : .7
            color: "#ffffff"
            opacity: sky.snowing ? .6 + s * .35 : .35 + s * .3
            rotation: sky.snowing ? 0 : sky.slant
            y: -40
            x: s * (sky.width + sky.slant * 4) - sky.slant * 2
            // each drop starts at its own height above the card, so they never fall in step
            NumberAnimation on y {
                running: sky.live; loops: Animation.Infinite
                from: -30 - drop.s2 * (sky.height + 30); to: sky.height + 10
                duration: (sky.snowing ? 6000 + drop.s * 4000 : sky.kind === "drizzle" ? 1300 + drop.s * 500 : 650 + drop.s * 350) * (1 + drop.s2)
            }
            SequentialAnimation on x {
                running: sky.live && sky.snowing; loops: Animation.Infinite
                NumberAnimation { to: drop.s * sky.width + 12; duration: 1600 + drop.s * 900; easing.type: Easing.InOutSine }
                NumberAnimation { to: drop.s * sky.width - 12; duration: 1600 + drop.s * 900; easing.type: Easing.InOutSine }
            }
        }
    }

    // lightning
    Item {
        anchors.fill: parent
        visible: sky.kind === "storm"
        Rectangle { id: flash; anchors.fill: parent; color: "#e9ecff"; opacity: 0 }
        Canvas {
            id: bolt
            anchors.fill: parent; opacity: 0
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                var x = width * (.3 + Math.random() * .4), y = 0;
                ctx.strokeStyle = "#ffffff"; ctx.lineWidth = 2.2; ctx.beginPath(); ctx.moveTo(x, y);
                while (y < height * .7) { y += 10 + Math.random() * 16; x += (Math.random() - .5) * 26; ctx.lineTo(x, y); }
                ctx.stroke();
            }
        }
        SequentialAnimation {
            running: sky.live && sky.kind === "storm"; loops: Animation.Infinite
            PauseAnimation { duration: 4200 }
            ScriptAction { script: bolt.requestPaint() }
            ParallelAnimation {
                SequentialAnimation { NumberAnimation { target: flash; property: "opacity"; to: .55; duration: 50 } NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 160 } }
                SequentialAnimation { NumberAnimation { target: bolt; property: "opacity"; to: 1; duration: 40 } PauseAnimation { duration: 120 } NumberAnimation { target: bolt; property: "opacity"; to: 0; duration: 300 } }
            }
            NumberAnimation { target: flash; property: "opacity"; to: .3; duration: 60 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 500 }
            PauseAnimation { duration: 2600 }
        }
    }
}
