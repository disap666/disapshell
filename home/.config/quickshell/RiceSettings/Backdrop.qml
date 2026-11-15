import QtQuick

// Window backdrop: two slowly pulsing colour glows
// (accent bottom-left, second colour top-right) plus a faint motif per fan skin:
//   air: wind swirls, reactor: hex grid, petals: falling petals
//   stars: starfield, ring: a wide accretion ring
Item {
    id: root
    property bool live: true
    readonly property string motif: Tokens.fan
    readonly property bool moving: live && visible

    component Glow: Canvas {
        id: glow
        property color tint: "#ffffff"
        property real cx: 0
        property real cy: 0
        property real reach: .5
        property real strength: .15
        anchors.fill: parent
        property var dep: [tint, width, height]
        onDepChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var x = width * cx, y = height * cy, r = Math.max(width, height) * reach;
            var g = ctx.createRadialGradient(x, y, 0, x, y, r);
            g.addColorStop(0, Qt.rgba(tint.r, tint.g, tint.b, strength));
            g.addColorStop(.45, Qt.rgba(tint.r, tint.g, tint.b, strength * .35));
            g.addColorStop(1, Qt.rgba(tint.r, tint.g, tint.b, 0));
            ctx.fillStyle = g; ctx.fillRect(0, 0, width, height);
        }
    }

    Glow {
        tint: Tokens.neon; cx: .02; cy: 1.02; reach: .6; strength: .30
        SequentialAnimation on opacity {
            running: root.moving; loops: Animation.Infinite
            NumberAnimation { to: .55; duration: 7000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 7000; easing.type: Easing.InOutSine }
        }
    }
    Glow {
        tint: Tokens.cyan; cx: 1.0; cy: -.05; reach: .65; strength: .22
        SequentialAnimation on opacity {
            running: root.moving; loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 0 }
            NumberAnimation { to: .5; duration: 9000; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 9000; easing.type: Easing.InOutSine }
        }
    }

    // Static motifs, painted once per size/skin change
    Canvas {
        anchors.fill: parent
        visible: root.motif === "air" || root.motif === "reactor" || root.motif === "stars" || root.motif === "ring"
        property var dep: [root.motif, width, height, Tokens.neon, Tokens.cyan]
        onDepChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var W = width, H = height, A = Qt.color(Tokens.neon), B = Qt.color(Tokens.cyan), i, k;
            function seed(n) { var x = Math.sin(n * 127.1) * 43758.5453; return x - Math.floor(x); }
            if (root.motif === "air") {
                // wind swirls drifting in from the bottom-right
                ctx.lineCap = "round";
                for (k = 0; k < 5; k++) {
                    var ox = W * (.62 + k * .08), oy = H * (.62 + (k % 2) * .12), turns = 1.2 + k * .15;
                    ctx.strokeStyle = "rgba(255,255,255," + (0.05 - k * 0.006) + ")"; ctx.lineWidth = 1.5;
                    ctx.beginPath();
                    for (i = 0; i <= 80; i++) {
                        var th = i / 80 * Math.PI * 2 * turns, r = 6 + i * (1.6 + k * .5);
                        var x = ox + Math.cos(th) * r - i * 3.2, y = oy + Math.sin(th) * r * .55;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
            } else if (root.motif === "reactor") {
                // hex grid fading out from the top-right corner
                var s = 26, hh = s * Math.sqrt(3);
                for (var row = 0; row < H / hh + 1; row++)
                    for (var col = 0; col < W / (s * 1.5) + 1; col++) {
                        var cx = col * s * 1.5, cy = row * hh + (col % 2 ? hh / 2 : 0);
                        var d = Math.hypot(W - cx, cy) / Math.hypot(W, H);
                        var a = Math.max(0, .075 - d * .11);
                        if (a <= 0.004) continue;
                        ctx.strokeStyle = Qt.rgba(B.r, B.g, B.b, a); ctx.lineWidth = 1;
                        ctx.beginPath();
                        for (i = 0; i < 6; i++) {
                            var ang = Math.PI / 3 * i;
                            var px = cx + Math.cos(ang) * (s - 3), py = cy + Math.sin(ang) * (s - 3);
                            if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
                        }
                        ctx.closePath(); ctx.stroke();
                    }
            } else if (root.motif === "stars") {
                for (i = 0; i < 160; i++) {
                    var sx = seed(i) * W, sy = seed(i + 999) * H, sz = seed(i + 77) < .9 ? 1 : 2;
                    ctx.fillStyle = "rgba(255,255,255," + (0.08 + seed(i + 5) * 0.22) + ")";
                    ctx.fillRect(sx, sy, sz, sz);
                }
            } else if (root.motif === "ring") {
                ctx.lineWidth = 1.5;
                for (k = 0; k < 4; k++) {
                    ctx.strokeStyle = Qt.rgba(A.r, A.g, A.b, .06 - k * .012);
                    ctx.beginPath();
                    for (i = 0; i <= 120; i++) {
                        var t2 = Math.PI + i / 120 * Math.PI;
                        var ex = W * .72 + Math.cos(t2) * (W * .55 + k * 22), ey = H * 1.02 + Math.sin(t2) * (H * .28 + k * 10);
                        if (i === 0) ctx.moveTo(ex, ey); else ctx.lineTo(ex, ey);
                    }
                    ctx.stroke();
                }
            }
        }
    }

    // A few twinkling stars on top of the starfield
    Repeater {
        model: root.motif === "stars" ? 10 : 0
        Rectangle {
            id: tw
            required property int index
            readonly property real r1: Math.abs(Math.sin(index * 91.7) * 1000 % 1)
            readonly property real r2: Math.abs(Math.cos(index * 47.3) * 1000 % 1)
            x: r1 * root.width; y: r2 * root.height
            width: 2; height: 2; radius: 1; color: index % 3 ? "#ffffff" : Tokens.neon
            SequentialAnimation on opacity {
                running: root.moving; loops: Animation.Infinite
                PauseAnimation { duration: tw.r1 * 4000 }
                NumberAnimation { to: .1; duration: 900 }
                NumberAnimation { to: .9; duration: 900 }
            }
        }
    }

    // Falling petals
    Repeater {
        model: root.motif === "petals" ? 14 : 0
        Item {
            id: petal
            required property int index
            readonly property real r1: Math.abs(Math.sin(index * 12.9898) * 43758.5453 % 1)
            readonly property real r2: Math.abs(Math.sin(index * 78.233) * 12345.678 % 1)
            width: 9 + r1 * 6; height: width * .62
            property real t: 0
            readonly property real fall: (r2 + t) % 1
            x: (r1 * 1.2 - .1) * root.width + Math.sin(fall * Math.PI * 4 + index) * 40 - fall * 120
            y: -20 + fall * (root.height + 40)
            opacity: .22 + r2 * .25
            rotation: fall * 720 * (index % 2 ? 1 : -1)
            NumberAnimation on t {
                running: root.moving; loops: Animation.Infinite
                from: 0; to: 1; duration: 16000 + petal.r1 * 12000
            }
            Rectangle {
                anchors.fill: parent; radius: height / 2
                color: petal.index % 4 === 0 ? Tokens.cyan : Tokens.neon
            }
        }
    }
}
