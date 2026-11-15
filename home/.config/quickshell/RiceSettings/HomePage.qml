pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Start page: hero card with the clock, system meters, now playing,
// quick modes, the palette and all sections.
Item {
    id: page
    required property var sections
    property string wallpaper: ""
    property bool active: visible
    readonly property bool dirty: false
    readonly property bool loaded: true
    readonly property string status: ""
    signal openSection(string id)

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property date now: clock.date
    readonly property real hour: clock.date.getHours() + clock.date.getMinutes() / 60
    readonly property bool isDay: hour >= 6 && hour < 19
    // 0 at sunrise/sunset, .5 in the middle of the day/night
    readonly property real arcT: isDay ? (hour - 6) / 13 : ((hour + 24 - 19) % 24) / 11

    // System load
    property real cpu: 0
    property var cpuHistory: []
    property real ram: 0
    property string ramText: ""
    property real disk: 0
    property string diskText: ""
    property string uptime: ""
    property string kernel: ""
    property var _lastCpu: null

    function fmtGiB(kib) { return (kib / 1048576).toFixed(1); }
    function fmtUptime(sec) {
        var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return d > 0 ? d + "д " + h + "ч" : h > 0 ? h + "ч " + m + "м" : m + "м";
    }

    Process {
        id: pulse
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; cat /proc/uptime; df -Pk / | tail -1"]
        stdout: StdioCollector { onStreamFinished: {
            var lines = text.trim().split("\n");
            if (lines.length < 5) return;
            var c = lines[0].trim().split(/\s+/).slice(1).map(Number);
            var idle = c[3] + (c[4] || 0), total = c.reduce((a, b) => a + b, 0);
            if (page._lastCpu) {
                var dt = total - page._lastCpu.total;
                if (dt > 0) page.cpu = Math.max(0, Math.min(1, 1 - (idle - page._lastCpu.idle) / dt));
                var h = page.cpuHistory.slice(-29); h.push(page.cpu); page.cpuHistory = h;
            }
            page._lastCpu = { idle: idle, total: total };
            var memTotal = Number(lines[1].split(/\s+/)[1]), memAvail = Number(lines[2].split(/\s+/)[1]);
            page.ram = 1 - memAvail / memTotal;
            page.ramText = page.fmtGiB(memTotal - memAvail) + " / " + page.fmtGiB(memTotal) + " ГБ";
            page.uptime = page.fmtUptime(Number(lines[3].split(" ")[0]));
            var df = lines[4].trim().split(/\s+/);
            page.disk = Number(df[2]) / Number(df[1]);
            page.diskText = Math.round(Number(df[3]) / 1048576) + " ГБ свободно";
        } }
    }
    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector { onStreamFinished: page.kernel = text.trim().split("-")[0] }
    }
    Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: page.active; onTriggered: if (!pulse.running) pulse.running = true }

    // Media: the playing player first, then Spotify, then any
    readonly property var player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying) || players.find(p => /spotify/i.test(p.identity)) || players[0] || null;
    }
    property real trackPos: 0
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: page.active && page.player !== null
        onTriggered: page.trackPos = page.player ? Math.max(0, page.player.position) : 0
    }
    function mmss(t) { t = Math.max(0, Math.floor(t)); return Math.floor(t / 60) + ":" + Tokens.pad(t % 60); }

    // Quick modes: the state is read back from the system
    property bool focusMode: false
    property bool dnd: false
    property bool nightLight: false
    property bool gameMode: false
    property bool ambient: true

    Process {
        id: probe
        command: ["sh", "-c",
            "hyprctl -j getoption decoration:blur:enabled; echo; " +
            "pgrep -x hyprsunset >/dev/null && echo night=1 || echo night=0; " +
            "[ -f \"${XDG_RUNTIME_DIR:-/tmp}/rice-gamemode\" ] && echo game=1; " +
            "timeout 2 qs -c RiceDesktop ipc call notifications status 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: {
            var t = text;
            var blur = t.match(/"int"\s*:\s*(\d)/);
            page.gameMode = t.indexOf("game=1") >= 0;
            page.focusMode = !!blur && blur[1] === "0" && !page.gameMode;
            page.nightLight = t.indexOf("night=1") >= 0;
            page.dnd = t.indexOf("dnd-") >= 0;
        } }
    }
    Timer { interval: 4000; repeat: true; triggeredOnStart: true; running: page.active; onTriggered: if (!probe.running) probe.running = true }
    Process { id: actor; onExited: probeSoon.restart() }
    Timer { id: probeSoon; interval: 350; onTriggered: if (!probe.running) probe.running = true }
    function act(cmd) { actor.command = ["sh", "-c", cmd]; actor.running = true; }

    function toggleFocus() {
        focusMode = !focusMode;
        act(focusMode
            // Liquid turns off blur and shadows, animations stay
            ? "hyprctl --batch 'keyword animations:enabled 1; keyword decoration:blur:enabled 0; keyword decoration:shadow:enabled 0'"
            : "hyprctl reload");
    }
    function toggleGame() {
        gameMode = !gameMode;
        act(Quickshell.env("HOME") + "/.local/bin/rice-gamemode " + (gameMode ? "on" : "off"));
    }
    function toggleDnd() { dnd = !dnd; act("qs -c RiceDesktop ipc call notifications toggleDnd"); }
    function toggleNight() {
        nightLight = !nightLight;
        act(nightLight ? "pkill -x hyprsunset; setsid -f hyprsunset -t 4300 >/dev/null 2>&1" : "pkill -x hyprsunset");
    }

    FileView {
        id: prefs
        path: Quickshell.env("HOME") + "/.config/rice-theme/home.json"
        printErrors: false; preload: true
        onLoaded: { try { page.ambient = JSON.parse(text()).ambient !== false; } catch (e) {} }
    }
    function toggleAmbient() { ambient = !ambient; prefs.setText(JSON.stringify({ ambient: ambient }, null, 2) + "\n"); }


    // Card with a soft shadow and an optional small title
    component Panel: Item {
        id: panel
        property string caption: ""
        property color edge: Tokens.cyan
        property bool lifted: false
        default property alias content: inner.data

        Repeater {
            model: 3
            Rectangle {
                required property int index
                x: -index * 2; y: 4 + index * 3
                width: panel.width - 4 + index * 4; height: panel.height - 4
                radius: Tokens.radius + index * 2
                color: "#000000"
                opacity: panel.lifted ? .16 : .10
            }
        }
        Rectangle {
            x: panel.lifted ? -1 : 0
            y: panel.lifted ? -2 : 0
            width: parent.width - 4; height: parent.height - 4
            radius: Tokens.radius
            color: Tokens.surface
            Behavior on x { NumberAnimation { duration: 110 } }
            Behavior on y { NumberAnimation { duration: 110 } }

            Rectangle {
                anchors.fill: parent; radius: parent.radius; color: "transparent"
                border.width: 1; border.color: panel.lifted ? Tokens.alpha(panel.edge, .45) : "#0fffffff"
            }
            Rectangle {   // lighter top
                anchors.fill: parent; radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Tokens.alpha("#ffffff", .045) }
                    GradientStop { position: .55; color: Tokens.alpha("#ffffff", 0) }
                }
            }
            Text {
                visible: panel.caption.length > 0
                x: 16; y: 14
                text: panel.caption
                font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium
                color: Tokens.text2
            }
            Item {
                id: inner
                anchors.fill: parent; anchors.margins: 16
                anchors.topMargin: panel.caption ? 34 : 16
            }
        }
    }

    // Accent mark before section titles
    component Tick: Rectangle {
        width: 4; height: 16; radius: 2
        Layout.alignment: Qt.AlignVCenter
        gradient: Gradient {
            GradientStop { position: 0; color: Tokens.neon }
            GradientStop { position: 1; color: Tokens.duo ? Tokens.cyan : Tokens.alpha(Tokens.neon, .35) }
        }
    }
    component SectionTitle: Text {
        text: ""
        font.family: Tokens.display; font.pixelSize: Tokens.px(16); font.weight: Font.Medium; font.letterSpacing: .5
        color: Tokens.text
    }

    // System meter card: icon, big number, sparkline or detail, bar
    component Meter: Item {
        id: m
        property string title: ""
        property int icon: 0
        property real value: 0
        property string detail: ""
        property color tint: Tokens.neon
        property var history: null
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Rectangle {
                    width: 26; height: 26; radius: 8
                    color: Tokens.alpha(m.tint, .15)
                    border.width: 1; border.color: Tokens.alpha(m.tint, .25)
                    Text { anchors.centerIn: parent; text: Tokens.glyph(m.icon); font.family: Tokens.iconFont; font.pixelSize: 14; color: m.tint }
                }
                Text { text: m.title; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                Item { Layout.fillWidth: true }
                Text { visible: !m.history; text: m.detail; font.family: Tokens.font; font.pixelSize: Tokens.px(10); font.letterSpacing: .5; color: Tokens.text3 }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: Math.round(m.value * 100)
                    font.family: Tokens.display; font.pixelSize: Tokens.px(30); font.weight: Font.Medium
                    color: Tokens.text
                }
                Text {
                    Layout.alignment: Qt.AlignBottom; bottomPadding: 6
                    text: "%"; font.family: Tokens.display; font.pixelSize: Tokens.px(14); font.weight: Font.Medium
                    color: m.tint
                }
                Item { Layout.fillWidth: true }
                Canvas {   // sparkline with a soft area under it
                    id: spark
                    visible: !!m.history
                    Layout.preferredWidth: 112; Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: 4
                    property var data: m.history || []
                    property color c: m.tint
                    onDataChanged: requestPaint()
                    onCChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset();
                        var d = data, n = 30;
                        if (d.length < 2) return;
                        var step = width / (n - 1), off = n - d.length;
                        function px(i) { return (i + off) * step; }
                        function py(v) { return height - 2 - Math.min(1, v * 1.6 + .04) * (height - 4); }
                        ctx.beginPath(); ctx.moveTo(px(0), py(d[0]));
                        for (var i = 1; i < d.length; i++) {
                            var xm = (px(i - 1) + px(i)) / 2;
                            ctx.bezierCurveTo(xm, py(d[i - 1]), xm, py(d[i]), px(i), py(d[i]));
                        }
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, .95); ctx.lineWidth = 1.6; ctx.stroke();
                        ctx.lineTo(px(d.length - 1), height); ctx.lineTo(px(0), height); ctx.closePath();
                        var g = ctx.createLinearGradient(0, 0, 0, height);
                        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, .28)); g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0));
                        ctx.fillStyle = g; ctx.fill();
                        ctx.beginPath(); ctx.arc(px(d.length - 1), py(d[d.length - 1]), 2.5, 0, 2 * Math.PI);
                        ctx.fillStyle = "#ffffff"; ctx.fill();
                    }
                }
            }
            Item { Layout.preferredHeight: 8 }
            Rectangle {   // bar
                Layout.fillWidth: true
                implicitHeight: 6; radius: 3
                color: Tokens.alpha(m.tint, .12)
                Rectangle {
                    height: parent.height; radius: 3
                    width: Math.max(height, parent.width * Math.min(1, m.value))
                    Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Tokens.alpha(m.tint, .35) }
                        GradientStop { position: 1; color: m.value > .85 ? Tokens.danger : m.tint }
                    }
                }
            }
        }
    }

    Flickable {
        id: scroller
        anchors.fill: parent
        clip: true
        contentHeight: body.implicitHeight + 12
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: body
            width: scroller.width - 12
            y: 8
            spacing: 20

            Panel {
                Layout.fillWidth: true
                Layout.preferredHeight: 268
                edge: Tokens.neon
                Hero { home: page; anchors.fill: parent; anchors.margins: -16 }
            }

            // Meters
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Panel {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 124
                    edge: Tokens.cyan
                    Meter { anchors.fill: parent; title: "Процессор"; icon: 0xF0EE0; value: page.cpu; tint: Tokens.cyan; history: page.cpuHistory }
                }
                Panel {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 124
                    edge: Tokens.neon
                    Meter { anchors.fill: parent; title: "Память"; icon: 0xF035B; value: page.ram; detail: page.ramText; tint: Tokens.neon }
                }
                Panel {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 124
                    edge: Tokens.amber
                    Meter { anchors.fill: parent; title: "Диск"; icon: 0xF02CA; value: page.disk; detail: page.diskText; tint: Tokens.amber }
                }
            }

            // Now playing
            Panel {
                id: media
                visible: page.player !== null
                readonly property var p: page.player
                readonly property bool playing: !!p && p.isPlaying
                readonly property real len: p && p.length > 0 ? p.length : 0
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                edge: Tokens.acid
                RowLayout {
                    anchors.fill: parent
                    spacing: 16
                    ClippingRectangle {
                        Layout.preferredWidth: 88; Layout.preferredHeight: 88
                        radius: 14
                        color: Tokens.well
                        Image {
                            anchors.fill: parent
                            source: media.p ? media.p.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop; asynchronous: true
                            sourceSize.width: 200
                        }
                        Text {
                            anchors.centerIn: parent; visible: !media.p || !media.p.trackArtUrl
                            text: Tokens.glyph(0xF075A); font.family: Tokens.iconFont; font.pixelSize: 28; color: Tokens.text3
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: media.p ? (media.p.trackTitle || "Без названия") : ""
                            font.family: Tokens.font; font.pixelSize: Tokens.px(17); font.weight: Font.DemiBold
                            color: Tokens.text
                        }
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: media.p ? [media.p.trackArtist, media.p.identity].filter(x => !!x).join("  ·  ") : ""
                            font.family: Tokens.font; font.pixelSize: Tokens.px(11)
                            color: Tokens.text2
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text { text: page.mmss(page.trackPos); font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.text3 }
                            Rectangle {
                                Layout.fillWidth: true; height: 4; radius: 2
                                color: Tokens.alpha(Tokens.text, .1)
                                Rectangle {
                                    height: parent.height; radius: 2
                                    width: parent.width * (media.len ? Math.min(1, page.trackPos / media.len) : 0)
                                    color: Tokens.neon
                                    Behavior on width { NumberAnimation { duration: 900 } }
                                }
                            }
                            Text { text: media.len ? page.mmss(media.len) : "--:--"; font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.text3 }
                        }
                    }
                    Row {
                        spacing: 6
                        Repeater {
                            model: [
                                { g: 0xF04AE, act: "prev" },
                                { g: media.playing ? 0xF03E4 : 0xF040A, act: "play", big: true },
                                { g: 0xF04AD, act: "next" }
                            ]
                            Item {
                                id: btn
                                required property var modelData
                                width: btn.modelData.big ? 44 : 34; height: width
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: btn.modelData.big ? Tokens.acid : btnMouse.containsMouse ? Tokens.controlHover : "transparent"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Tokens.glyph(btn.modelData.g); font.family: Tokens.iconFont; font.pixelSize: btn.modelData.big ? 22 : 17
                                    color: btn.modelData.big ? Tokens.onAccent : Tokens.text
                                }
                                MouseArea {
                                    id: btnMouse
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var p = media.p; if (!p) return;
                                        if (btn.modelData.act === "prev" && p.canGoPrevious) p.previous();
                                        else if (btn.modelData.act === "next" && p.canGoNext) p.next();
                                        else if (btn.modelData.act === "play") p.togglePlaying();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Modes
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    spacing: 8
                    Tick {}
                    SectionTitle { text: Tokens.up("Режимы") }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.width > 760 ? 5 : 3
                    columnSpacing: 14; rowSpacing: 14

                    Repeater {
                        model: [
                            { key: "game",    title: "Игра",     icon: 0xF0297, tint: Tokens.neon,  on: page.gameMode },
                            { key: "focus",   title: "Liquid",   icon: 0xF058C, tint: Tokens.amber, on: page.focusMode },
                            { key: "dnd",     title: "Тишина",   icon: 0xF009B, tint: Tokens.neon,  on: page.dnd },
                            { key: "night",   title: "Ночь",     icon: 0xF0594, tint: "#ff8a3c",    on: page.nightLight },
                            { key: "ambient", title: "Анимация", icon: 0xF040A, tint: Tokens.cyan,  on: page.ambient }
                        ]
                        Panel {
                            id: mode
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 92
                            edge: mode.modelData.on ? mode.modelData.tint : Tokens.alpha(Tokens.text3, .9)
                            lifted: modeMouse.containsMouse
                            Item {
                                anchors.fill: parent
                                Rectangle {   // tint when the mode is on
                                    anchors.fill: parent; anchors.margins: -16
                                    radius: Tokens.radius
                                    opacity: mode.modelData.on ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 220 } }
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Tokens.alpha(mode.modelData.tint, .20) }
                                        GradientStop { position: 1; color: Tokens.alpha(mode.modelData.tint, .03) }
                                    }
                                    border.width: 1; border.color: Tokens.alpha(mode.modelData.tint, .35)
                                }
                                Rectangle {
                                    width: 34; height: 34; radius: 17
                                    color: mode.modelData.on ? mode.modelData.tint : Tokens.alpha("#ffffff", .06)
                                    border.width: mode.modelData.on ? 0 : 1; border.color: Tokens.alpha(Tokens.text, .08)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: Tokens.glyph(mode.modelData.icon)
                                        font.family: Tokens.iconFont; font.pixelSize: 17
                                        color: mode.modelData.on ? Tokens.base : Tokens.text2
                                    }
                                }
                                Rectangle {   // switch
                                    anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 6
                                    width: 38; height: 22; radius: 11
                                    color: mode.modelData.on ? mode.modelData.tint : Tokens.alpha(Tokens.text, .12)
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                    Rectangle {
                                        width: 16; height: 16; radius: 8; y: 3
                                        x: mode.modelData.on ? parent.width - width - 3 : 3
                                        color: mode.modelData.on ? "#ffffff" : Tokens.text2
                                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    }
                                }
                                Column {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    spacing: 2
                                    Text {
                                        text: Tokens.up(mode.modelData.title)
                                        font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.DemiBold
                                        color: Tokens.text
                                    }
                                }
                            }
                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var k = mode.modelData.key;
                                    if (k === "game") page.toggleGame();
                                    else if (k === "focus") page.toggleFocus();
                                    else if (k === "dnd") page.toggleDnd();
                                    else if (k === "night") page.toggleNight();
                                    else page.toggleAmbient();
                                }
                            }
                        }
                    }
                }
            }

            // Palette
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: !!Rice.Theme.palette.colors
                Tick {}
                SectionTitle { text: Tokens.up("Палитра") }
                Row {
                    spacing: 3
                    Repeater {
                        model: ["background", "surface", "highlight", "border", "accent", "muted", "foreground"]
                        Rectangle {
                            required property string modelData
                            width: 22; height: 22; radius: 11
                            color: (Rice.Theme.palette.colors || {})[modelData] || "transparent"
                            border.width: 1; border.color: swatchMouse.containsMouse ? Tokens.neon : Tokens.line
                            ToolTip.visible: swatchMouse.containsMouse; ToolTip.text: modelData + " " + color
                            MouseArea { id: swatchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openSection("themes") }
                        }
                    }
                }
            }

            // All sections
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                RowLayout {
                    spacing: 8
                    Tick {}
                    SectionTitle { text: Tokens.up("Разделы") }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.width > 820 ? 3 : 2
                    columnSpacing: 14; rowSpacing: 14
                    Repeater {
                        model: page.sections.filter(s => s.id !== "home")
                        Panel {
                            id: cart
                            required property var modelData
                            required property int index
                            readonly property color tint: Tokens.duo ? (index % 2 ? Tokens.cyan : Tokens.neon) : modelData.tint
                            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 64
                            edge: cartMouse.containsMouse ? cart.tint : Tokens.line
                            lifted: cartMouse.containsMouse
                            RowLayout {
                                anchors.fill: parent; spacing: 12
                                Rectangle {
                                    Layout.preferredWidth: 36; Layout.fillHeight: true; radius: Tokens.controlRadius
                                    color: cartMouse.containsMouse ? cart.tint : Tokens.alpha(cart.tint, .15)
                                    Text {
                                        anchors.centerIn: parent
                                        text: Tokens.glyph(cart.modelData.icon); font.family: Tokens.iconFont; font.pixelSize: Tokens.px(16)
                                        color: cartMouse.containsMouse ? Tokens.onAccent : cart.tint
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { Layout.fillWidth: true; text: Tokens.up(cart.modelData.name); font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.DemiBold; color: Tokens.text }
                                }
                                Text {
                                    text: Tokens.glyph(0xF0054)
                                    font.family: Tokens.iconFont; font.pixelSize: Tokens.px(14); font.weight: Font.Bold
                                    color: cartMouse.containsMouse ? cart.tint : Tokens.text3
                                    Layout.rightMargin: cartMouse.containsMouse ? 0 : 4
                                    Behavior on Layout.rightMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                }
                            }
                            MouseArea { id: cartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openSection(cart.modelData.id) }
                        }
                    }
                }
            }
        }
    }
}
