pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Desktop RAM usage widget.
// Drag to move, drag the ◢ corner to scale, double-click to switch look.
// Options live in ~/.config/rice-theme/memory.json (Settings -> Виджеты -> Память).
// One widget of the merged RiceDesktop process (see ../RiceDesktop/shell.qml).
Scope {
    id: root
    property bool shown: true

    // options
    readonly property var optDefaults: ({ visible: true, onTop: false, look: "card", interval: 2, procs: true, opacity: .82 })
    property var opts: optDefaults
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/memory.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.opts = Object.assign({}, root.optDefaults, JSON.parse(text())); } catch (e) {}
            root.shown = root.opts.visible !== false;
        }
    }
    readonly property var looks: ["card", "ring", "pill"]
    readonly property string look: looks.indexOf(opts.look) >= 0 ? opts.look : "card"
    readonly property var sizes: ({ card: [380, opts.procs !== false ? 318 : 214], ring: [220, 220], pill: [340, 58] })
    readonly property real baseWidth: sizes[look][0]
    readonly property real baseHeight: sizes[look][1]

    Settings {
        id: saved
        location: Qt.resolvedUrl("position.ini")
        property real left: -1
        property real top: 120
        property string scales: "{}"
    }
    readonly property real curScale: { try { return JSON.parse(saved.scales)[look] || 1; } catch (e) { return 1; } }
    function setScale(v) { var m = {}; try { m = JSON.parse(saved.scales); } catch (e) {} m[look] = v; saved.scales = JSON.stringify(m); }

    // data (kB)
    property real total: 0
    property real avail: 0
    property real free: 0
    property real swapTotal: 0
    property real swapFree: 0
    readonly property real used: Math.max(0, total - avail)        // what programs really hold
    readonly property real cache: Math.max(0, avail - free)        // reclaimable page cache
    readonly property real ratio: total > 0 ? used / total : 0
    readonly property real cacheRatio: total > 0 ? cache / total : 0
    readonly property real swapUsed: Math.max(0, swapTotal - swapFree)
    readonly property bool ready: total > 0
    property real shownRatio: ratio                               // animated copy for the gauges
    Behavior on shownRatio { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    property real shownCache: cacheRatio
    Behavior on shownCache { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    property var history: []                                      // last 60 ratios
    property var top: []                                          // [{ name, kb }]

    // Firefox/Chromium helpers have their own process names: fold them into the app
    readonly property var alias: ({ "Isolated Web Co": "firefox", "Web Content": "firefox", "WebExtensions": "firefox",
        "Privileged Cont": "firefox", "RDD Process": "firefox", "Socket Process": "firefox", "Utility Process": "firefox",
        "chrome_crashpad": "chrome", "Telegram": "telegram", ".quickshell-wra": "quickshell", "qs": "quickshell" })

    // /proc/meminfo is read in-process; ps only runs while the process list is on screen.
    readonly property bool wantProcs: look === "card" && opts.procs !== false
    FileView {
        id: meminfo
        path: "/proc/meminfo"; printErrors: false
        onLoaded: root.parseMem(text())
    }
    Process {
        id: procs
        command: ["ps", "-eo", "rss=,comm="]
        stdout: StdioCollector { onStreamFinished: root.parseProcs(text) }
    }
    property int tick: 0
    Timer {
        interval: Math.max(1, root.opts.interval || 2) * 1000
        repeat: true; triggeredOnStart: true
        running: root.shown
        onTriggered: {
            meminfo.reload();
            if (root.wantProcs && root.tick++ % 2 === 0 && !procs.running) procs.running = true;
        }
    }
    function parseMem(text) {
        var m = {};
        text.split("\n").forEach(l => { var r = /^(\w+(?:\(\w+\))?):\s+(\d+)/.exec(l); if (r) m[r[1]] = +r[2]; });
        if (!m.MemTotal) return;
        total = m.MemTotal; avail = m.MemAvailable || m.MemFree; free = m.MemFree;
        swapTotal = m.SwapTotal || 0; swapFree = m.SwapFree || 0;
        var h = history.slice(-59); h.push(ratio); history = h;
    }
    function parseProcs(text) {
        var agg = {};
        text.split("\n").forEach(l => {
            var r = /^\s*(\d+)\s+(.+?)\s*$/.exec(l); if (!r) return;
            var n = alias[r[2]] || r[2];
            agg[n] = (agg[n] || 0) + (+r[1]);
        });
        top = Object.keys(agg).map(k => ({ name: k, kb: agg[k] })).sort((a, b) => b.kb - a.kb).slice(0, 4);
    }

    // formatting & colour
    function gb(kb) {
        if (kb < 1048576) return Math.round(kb / 1024) + " МБ";
        var g = kb / 1048576;
        return (g >= 100 ? g.toFixed(0) : g.toFixed(1)).replace(".", ",") + " ГБ";
    }
    function num(kb) { var g = kb / 1048576; return (g >= 100 ? g.toFixed(0) : g.toFixed(1)).replace(".", ","); }
    // usage to colour: green, amber, red
    function load(r) {
        var stops = [[0, "#8fe3a8"], [.55, "#8fe3a8"], [.75, "#ffd36b"], [.9, "#ff8a4c"], [1, "#ff4d5e"]];
        for (var i = 1; i < stops.length; i++) if (r <= stops[i][0]) {
            var a = Qt.color(stops[i - 1][1]), b = Qt.color(stops[i][1]), k = (r - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
            return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
        }
        return stops[stops.length - 1][1];
    }
    readonly property color hot: load(shownRatio)
    readonly property color cacheColor: "#7fb4ff"

    IpcHandler {
        target: "memory"
        function toggle(): void { root.shown = !root.shown; }
        function show(): void { root.shown = true; }
        function hide(): void { root.shown = false; }
        function place(x: real, y: real): void {
            card.x = Math.max(0, Math.min(x, desktop.width - card.width));
            card.y = Math.max(0, Math.min(y, desktop.height - card.height));
            card.savePosition();
        }
        function resize(scale: real): void { root.setScale(Math.max(.6, Math.min(1.8, scale))); saved.sync(); }
        function status(): string {
            return JSON.stringify({ shown: root.shown, look: root.look, x: card.x, y: card.y, width: card.width, height: card.height, scale: root.curScale,
                deskWidth: desktop.width, deskHeight: desktop.height, total: root.total, used: root.used, cache: root.cache,
                percent: Math.round(root.ratio * 100), swapUsed: root.swapUsed, top: root.top });
        }
    }

    component Label: Text {
        color: "#f4f1fa"
        font.family: Rice.Theme.fontFamily
    }
    component Icon: Text {
        color: "#f4f1fa"
        font.family: "JetBrainsMono Nerd Font"
    }
    // a ring gauge: track, cache arc right after the used arc, used arc on top
    component Gauge: Canvas {
        id: g
        property real used: root.shownRatio
        property real cached: root.shownCache
        property real thick: 12
        property bool showCache: true
        onUsedChanged: requestPaint()
        onCachedChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var r = Math.min(width, height) / 2 - thick / 2 - 1, cx = width / 2, cy = height / 2;
            var a0 = -Math.PI / 2, full = Math.PI * 2;
            c.lineWidth = thick; c.lineCap = "round";
            c.strokeStyle = "rgba(255,255,255,0.09)";
            c.beginPath(); c.arc(cx, cy, r, 0, full); c.stroke();
            if (showCache && cached > .005) {
                c.strokeStyle = Qt.rgba(0.5, 0.7, 1, 0.38);
                c.beginPath(); c.arc(cx, cy, r, a0 + full * used, a0 + full * Math.min(1, used + cached)); c.stroke();
            }
            if (used > .002) {
                var grad = c.createLinearGradient(0, 0, width, height);
                grad.addColorStop(0, root.load(Math.max(0, used - .25)));
                grad.addColorStop(1, root.load(used));
                c.strokeStyle = grad;
                c.beginPath(); c.arc(cx, cy, r, a0, a0 + full * used); c.stroke();
            }
        }
    }
    // the last two minutes as a filled line
    component Spark: Canvas {
        property var points: root.history
        onPointsChanged: requestPaint()
        onPaint: {
            var c = getContext("2d"), P = points; c.reset();
            if (P.length < 2) return;
            var lo = Math.max(0, Math.min.apply(null, P) - .04), hi = Math.min(1, Math.max.apply(null, P) + .04);
            if (hi - lo < .1) { var mid = (hi + lo) / 2; lo = mid - .05; hi = mid + .05; }
            var step = width / 59, x0 = width - (P.length - 1) * step;
            function y(v) { return height - 2 - (v - lo) / (hi - lo) * (height - 4); }
            c.beginPath(); c.moveTo(x0, y(P[0]));
            for (var i = 1; i < P.length; i++) c.lineTo(x0 + i * step, y(P[i]));
            var col = root.load(P[P.length - 1]);
            c.lineWidth = 2; c.lineJoin = "round"; c.strokeStyle = col; c.stroke();
            c.lineTo(width, height); c.lineTo(x0, height); c.closePath();
            var g = c.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(col.r, col.g, col.b, .32)); g.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0));
            c.fillStyle = g; c.fill();
            c.fillStyle = col; c.beginPath(); c.arc(width - 2, y(P[P.length - 1]), 2.5, 0, Math.PI * 2); c.fill();
        }
    }

    PanelWindow {
        id: desktop
        visible: root.shown
        anchors { top: true; right: true; bottom: true; left: true }
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-memory"
        WlrLayershell.layer: root.opts.onTop ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: card }

        Item {
            id: card
            readonly property real uiScale: Math.min(root.curScale, desktop.width / root.baseWidth, desktop.height / root.baseHeight)
            width: root.baseWidth * uiScale
            height: root.baseHeight * uiScale
            x: Math.max(0, Math.min(saved.left < 0 ? desktop.width - width - 24 : saved.left, desktop.width - width))
            y: Math.max(0, Math.min(saved.top, desktop.height - height))
            Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
            function savePosition() { saved.left = x; saved.top = y; saved.sync(); }

            Item {
                id: body
                width: root.baseWidth; height: root.baseHeight
                scale: card.uiScale; transformOrigin: Item.TopLeft

                // glass
                Rectangle {
                    anchors.fill: parent
                    radius: root.look === "pill" ? height / 2 : root.look === "ring" ? width / 2 : 26
                    color: Qt.rgba(.08, .07, .11, root.opts.opacity === undefined ? .82 : root.opts.opacity)
                    border.width: 1; border.color: "#33ffffff"
                    Rectangle {   // load colour, fading in from the bottom
                        anchors.fill: parent; radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#00000000" }
                            GradientStop { position: 1; color: Qt.rgba(root.hot.r, root.hot.g, root.hot.b, .10) }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: card
                    drag.minimumX: 0; drag.maximumX: Math.max(0, desktop.width - card.width)
                    drag.minimumY: 0; drag.maximumY: Math.max(0, desktop.height - card.height)
                    drag.threshold: 3
                    onReleased: card.savePosition()
                    onCanceled: card.savePosition()
                    onDoubleClicked: {   // cycle looks
                        var next = root.looks[(root.looks.indexOf(root.look) + 1) % root.looks.length];
                        var o = Object.assign({}, root.opts); o.look = next; root.opts = o;
                        optWriter.setText(JSON.stringify(o, null, 2) + "\n");
                    }
                }
                FileView { id: optWriter; path: Quickshell.env("HOME") + "/.config/rice-theme/memory.json"; printErrors: false }

                // Карточка
                Item {
                    visible: root.look === "card"
                    anchors.fill: parent

                    Row {
                        x: 20; y: 16; spacing: 7
                        Icon { text: String.fromCodePoint(0xF035B); font.pixelSize: 15; color: root.hot; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Память"; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Label {
                        anchors.right: parent.right; anchors.rightMargin: 20; y: 18
                        visible: root.swapTotal > 0
                        text: "swap " + root.gb(root.swapUsed)
                        font.pixelSize: 11; opacity: .55
                    }

                    Gauge {
                        id: bigGauge
                        x: 18; y: 48; width: 128; height: 128
                        thick: 13
                    }
                    Column {
                        anchors.centerIn: bigGauge
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(root.shownRatio * 100) + "%"
                            font.pixelSize: 32; font.weight: Font.Light; font.letterSpacing: -1
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "занято"; font.pixelSize: 11; opacity: .55 }
                    }

                    Item {
                        x: 166; y: 48; width: parent.width - 166 - 20; height: 128
                        Row {
                            spacing: 4
                            Label { text: root.ready ? root.num(root.used) : "…"; font.pixelSize: 30; font.weight: Font.DemiBold; font.letterSpacing: -1 }
                            Label { text: "ГБ"; font.pixelSize: 14; opacity: .7; topPadding: 13 }
                        }
                        Label { y: 38; text: "из " + root.gb(root.total); font.pixelSize: 12; opacity: .55 }
                        Spark { y: 58; width: parent.width; height: 34 }
                        Row {   // legend
                            y: 102; spacing: 12
                            Repeater {
                                model: [[root.hot, "программы", root.used], [root.cacheColor, "кэш", root.cache], ["#55ffffff", "свободно", root.free]]
                                Row {
                                    id: lg
                                    required property var modelData
                                    spacing: 5
                                    Rectangle { width: 7; height: 7; radius: 3.5; color: lg.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                                    Column {
                                        Label { text: root.gb(lg.modelData[2]); font.pixelSize: 11; font.weight: Font.DemiBold }
                                        Label { text: lg.modelData[1]; font.pixelSize: 9; opacity: .5 }
                                    }
                                }
                            }
                        }
                    }

                    // top consumers
                    Item {
                        visible: root.opts.procs !== false
                        x: 20; y: 194; width: parent.width - 40; height: 110
                        Rectangle { width: parent.width; height: 1; color: "#1affffff" }
                        Label { y: 10; text: "Процессы"; font.pixelSize: 11; opacity: .5 }
                        Column {
                            y: 30; width: parent.width; spacing: 6
                            Repeater {
                                model: root.top
                                Item {
                                    id: pr
                                    required property var modelData
                                    required property int index
                                    width: parent.width; height: 14
                                    Label { width: 104; elide: Text.ElideRight; text: pr.modelData.name; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                    Rectangle {
                                        x: 112; width: parent.width - 112 - 64; height: 5; radius: 2.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: "#14ffffff"
                                        Rectangle {
                                            height: parent.height; radius: 2.5
                                            width: Math.max(4, parent.width * Math.min(1, pr.modelData.kb / Math.max(1, root.top[0].kb)))
                                            color: pr.index === 0 ? root.hot : Qt.rgba(root.hot.r, root.hot.g, root.hot.b, .55)
                                            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    Label { anchors.right: parent.right; text: root.gb(pr.modelData.kb); font.pixelSize: 11; opacity: .75; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                // Кольцо
                Item {
                    visible: root.look === "ring"
                    anchors.fill: parent
                    Gauge { anchors.fill: parent; anchors.margins: 12; thick: 14 }
                    Column {
                        anchors.centerIn: parent; spacing: 0
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xF035B); font.pixelSize: 16; color: root.hot }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Math.round(root.shownRatio * 100) + "%"
                            font.pixelSize: 44; font.weight: Font.Light; font.letterSpacing: -2
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.num(root.used) + " / " + root.gb(root.total); font.pixelSize: 12; opacity: .65 }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "кэш " + root.gb(root.cache); font.pixelSize: 10; color: root.cacheColor; opacity: .85; topPadding: 2 }
                    }
                }

                // Капсула
                Item {
                    visible: root.look === "pill"
                    anchors.fill: parent
                    Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(0xF035B); font.pixelSize: 18; color: root.hot }
                    Rectangle {
                        id: pillTrack
                        x: 50; width: parent.width - 50 - 118; height: 10; radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#17ffffff"
                        Rectangle {   // cache, behind
                            height: parent.height; radius: 5
                            width: parent.width * Math.min(1, root.shownRatio + root.shownCache)
                            color: Qt.rgba(.5, .7, 1, .35)
                        }
                        Rectangle {
                            height: parent.height; radius: 5
                            width: Math.max(height, parent.width * root.shownRatio)
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: root.load(Math.max(0, root.shownRatio - .3)) }
                                GradientStop { position: 1; color: root.hot }
                            }
                        }
                    }
                    Column {
                        anchors.right: parent.right; anchors.rightMargin: 22; anchors.verticalCenter: parent.verticalCenter
                        Label { anchors.right: parent.right; text: root.num(root.used) + " / " + root.gb(root.total); font.pixelSize: 13; font.weight: Font.DemiBold }
                        Label { anchors.right: parent.right; text: Math.round(root.ratio * 100) + "% занято"; font.pixelSize: 10; opacity: .55 }
                    }
                }
            }

            MouseArea {
                id: resizeHandle
                anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                width: 22; height: 22
                cursorShape: Qt.SizeFDiagCursor
                hoverEnabled: true
                property real startX: 0
                property real startScale: 1
                onPressed: mouse => { startX = mapToItem(desktop.contentItem, mouse.x, mouse.y).x; startScale = root.curScale; }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(desktop.contentItem, mouse.x, mouse.y);
                    const limit = Math.min(1.8, (desktop.width - card.x) / root.baseWidth, (desktop.height - card.y) / root.baseHeight);
                    root.setScale(Math.max(Math.min(.6, limit), Math.min(limit, startScale + (p.x - startX) / root.baseWidth)));
                }
                onReleased: { saved.sync(); card.savePosition(); }
                onDoubleClicked: { root.setScale(1); saved.sync(); }
                Text { anchors.centerIn: parent; text: "◢"; color: resizeHandle.containsMouse ? "#ffffff" : "#50ffffff"; font.pixelSize: 12 }
            }
        }
    }
}
