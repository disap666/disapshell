pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Desktop weather widget.
// Drag the card to move it, drag the ◢ corner to scale. Options live in
// ~/.config/rice-theme/weather.json (Settings -> Виджеты -> Погода).
// One widget of the merged RiceDesktop process (see ../RiceDesktop/shell.qml).
Scope {
    id: root
    property bool shown: true

    // options
    readonly property var optDefaults: ({ visible: true, onTop: false, look: "", layout: "wide", city: "", units: "c", wind: "ms", live: true, refresh: 20, demo: "" })
    // "Примерить погоду": show a chosen sky without changing the numbers
    readonly property var demoSky: ({ clear: [0, 0], partly: [40, 0], cloudy: [95, 0], fog: [100, 0], drizzle: [90, .3], rain: [100, 2.5], snow: [100, 1.5], storm: [100, 6] })[opts.demo] || null
    property var opts: optDefaults
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/weather.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var prev = JSON.stringify([root.opts.city, root.opts.units, root.opts.wind]);
            try { root.opts = Object.assign({}, root.optDefaults, JSON.parse(text())); } catch (e) {}
            root.shown = root.opts.visible !== false;
            if (JSON.stringify([root.opts.city, root.opts.units, root.opts.wind]) !== prev) root.refresh();
        }
    }
    // Looks. "sky"/"full" are the sky card; the rest are separate bodies (Look*.qml).
    readonly property var looks: ["sky", "full", "thermo", "window", "board", "dial", "type"]
    readonly property string look: looks.indexOf(opts.look) >= 0 ? opts.look : (opts.layout === "full" ? "full" : "sky")
    readonly property bool skyLook: look === "sky" || look === "full"
    readonly property string layout: look === "full" ? "full" : "wide"     // used by the sky card
    readonly property var sizes: ({ sky: [450, 210], full: [450, 690], thermo: [230, 420], window: [300, 360], board: [440, 300], dial: [320, 320], type: [420, 280] })
    readonly property real baseWidth: sizes[look][0]
    readonly property real baseHeight: sizes[look][1]
    readonly property bool live: opts.live !== false && shown
    readonly property date now: clock.date

    Settings {
        id: saved
        location: Qt.resolvedUrl("position.ini")
        property real left: -1
        property real top: 300
        property string scales: "{}"
    }
    readonly property real curScale: { try { return JSON.parse(saved.scales)[look] || 1; } catch (e) { return 1; } }
    function setScale(v) { var m = {}; try { m = JSON.parse(saved.scales); } catch (e) {} m[look] = v; saved.scales = JSON.stringify(m); }

    // data
    property var data: null
    readonly property bool ready: !!data && data.ok !== false && !!data.current
    readonly property var cur: ready ? data.current : null
    readonly property var today: ready ? data.daily[0] : null
    readonly property string tu: ready ? data.units.temp : "°"
    function t(v) { return Math.round(v) + "°"; }
    Process {
        id: fetcher
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/quickshell/RiceWeather/weather.py", root.opts.city || "", root.opts.units || "c", root.opts.wind || "ms"]
        stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); if (d.ok !== false || !root.data) root.data = d; } catch (e) {} } }
    }
    function refresh() { if (!fetcher.running) fetcher.running = true; }
    Timer { interval: Math.max(5, root.opts.refresh || 20) * 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string updated: {
        if (!ready) return "";
        var mins = Math.round((clock.date.getTime() / 1000 - data.fetched) / 60);
        return mins < 1 ? "только что" : mins + " мин назад";
    }

    function glyph(kind, day) {
        return String.fromCodePoint(({
            clear: day ? 0xF0599 : 0xF0594, partly: day ? 0xF0595 : 0xF0F31, cloudy: 0xF0590, fog: 0xF0591,
            drizzle: 0xF0F33, rain: 0xF0597, snow: 0xF0598, storm: 0xF067E
        })[kind] || 0xF0590);
    }
    function dayName(iso, i) {
        if (i === 0) return "Сегодня";
        if (i === 1) return "Завтра";
        var d = new Date(iso + "T12:00:00");
        var s = d.toLocaleDateString(Qt.locale("ru_RU"), "dddd");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    function windDir(deg) { return ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"][Math.round(deg / 45) % 8]; }
    // temperature -> colour (cold blue ... hot red), in °C
    function tempColor(v) {
        var c = (root.opts.units === "f") ? (v - 32) / 1.8 : v;
        var stops = [[-20, "#7aa7ff"], [0, "#7fd4ff"], [10, "#8fe3a8"], [20, "#ffd36b"], [30, "#ff8a4c"], [40, "#ff4d4d"]];
        for (var i = 1; i < stops.length; i++) if (c <= stops[i][0]) {
            var a = Qt.color(stops[i - 1][1]), b = Qt.color(stops[i][1]), k = (c - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
            k = Math.max(0, Math.min(1, k)); return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
        }
        return stops[stops.length - 1][1];
    }

    IpcHandler {
        target: "weather"
        function toggle(): void { root.shown = !root.shown; }
        function show(): void { root.shown = true; }
        function hide(): void { root.shown = false; }
        function refresh(): void { root.refresh(); }
        function place(x: real, y: real): void {
            card.x = Math.max(0, Math.min(x, desktop.width - card.width));
            card.y = Math.max(0, Math.min(y, desktop.height - card.height));
            card.savePosition();
        }
        function resize(scale: real): void { root.setScale(Math.max(.6, Math.min(1.8, scale))); saved.sync(); }
        function status(): string {
            return JSON.stringify({ shown: root.shown, look: root.look, x: card.x, y: card.y, width: card.width, height: card.height, scale: root.curScale,
                deskWidth: desktop.width, deskHeight: desktop.height, place: root.ready ? root.data.place : "", temp: root.cur ? root.cur.temp : null,
                desc: root.cur ? root.cur.desc : "", stale: root.ready ? !!root.data.stale : false, error: root.data ? (root.data.error || "") : "" });
        }
    }

    // shared text styles
    component Label: Text {
        color: "#ffffff"
        font.family: Rice.Theme.fontFamily
        style: Text.Raised; styleColor: "#30000000"
    }

    PanelWindow {
        id: desktop
        visible: root.shown
        anchors { top: true; right: true; bottom: true; left: true }
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-weather"
        WlrLayershell.layer: root.opts.onTop ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: card }

        Item {
            id: card
            readonly property real uiScale: Math.min(root.curScale, desktop.width / root.baseWidth, desktop.height / root.baseHeight)
            width: root.baseWidth * uiScale
            height: root.baseHeight * uiScale
            x: Math.max(0, Math.min(saved.left < 0 ? 24 : saved.left, desktop.width - width))
            y: Math.max(0, Math.min(saved.top, desktop.height - height))
            Behavior on height { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
            Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.InOutCubic } }
            function savePosition() { saved.left = x; saved.top = y; saved.sync(); }

            Item {
                id: body
                width: root.baseWidth; height: root.baseHeight
                scale: card.uiScale; transformOrigin: Item.TopLeft

                // other looks: drag anywhere, body comes from Look*.qml
                MouseArea {
                    visible: !root.skyLook
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: card
                    drag.minimumX: 0; drag.maximumX: Math.max(0, desktop.width - card.width)
                    drag.minimumY: 0; drag.maximumY: Math.max(0, desktop.height - card.height)
                    drag.threshold: 3
                    onReleased: card.savePosition()
                    onCanceled: card.savePosition()
                    onDoubleClicked: root.refresh()
                }
                Loader {
                    active: !root.skyLook
                    anchors.fill: parent
                    sourceComponent: ({ thermo: thermoC, window: windowC, board: boardC, dial: dialC, type: typeC })[root.look] || null
                }
                Component { id: thermoC; LookThermo { w: root } }
                Component { id: windowC; LookWindow { w: root } }
                Component { id: boardC;  LookBoard  { w: root } }
                Component { id: dialC;   LookDial   { w: root } }
                Component { id: typeC;   LookType   { w: root } }

                Item {
                visible: root.skyLook
                anchors.fill: parent
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 30
                    color: "#1a1d2b"
                    Sky {
                        anchors.fill: parent
                        kind: root.demoSky ? root.opts.demo : root.cur ? root.cur.kind : "cloudy"
                        cloud: root.demoSky ? root.demoSky[0] : root.cur ? root.cur.cloud : 50
                        precip: root.demoSky ? root.demoSky[1] : root.cur ? root.cur.precip : 0
                        wind: root.cur ? (root.opts.wind === "kmh" ? root.cur.wind / 3.6 : root.cur.wind) : 2
                        sunrise: root.today ? root.today.sunrise : "07:00"
                        sunset: root.today ? root.today.sunset : "17:00"
                        live: root.live
                        now: clock.date
                    }
                    Rectangle {   // legibility: soft shade where text sits
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#33000000" }
                            GradientStop { position: .4; color: "#00000000" }
                            GradientStop { position: 1; color: root.layout === "full" ? "#8c000000" : "#59000000" }
                        }
                    }
                }
                Rectangle { anchors.fill: parent; radius: 30; color: "transparent"; border.width: 1; border.color: "#40ffffff" }
                Rectangle { x: 30; y: 1; width: parent.width - 60; height: 1; color: "#59ffffff" }

                // drag the card from anywhere
                MouseArea {
                    anchors.fill: parent
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: card
                    drag.minimumX: 0; drag.maximumX: Math.max(0, desktop.width - card.width)
                    drag.minimumY: 0; drag.maximumY: Math.max(0, desktop.height - card.height)
                    drag.threshold: 3
                    onReleased: card.savePosition()
                    onCanceled: card.savePosition()
                    onDoubleClicked: root.refresh()
                }

                // no data yet
                Column {
                    visible: !root.ready
                    anchors.centerIn: parent; spacing: 6
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: String.fromCodePoint(0xF0590); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 34 }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.data && root.data.error ? root.data.error : "Загрузка…"; font.pixelSize: 13 }
                }

                // current conditions (all layouts)
                Item {
                    id: now
                    visible: root.ready
                    x: 22; y: 18
                    width: root.layout === "wide" ? 200 : parent.width - 44
                    height: 172
                    Row {
                        spacing: 5
                        Label { text: String.fromCodePoint(0xF034E); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Label {
                            width: Math.min(implicitWidth, now.width - 60); elide: Text.ElideRight
                            text: root.ready ? root.data.place : ""
                            font.pixelSize: 14; font.weight: Font.DemiBold
                        }
                    }
                    Label {
                        y: 22
                        text: root.cur ? Math.round(root.cur.temp) + "°" : ""
                        font.pixelSize: root.layout === "compact" ? 58 : 66; font.weight: Font.Light
                        font.letterSpacing: -2
                    }
                    Label {
                        anchors.right: parent.right; y: 30
                        visible: root.layout !== "wide"
                        text: root.cur ? root.glyph(root.cur.kind, root.cur.day) : ""
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.layout === "compact" ? 30 : 42
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        spacing: 1
                        Label { width: parent.width; elide: Text.ElideRight; text: root.cur ? root.cur.desc : ""; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Label {
                            width: parent.width; elide: Text.ElideRight
                            text: root.today ? "Макс. " + root.t(root.today.max) + "  Мин. " + root.t(root.today.min) : ""
                            font.pixelSize: 12; opacity: .9
                        }
                        Label {
                            visible: root.layout !== "compact"
                            width: parent.width; elide: Text.ElideRight
                            text: root.cur ? "Ощущается как " + root.t(root.cur.feels) : ""
                            font.pixelSize: 11; opacity: .75
                        }
                    }
                }

                // summary pill (wide + full)
                Rectangle {
                    id: summaryPill
                    visible: root.ready && root.layout !== "compact"
                    x: root.layout === "wide" ? 236 : 22
                    y: root.layout === "wide" ? 18 : 200
                    width: root.layout === "wide" ? parent.width - 236 - 22 : parent.width - 44
                    height: summaryText.implicitHeight + 16
                    radius: 14
                    color: "#2effffff"; border.width: 1; border.color: "#26ffffff"
                    Row {
                        x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Label { text: String.fromCodePoint(0xF0F2F); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter; visible: root.layout === "full" }
                        Label {
                            id: summaryText
                            width: summaryPill.width - (root.layout === "full" ? 46 : 24)
                            wrapMode: Text.WordWrap
                            text: root.ready ? root.data.summary : ""
                            font.pixelSize: 12; font.weight: Font.DemiBold
                        }
                    }
                }

                // hourly strip (wide: 6 h; full: 12 h with curve)
                Item {
                    id: hours
                    visible: root.ready && root.layout !== "compact"
                    readonly property int n: root.layout === "full" ? 12 : 6
                    readonly property var list: root.ready ? root.data.hourly.slice(0, n) : []
                    x: root.layout === "wide" ? 236 : 22
                    y: root.layout === "wide" ? summaryPill.y + summaryPill.height + 10 : 262
                    width: root.layout === "wide" ? parent.width - 236 - 22 : parent.width - 44
                    height: root.layout === "wide" ? parent.height - y - 18 : 112
                    readonly property real colW: width / Math.max(1, n)
                    readonly property var temps: list.map(h => h.temp)
                    readonly property real lo: temps.length ? Math.min.apply(null, temps) : 0
                    readonly property real hi: temps.length ? Math.max.apply(null, temps) : 1
                    function ty(v) { var top = 40, bot = height - 30; return hi === lo ? (top + bot) / 2 : bot - (v - lo) / (hi - lo) * (bot - top); }

                    Canvas {   // temperature curve + precipitation chance (full only)
                        visible: root.layout === "full"
                        anchors.fill: parent
                        property var dep: hours.list
                        onDepChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d"), L = hours.list; ctx.reset();
                            if (L.length < 2) return;
                            function px(i) { return hours.colW * (i + .5); }
                            for (var i = 0; i < L.length; i++) if (L[i].pop > 0) {   // rain chance bars
                                var bh = (L[i].pop / 100) * 20;
                                ctx.fillStyle = "rgba(127,200,255," + (0.25 + L[i].pop / 250) + ")";
                                ctx.fillRect(px(i) - 7, hours.height - 4 - bh, 14, bh);
                            }
                            ctx.beginPath(); ctx.moveTo(px(0), hours.ty(L[0].temp));
                            for (var k = 1; k < L.length; k++) { var xm = (px(k - 1) + px(k)) / 2; ctx.bezierCurveTo(xm, hours.ty(L[k - 1].temp), xm, hours.ty(L[k].temp), px(k), hours.ty(L[k].temp)); }
                            var g = ctx.createLinearGradient(0, 0, width, 0);
                            g.addColorStop(0, root.tempColor(L[0].temp)); g.addColorStop(1, root.tempColor(L[L.length - 1].temp));
                            ctx.strokeStyle = g; ctx.lineWidth = 3; ctx.lineCap = "round"; ctx.stroke();
                        }
                    }
                    Repeater {
                        model: hours.list
                        Item {
                            id: hr
                            required property var modelData
                            required property int index
                            x: hours.colW * index; width: hours.colW; height: hours.height
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 0
                                text: hr.index === 0 ? "Сейчас" : hr.modelData.time.slice(-5, -3)
                                font.pixelSize: 11; font.weight: hr.index === 0 ? Font.Bold : Font.Normal; opacity: .85
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 16
                                text: root.glyph(hr.modelData.kind, hr.modelData.day)
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 17
                            }
                            Label {   // wide: plain number; full: number on the curve
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: root.layout === "full" ? hours.ty(hr.modelData.temp) - 20 : hours.height - 20
                                text: root.t(hr.modelData.temp)
                                font.pixelSize: 13; font.weight: Font.DemiBold
                            }
                            Rectangle {   // dot on the curve
                                visible: root.layout === "full"
                                anchors.horizontalCenter: parent.horizontalCenter; y: hours.ty(hr.modelData.temp) - 4
                                width: 8; height: 8; radius: 4; color: "#ffffff"
                                border.width: 2; border.color: root.tempColor(hr.modelData.temp)
                            }
                        }
                    }
                }

                // detail tiles (full)
                Row {
                    visible: root.ready && root.layout === "full"
                    x: 22; y: 386
                    spacing: 8
                    Repeater {
                        model: root.cur ? [
                            { g: 0xF059D, v: (Math.round(root.cur.wind * 10) / 10) + " " + root.data.units.wind, s: "Ветер · " + root.windDir(root.cur.windDir), arrow: true },
                            { g: 0xF058E, v: root.cur.humidity + "%", s: "Влажность" },
                            { g: 0xF029A, v: root.cur.pressure + "", s: "мм рт. ст." },
                            { g: 0xF0599, v: root.today ? (Math.round(root.today.uv * 10) / 10) + "" : "-", s: "УФ-индекс" },
                            { g: 0xF059C, v: root.today ? root.today.sunset : "", s: "Закат · " + (root.today ? root.today.sunrise : "") }
                        ] : []
                        Rectangle {
                            id: tile
                            required property var modelData
                            width: (450 - 44 - 4 * 8) / 5; height: 70; radius: 16
                            color: "#26ffffff"; border.width: 1; border.color: "#1fffffff"
                            Column {
                                anchors.centerIn: parent; spacing: 2
                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 18; height: 18
                                    Label {
                                        anchors.centerIn: parent
                                        text: tile.modelData.arrow ? "↓" : String.fromCodePoint(tile.modelData.g)
                                        font.family: tile.modelData.arrow ? Rice.Theme.fontFamily : "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16; font.weight: Font.Bold
                                        rotation: tile.modelData.arrow && root.cur ? root.cur.windDir : 0   // arrow points where the wind blows
                                    }
                                }
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.v; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.s; font.pixelSize: 9; opacity: .75 }
                            }
                        }
                    }
                }

                // 7 days with range bars (full)
                Column {
                    id: week
                    visible: root.ready && root.layout === "full"
                    x: 22; y: 468
                    width: parent.width - 44
                    spacing: 0
                    readonly property var days: root.ready ? root.data.daily.slice(0, 7) : []
                    readonly property real lo: days.length ? Math.min.apply(null, days.map(d => d.min)) : 0
                    readonly property real hi: days.length ? Math.max.apply(null, days.map(d => d.max)) : 1
                    Repeater {
                        model: week.days
                        Item {
                            id: dayRow
                            required property var modelData
                            required property int index
                            width: week.width; height: 28
                            Rectangle { visible: dayRow.index > 0; width: parent.width; height: 1; color: "#1fffffff" }
                            Label { x: 0; anchors.verticalCenter: parent.verticalCenter; width: 92; elide: Text.ElideRight; text: root.dayName(dayRow.modelData.date, dayRow.index); font.pixelSize: 13; font.weight: dayRow.index === 0 ? Font.Bold : Font.Normal }
                            Label { x: 96; anchors.verticalCenter: parent.verticalCenter; text: root.glyph(dayRow.modelData.kind, true); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
                            Label { x: 120; anchors.verticalCenter: parent.verticalCenter; visible: dayRow.modelData.pop >= 20; text: dayRow.modelData.pop + "%"; font.pixelSize: 10; color: "#a8dcff" }
                            Label { x: 160; width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: root.t(dayRow.modelData.min); font.pixelSize: 13; opacity: .7 }
                            Rectangle {   // week-wide range track
                                id: track
                                x: 204; width: parent.width - 204 - 44; height: 6; radius: 3
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#26ffffff"
                                readonly property real span: Math.max(1, week.hi - week.lo)
                                Rectangle {
                                    x: (dayRow.modelData.min - week.lo) / track.span * track.width
                                    width: Math.max(8, (dayRow.modelData.max - dayRow.modelData.min) / track.span * track.width)
                                    height: parent.height; radius: 3
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: root.tempColor(dayRow.modelData.min) }
                                        GradientStop { position: 1; color: root.tempColor(dayRow.modelData.max) }
                                    }
                                }
                                Rectangle {   // where "now" sits within today's range
                                    visible: dayRow.index === 0 && !!root.cur
                                    width: 10; height: 10; radius: 5; y: -2
                                    x: root.cur ? Math.max(0, Math.min(track.width, (root.cur.temp - week.lo) / track.span * track.width)) - 5 : 0
                                    color: "#ffffff"; border.width: 2; border.color: "#40000000"
                                }
                            }
                            Label { anchors.right: parent.right; width: 34; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; text: root.t(dayRow.modelData.max); font.pixelSize: 13; font.weight: Font.DemiBold }
                        }
                    }
                }

                // footer: freshness
                Label {
                    visible: root.ready
                    anchors.right: parent.right; anchors.rightMargin: 40; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
                    text: (root.data && root.data.stale ? "нет сети · " : "") + root.updated
                    font.pixelSize: 9; opacity: .55
                }
                }
            }

            // scale corner, same gesture as the music widget
            MouseArea {
                id: resizeHandle
                anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                width: 24; height: 24
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
                Text { anchors.centerIn: parent; text: "◢"; color: resizeHandle.containsMouse ? "#ffffff" : "#70ffffff"; font.pixelSize: 13 }
            }
        }
    }
}
