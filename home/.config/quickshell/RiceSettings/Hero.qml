pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Hero card of the home page.
//   fan skins: art from assets/heroes/<skin id>.(png|jpg|jpeg|webp) on the right,
//                faded into the card; without a file, a drawn emblem of the skin
//   Glass: the swinging spider (assets/spider.png), if present
//   otherwise: drifting colour blobs and the day ring
ClippingRectangle {
    id: hero
    required property var home
    radius: Tokens.radius
    readonly property string fan: Tokens.fan
    readonly property bool spidey: !fan && spider.status === Image.Ready
    readonly property bool cinema: spidey || fan.length > 0
    readonly property bool hasArt: fan.length > 0 && art.status === Image.Ready
    readonly property color ink: fan ? Qt.darker(Tokens.base, 1.4) : "#000000"
    color: cinema ? ink : Tokens.surface

    readonly property var sky: home.isDay ? Tokens.skin.skyDay : Tokens.skin.skyNight
    readonly property bool animate: home.active && home.ambient && visible
    readonly property color red: fan ? Tokens.neon : "#e23b3b"
    readonly property color blue: fan ? Tokens.cyan : "#3d6fe0"
    // Qt.alpha() replaces alpha, so a translucent surface (Glass: #14ffffff)
    // would turn into near-opaque white. Tint such skins from the dark base.
    readonly property bool seeThrough: Tokens.surface.a < .5
    readonly property color veil: seeThrough ? Tokens.base : Tokens.surface

    // Aurora fallback
    Repeater {
        model: hero.cinema ? 0 : 3
        Rectangle {
            id: blob
            required property int index
            readonly property real s: hero.height * (1.1 - index * .15)
            width: s; height: s; radius: s / 2
            color: hero.sky[index]
            opacity: .32
            x: hero.width * (.35 + index * .2) - s / 2
            y: hero.height * (index === 1 ? .55 : .1) - s / 2
            SequentialAnimation on x {
                running: hero.animate; loops: Animation.Infinite
                NumberAnimation { to: hero.width * (.30 + blob.index * .22) - blob.s / 2; duration: 7000 + blob.index * 1500; easing.type: Easing.InOutSine }
                NumberAnimation { to: hero.width * (.40 + blob.index * .18) - blob.s / 2; duration: 7000 + blob.index * 1500; easing.type: Easing.InOutSine }
            }
        }
    }
    Rectangle {
        visible: !hero.cinema
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Tokens.alpha(hero.veil, hero.seeThrough ? .78 : .96) }
            GradientStop { position: .45; color: Tokens.alpha(hero.veil, hero.seeThrough ? .52 : .70) }
            GradientStop { position: 1; color: Tokens.alpha(hero.veil, hero.seeThrough ? .18 : .25) }
        }
    }

    // Fan art, faded into the card
    Item {
        id: artBox
        visible: hero.hasArt
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
        width: parent.width * .62
        clip: true
        Image {
            id: art
            readonly property var exts: ["png", "jpg", "jpeg", "webp"]
            property int tryIndex: 0
            anchors.fill: parent
            source: hero.fan ? Qt.resolvedUrl("assets/heroes/" + Tokens.skin.id + "." + exts[tryIndex]) : ""
            readonly property string skinId: Tokens.skin.id
            onSkinIdChanged: tryIndex = 0
            onStatusChanged: if (status === Image.Error && tryIndex < exts.length - 1) tryIndex++
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignRight
            asynchronous: true; smooth: true; mipmap: true
            sourceSize.width: 1200
            scale: 1.04
            SequentialAnimation on scale {   // slow push-in, like a film still
                running: hero.animate && hero.hasArt; loops: Animation.Infinite
                NumberAnimation { to: 1.10; duration: 14000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.04; duration: 14000; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {   // fade the left edge of the art into the card
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: hero.ink }
                GradientStop { position: .38; color: Tokens.alpha(hero.ink, .55) }
                GradientStop { position: .7; color: Tokens.alpha(hero.ink, 0) }
            }
        }
        Rectangle {   // and the bottom, so the seam reads
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: .6; color: Tokens.alpha(hero.ink, 0) }
                GradientStop { position: 1; color: Tokens.alpha(hero.ink, .7) }
            }
        }
    }

    // Emblem when a fan skin has no art yet
    Item {
        id: emblem
        visible: hero.fan.length > 0 && !hero.hasArt
        width: Math.min(hero.height * .86, 230); height: width
        anchors.right: parent.right; anchors.rightMargin: 46
        anchors.verticalCenter: parent.verticalCenter
        property real spin: 0
        NumberAnimation on spin { running: hero.animate && emblem.visible; from: 0; to: 1; duration: 24000; loops: Animation.Infinite }
        property real pulse: 1
        SequentialAnimation on pulse {
            running: hero.animate && emblem.visible; loops: Animation.Infinite
            NumberAnimation { to: .72; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 1800; easing.type: Easing.InOutSine }
        }
        Canvas {
            id: emblemCanvas
            anchors.fill: parent
            property var dep: [hero.fan, Tokens.neon, Tokens.cyan, emblem.spin, emblem.pulse]
            onDepChanged: requestPaint()
            function rgba(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
            onPaint: {
                var ctx = getContext("2d"); ctx.reset();
                var w = width, c = w / 2, A = Qt.color(Tokens.neon), B = Qt.color(Tokens.cyan);
                var t = emblem.spin * Math.PI * 2, p = emblem.pulse, i, k;
                ctx.lineCap = "round";
                if (hero.fan === "air") {
                    // three spirals turning around a common centre
                    ctx.strokeStyle = rgba(A, .12); ctx.lineWidth = 2;
                    ctx.beginPath(); ctx.arc(c, c, c - 6, 0, 2 * Math.PI); ctx.stroke();
                    for (k = 0; k < 3; k++) {
                        ctx.beginPath();
                        for (i = 0; i <= 60; i++) {
                            var th = i / 60 * Math.PI * 1.55, r = 8 + (c - 26) * i / 60;
                            var a = th + k * Math.PI * 2 / 3 + t;
                            var x = c + Math.cos(a) * r, y = c + Math.sin(a) * r;
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.strokeStyle = rgba(k === 1 ? B : A, .9); ctx.lineWidth = 7; ctx.stroke();
                    }
                    ctx.fillStyle = rgba(A, .9); ctx.beginPath(); ctx.arc(c, c, 9, 0, 2 * Math.PI); ctx.fill();
                } else if (hero.fan === "reactor") {
                    var g = ctx.createRadialGradient(c, c, 0, c, c, c * .55);
                    g.addColorStop(0, "rgba(255,255,255," + .95 * p + ")");
                    g.addColorStop(.35, "rgba(150,215,255," + .6 * p + ")");
                    g.addColorStop(1, "rgba(150,215,255,0)");
                    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(c, c, c * .55, 0, 2 * Math.PI); ctx.fill();
                    ctx.strokeStyle = rgba(B, .9); ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.arc(c, c, c - 8, 0, 2 * Math.PI); ctx.stroke();
                    for (i = 0; i < 10; i++) {   // coil segments
                        var a0 = i / 10 * Math.PI * 2 + t * .3;
                        ctx.strokeStyle = rgba(A, .85); ctx.lineWidth = 14;
                        ctx.beginPath(); ctx.arc(c, c, c - 26, a0 + .06, a0 + Math.PI / 5 - .06); ctx.stroke();
                    }
                    ctx.strokeStyle = "rgba(200,235,255," + .9 * p + ")"; ctx.lineWidth = 4; ctx.lineJoin = "round";
                    ctx.beginPath();
                    for (i = 0; i < 3; i++) {
                        var at = -Math.PI / 2 + i * Math.PI * 2 / 3, rt = c * .42;
                        if (i === 0) ctx.moveTo(c + Math.cos(at) * rt, c + Math.sin(at) * rt);
                        else ctx.lineTo(c + Math.cos(at) * rt, c + Math.sin(at) * rt);
                    }
                    ctx.closePath(); ctx.stroke();
                } else if (hero.fan === "petals") {
                    // a big dusk moon with a comet trail
                    var mg = ctx.createLinearGradient(0, 0, w, w);
                    mg.addColorStop(0, rgba(B, .95)); mg.addColorStop(1, rgba(A, .95));
                    ctx.fillStyle = mg; ctx.beginPath(); ctx.arc(c * 1.1, c * .95, c * .62, 0, 2 * Math.PI); ctx.fill();
                    ctx.fillStyle = hero.ink; ctx.globalAlpha = .55;
                    ctx.beginPath(); ctx.arc(c * 1.35, c * .8, c * .5, 0, 2 * Math.PI); ctx.fill();
                    ctx.globalAlpha = 1;
                    var cg = ctx.createLinearGradient(0, w, c, c * .6);
                    cg.addColorStop(0, rgba(A, 0)); cg.addColorStop(1, "rgba(255,255,255,0.95)");
                    ctx.strokeStyle = cg; ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.moveTo(6, w - 10); ctx.quadraticCurveTo(c * .5, c * 1.1, c * .78 + 8 * p, c * .5); ctx.stroke();
                } else if (hero.fan === "stars") {
                    // two crossed blades of light
                    function blade(x1, y1, x2, y2, col) {
                        ctx.strokeStyle = rgba(col, .18 * p); ctx.lineWidth = 22; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
                        ctx.strokeStyle = rgba(col, .55); ctx.lineWidth = 9; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
                        ctx.strokeStyle = "rgba(255,255,255,0.95)"; ctx.lineWidth = 3.5; ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
                    }
                    blade(w * .2, w * .88, w * .86, w * .1, A);
                    blade(w * .8, w * .88, w * .14, w * .1, B);
                    ctx.strokeStyle = "#9aa3b2"; ctx.lineWidth = 10;
                    ctx.beginPath(); ctx.moveTo(w * .12, w * .97); ctx.lineTo(w * .21, w * .87); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(w * .88, w * .97); ctx.lineTo(w * .79, w * .87); ctx.stroke();
                } else if (hero.fan === "ring") {
                    // black hole: lensed halo, disc behind, shadow, disc in front
                    function disc(front) {
                        var dg = ctx.createLinearGradient(0, 0, w, 0);
                        dg.addColorStop(0, rgba(A, 0)); dg.addColorStop(.25, rgba(A, .9)); dg.addColorStop(.5, "rgba(255,240,215,1)");
                        dg.addColorStop(.75, rgba(A, .9)); dg.addColorStop(1, rgba(A, 0));
                        ctx.strokeStyle = dg; ctx.lineWidth = front ? 9 : 6;
                        var rx = c - 4, ry = 16, cy = c;
                        ctx.beginPath();
                        for (var q = 0; q <= 48; q++) {
                            var ang = (front ? 0 : Math.PI) + q / 48 * Math.PI;
                            var ex = c + Math.cos(ang) * rx, ey = cy + Math.sin(ang) * ry;
                            if (q === 0) ctx.moveTo(ex, ey); else ctx.lineTo(ex, ey);
                        }
                        ctx.stroke();
                    }
                    var hg = ctx.createRadialGradient(c, c, c * .3, c, c, c * .62);
                    hg.addColorStop(0, rgba(A, .0)); hg.addColorStop(.55, rgba(A, .85 * p)); hg.addColorStop(1, rgba(A, 0));
                    ctx.fillStyle = hg; ctx.beginPath(); ctx.arc(c, c, c * .62, 0, 2 * Math.PI); ctx.fill();
                    disc(false);
                    ctx.fillStyle = "#000000"; ctx.beginPath(); ctx.arc(c, c, c * .34, 0, 2 * Math.PI); ctx.fill();
                    disc(true);
                }
            }
        }
    }

    // Spider (Glass)
    Item {
        id: hang
        visible: hero.spidey
        readonly property real s: Math.min(1.45, hero.height / 180 * .95)
        width: 130 * s; height: 180 * s
        x: hero.width - width - 34
        y: -6
        transform: Rotation {
            origin.x: hang.width * .53; origin.y: 0
            angle: 0
            SequentialAnimation on angle {
                running: hero.animate && hero.spidey; loops: Animation.Infinite
                NumberAnimation { from: -3.2; to: 3.2; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { from: 3.2; to: -3.2; duration: 2600; easing.type: Easing.InOutSine }
            }
        }
        SequentialAnimation on y {
            running: hero.animate && hero.spidey; loops: Animation.Infinite
            NumberAnimation { to: 4; duration: 3700; easing.type: Easing.InOutSine }
            NumberAnimation { to: -6; duration: 3700; easing.type: Easing.InOutSine }
        }
        Image {
            id: spider
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/spider.png")
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
        }
    }

    // Text
    ColumnLayout {
        x: 34; anchors.verticalCenter: parent.verticalCenter
        width: hero.width - (hero.spidey ? hang.width + 90 : hero.hasArt ? hero.width * .45 : hero.fan ? emblem.width + 100 : ring.width + 100)
        spacing: 0
        Row {
            spacing: 6
            Text {
                id: clockText
                text: Qt.formatTime(hero.home.now, "HH:mm")
                font.family: hero.cinema ? Tokens.display : Tokens.font
                font.pixelSize: Tokens.px(hero.cinema ? 70 : 76)
                font.weight: hero.cinema ? Font.Medium : Font.Light
                font.letterSpacing: hero.cinema ? -1 : -2
                color: hero.cinema ? "#ffffff" : Tokens.text
            }
            Text {
                visible: hero.cinema
                anchors.baseline: clockText.baseline
                text: Qt.formatTime(hero.home.now, "ss")
                font.family: Tokens.display; font.pixelSize: Tokens.px(20); font.weight: Font.Medium
                color: hero.red
            }
        }
        Text {
            Layout.topMargin: hero.cinema ? 2 : -6
            text: {
                var d = hero.home.now.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM");
                return d.charAt(0).toUpperCase() + d.slice(1);
            }
            font.family: Tokens.font; font.pixelSize: Tokens.px(15); font.weight: Font.Medium
            color: hero.cinema ? Tokens.alpha(Tokens.text, .55) : Tokens.text2
        }
        Flow {
            Layout.fillWidth: true; Layout.topMargin: 18
            spacing: 8
            Repeater {
                model: [
                    [0xF03D8, Rice.Theme.palette.name || "Своя палитра"],
                    [0xF0150, "Аптайм " + hero.home.uptime],
                    [0xF033D, "Linux " + hero.home.kernel]
                ]
                Rectangle {
                    id: chip
                    required property var modelData
                    required property int index
                    implicitWidth: chipRow.implicitWidth + 22; implicitHeight: 30; radius: 15
                    color: Tokens.alpha("#ffffff", hero.cinema ? .06 : .07)
                    border.width: 1
                    border.color: hero.cinema ? Tokens.alpha(chip.index === 0 ? hero.red : "#ffffff", chip.index === 0 ? .55 : .12) : Tokens.line
                    Row {
                        id: chipRow; anchors.centerIn: parent; spacing: 7
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Tokens.glyph(chip.modelData[0]); font.family: Tokens.iconFont; font.pixelSize: 13; color: hero.cinema ? (chip.index === 0 ? hero.red : Qt.lighter(hero.blue, 1.15)) : Tokens.neon }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: chip.modelData[1]; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.DemiBold; color: hero.cinema ? Tokens.alpha(Tokens.text, .9) : Tokens.text }
                    }
                }
            }
        }
    }

    // Day ring (fallback only)
    Item {
        id: ring
        visible: !hero.cinema
        width: Math.min(hero.height - 50, 190); height: width
        anchors.right: parent.right; anchors.rightMargin: 36
        anchors.verticalCenter: parent.verticalCenter

        Canvas {
            id: arcCanvas
            anchors.fill: parent
            property real t: hero.home.arcT
            property var dep: [Tokens.neon, Tokens.cyan]
            onTChanged: requestPaint()
            onDepChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d"), c = width / 2, r = c - 9; ctx.reset();
                ctx.lineCap = "round"; ctx.lineWidth = 12;
                ctx.strokeStyle = "rgba(255,255,255,0.08)";
                ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke();
                var g = ctx.createLinearGradient(0, 0, width, height);
                g.addColorStop(0, Tokens.cyan); g.addColorStop(1, Tokens.neon);
                ctx.strokeStyle = g;
                ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.max(.02, t) * 2 * Math.PI); ctx.stroke();
            }
        }
        Rectangle {
            readonly property real a: -Math.PI / 2 + hero.home.arcT * 2 * Math.PI
            readonly property real r: ring.width / 2 - 9
            width: 20; height: 20; radius: 10
            color: "#ffffff"
            border.width: 4; border.color: Tokens.neon
            x: ring.width / 2 + Math.cos(a) * r - 10
            y: ring.height / 2 + Math.sin(a) * r - 10
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Tokens.glyph(hero.home.isDay ? 0xF05A8 : 0xF0594)
                font.family: Tokens.iconFont; font.pixelSize: 26
                color: hero.home.isDay ? Tokens.amber : Tokens.cyan
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(hero.home.arcT * 100) + "%"
                font.family: Tokens.font; font.pixelSize: Tokens.px(24); font.weight: Font.DemiBold
                color: Tokens.text
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: hero.home.isDay ? "дня прошло" : "ночи прошло"
                font.family: Tokens.font; font.pixelSize: Tokens.px(11)
                color: Tokens.text3
            }
        }
    }
}
