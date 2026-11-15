pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// "Виджеты": settings for the desktop widgets you already have.
// Tabs: RiceMusic and RiceWeather. The page
// moves/resizes it over IPC and writes behaviour options to
// ~/.config/rice-theme/music.json, which the widget reads live.
Flickable {
    id: page
    property string wallpaper: ""
    readonly property bool dirty: false
    readonly property bool loaded: true
    readonly property string status: ""

    clip: true
    contentHeight: body.implicitHeight + 16
    boundsBehavior: Flickable.StopAtBounds
    interactive: !dragging
    property bool dragging: false
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    property string tab: "music"
    readonly property var tabs: [{ id: "music", name: "Музыка", icon: 0xF075A, tint: "#d9bcff" }, { id: "weather", name: "Погода", icon: 0xF0590, tint: "#8cc0f2" }, { id: "memory", name: "Память", icon: 0xF035B, tint: "#8fe3a8" }]
    // which widget the page is talking to
    readonly property var target: tab === "memory"
        ? ({ qs: "RiceDesktop", ipc: "memory", file: "memory.json", bin: "rice-memory", name: "память" })
        : tab === "weather"
        ? ({ qs: "RiceDesktop", ipc: "weather", file: "weather.json", bin: "rice-weather", name: "погода" })
        : ({ qs: "RiceDesktop", ipc: "music", file: "music.json", bin: "rice-music", name: "плеер" })
    onTabChanged: { live = null; opts = optDefaults; if (!poll.running) poll.running = true; autoRead.running = true; }

    // Live state of the widget (polled over IPC while the page is open)
    property var live: null
    readonly property bool running: live !== null
    Process {
        id: poll
        command: ["qs", "ipc", "-c", page.target.qs, "call", page.target.ipc, "status"]
        stdout: StdioCollector { onStreamFinished: { try { page.live = JSON.parse(text); } catch (e) { page.live = null; } } }
        onExited: code => { if (code !== 0) page.live = null; }
    }
    Timer { interval: 1500; repeat: true; triggeredOnStart: true; running: page.visible && !page.dragging; onTriggered: if (!poll.running) poll.running = true }
    function ipc(args) { Quickshell.execDetached(["qs", "ipc", "-c", target.qs, "call", target.ipc].concat(args)); refresh.restart(); }
    Timer { id: refresh; interval: 250; onTriggered: if (!poll.running) poll.running = true }

    // Options file
    readonly property var optDefaults: tab === "memory"
        ? ({ visible: true, onTop: false, look: "card", interval: 2, procs: true, opacity: .82 })
        : tab === "weather"
        ? ({ visible: true, onTop: false, look: "", layout: "wide", city: "", units: "c", wind: "ms", live: true, refresh: 20, demo: "" })
        : ({ visible: true, onTop: false, player: "", lyricsOnStart: false, opacity: 1, style: "classic" })
    readonly property var looks: [
        { id: "classic",  name: "Классика" },
        { id: "vinyl",    name: "Винил" },
        { id: "square",   name: "Квадрат" },
        { id: "cassette", name: "Кассета" },
        { id: "pill",     name: "Капсула" },
        { id: "round",    name: "Круг" }
    ]
    property var opts: optDefaults
    FileView {
        id: optFile
        path: Quickshell.env("HOME") + "/.config/rice-theme/" + page.target.file
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.opts = Object.assign({}, page.optDefaults, JSON.parse(text())); } catch (e) {} }
    }
    function setOpt(key, value) {
        var next = Object.assign({}, opts); next[key] = value; opts = next;
        optFile.setText(JSON.stringify(next, null, 2) + "\n");
    }

    // Autostart line in hyprland.conf
    property bool autostart: true
    Process {
        id: autoRead
        running: true
        command: ["sh", "-c", "grep -qx 'exec-once = ~/.local/bin/" + page.target.bin + "' ~/.config/hypr/hyprland.conf && echo on || echo off"]
        stdout: StdioCollector { onStreamFinished: page.autostart = text.trim() === "on" }
    }
    function setAutostart(on) {
        autostart = on;
        Quickshell.execDetached(["sh", "-c", on
            ? "sed -i 's|^# exec-once = ~/.local/bin/" + target.bin + "$|exec-once = ~/.local/bin/" + target.bin + "|' ~/.config/hypr/hyprland.conf"
            : "sed -i 's|^exec-once = ~/.local/bin/" + target.bin + "$|# exec-once = ~/.local/bin/" + target.bin + "|' ~/.config/hypr/hyprland.conf"]);
    }

    // Geometry helpers (widget coords are inside its full-screen layer)
    readonly property var scr: Quickshell.screens[0]
    readonly property int screenW: scr ? scr.width : 1920
    readonly property int screenH: scr ? scr.height : 1080
    readonly property real deskW: live ? live.deskWidth : screenW
    readonly property real deskH: live ? live.deskHeight : screenH - 50
    readonly property real deskTop: screenH - deskH            // space taken by the bar
    function preset(where) {
        if (!live) return;
        var m = 24, w = live.width, h = live.height;
        var x = where.indexOf("l") >= 0 ? m : where.indexOf("r") >= 0 ? deskW - w - m : (deskW - w) / 2;
        var y = where.indexOf("t") >= 0 ? 8 : where.indexOf("b") >= 0 ? deskH - h - m : (deskH - h) / 2;
        ipc(["place", String(Math.round(x)), String(Math.round(y))]);
    }

    component Heading: RowLayout {
        id: heading
        property string title
        spacing: 8
        Text { text: Tokens.up(heading.title); font.family: Tokens.font; font.pixelSize: Tokens.px(17); font.weight: Font.ExtraBold; font.letterSpacing: Tokens.caps ? 2 : 0; color: Tokens.text }
    }

    ColumnLayout {
        id: body
        width: page.width - 12
        spacing: 20

        // Tabs: one per widget
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Segmented {
                model: page.tabs.map(t => t.name)
                current: Math.max(0, page.tabs.findIndex(t => t.id === page.tab))
                onActivated: index => page.tab = page.tabs[index].id
            }
            Item { Layout.fillWidth: true }
            Rectangle {   // live status chip
                implicitWidth: statusRow.implicitWidth + 18; implicitHeight: 26
                radius: 13
                color: "transparent"; border.width: 1; border.color: page.running ? Tokens.acid : Tokens.danger
                Row {
                    id: statusRow; anchors.centerIn: parent; spacing: 6
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 4; color: page.running ? Tokens.acid : Tokens.danger }
                    Text {
                        text: !page.running ? "не запущен" : !page.live.shown ? "скрыт"
                            : page.tab === "memory" ? "занято " + page.live.percent + "% · " + (page.live.used / 1048576).toFixed(1).replace(".", ",") + " ГБ"
                            : page.tab === "weather" ? (page.live.place ? page.live.place + " · " + Math.round(page.live.temp) + "° · " + page.live.desc.toLowerCase() : "загружается")
                            : page.live.player ? "играет · " + page.live.player : "запущен"
                        font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text
                    }
                }
            }
        }

        // Музыка
        ColumnLayout {
            visible: true
            Layout.fillWidth: true
            spacing: 20


            // Вид
            Heading { visible: page.tab === "music"; title: "Вид" }
            GridLayout {
                visible: page.tab === "music"
                Layout.fillWidth: true
                columns: page.width > 760 ? 3 : 2
                columnSpacing: 12; rowSpacing: 12
                Repeater {
                    model: page.looks
                    Item {
                        id: lk
                        required property var modelData
                        readonly property bool current: (page.opts.style || "classic") === modelData.id
                        Layout.fillWidth: true; Layout.preferredWidth: 1
                        implicitHeight: 154
                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius
                            color: lkMouse.containsMouse ? Tokens.cardStrong : Tokens.card
                            border.width: lk.current ? 2 : 1
                            border.color: lk.current ? Tokens.neon : Tokens.line
                        }
                        // stage with a miniature of the look
                        ClippingRectangle {
                            id: stage
                            x: 10; y: 10; width: parent.width - 20; height: 104
                            radius: Math.max(0, Tokens.radius - 4)
                            color: "#1a1622"
                            Image { anchors.fill: parent; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; sourceSize.width: 400; opacity: .35; asynchronous: true }
                            readonly property color glassTop: "#8c7aa8"
                            readonly property color glassBot: "#2c2638"
                            // classic: wide plate
                            Item {
                                visible: lk.modelData.id === "classic"
                                anchors.centerIn: parent; width: 168; height: 42
                                Rectangle { anchors.fill: parent; radius: 10; gradient: Gradient { GradientStop { position: 0; color: stage.glassTop } GradientStop { position: 1; color: stage.glassBot } } border.width: 1; border.color: "#60e4d4f6" }
                                Rectangle { x: 6; y: 6; width: 30; height: 30; radius: 6; color: Tokens.neon; opacity: .8 }
                                Rectangle { x: 44; y: 9; width: 70; height: 4; radius: 2; color: "#faf6ff" }
                                Rectangle { x: 44; y: 17; width: 44; height: 3; radius: 1.5; color: "#aee6ddef" }
                                Rectangle { x: 44; y: 31; width: 116; height: 2; radius: 1; color: "#40ffffff"; Rectangle { width: 70; height: 2; color: "#c5a6e9" } }
                            }
                            // vinyl
                            Item {
                                visible: lk.modelData.id === "vinyl"
                                anchors.centerIn: parent; width: 74; height: 90
                                Rectangle { anchors.fill: parent; radius: 10; gradient: Gradient { GradientStop { position: 0; color: stage.glassTop } GradientStop { position: 1; color: stage.glassBot } } border.width: 1; border.color: "#60e4d4f6" }
                                Item {
                                    x: 7; y: 6; width: 60; height: 60
                                    RotationAnimation on rotation { running: page.visible && lkMouse.containsMouse; from: 0; to: 360; duration: 1800; loops: Animation.Infinite }
                                    Rectangle { anchors.fill: parent; radius: 30; color: "#121016" }
                                    Repeater { model: 4; Rectangle { required property int index; anchors.centerIn: parent; width: 56 - index * 8; height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: "#22ffffff" } }
                                    Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: Tokens.neon }
                                }
                                Rectangle { x: 60; y: 2; width: 2.5; height: 32; radius: 1; color: "#e2dbea"; rotation: 26; transformOrigin: Item.Top }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 74; width: 40; height: 3; radius: 1.5; color: "#faf6ff" }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 81; width: 26; height: 2; radius: 1; color: "#aee6ddef" }
                            }
                            // square
                            Item {
                                visible: lk.modelData.id === "square"
                                anchors.centerIn: parent; width: 80; height: 80
                                Rectangle { anchors.fill: parent; radius: 12; gradient: Gradient { GradientStop { position: 0; color: Tokens.neon } GradientStop { position: 1; color: Tokens.cyan } } }
                                Rectangle { anchors.fill: parent; radius: 12; gradient: Gradient { GradientStop { position: .45; color: "#00000000" } GradientStop { position: 1; color: "#c0000000" } } }
                                Rectangle { x: 8; y: 58; width: 46; height: 4; radius: 2; color: "#ffffff" }
                                Rectangle { x: 8; y: 66; width: 30; height: 3; radius: 1.5; color: "#c8ffffff" }
                                Rectangle { anchors.bottom: parent.bottom; x: 4; width: 44; height: 2; color: "#ffffff" }
                            }
                            // cassette
                            Item {
                                visible: lk.modelData.id === "cassette"
                                anchors.centerIn: parent; width: 120; height: 78
                                Rectangle { anchors.fill: parent; radius: 8; gradient: Gradient { GradientStop { position: 0; color: stage.glassTop } GradientStop { position: 1; color: stage.glassBot } } border.width: 1; border.color: "#60e4d4f6" }
                                Rectangle {
                                    x: 9; y: 7; width: 102; height: 44; radius: 4; color: "#eee5f7"
                                    Rectangle { x: 6; y: 5; width: 50; height: 4; radius: 2; color: "#2a2438" }
                                    Rectangle { y: 12; width: parent.width; height: 2; color: "#c5a6e9" }
                                    Rectangle {
                                        x: 18; y: 18; width: 66; height: 20; radius: 10; color: "#2a2438"
                                        Repeater {
                                            model: 2
                                            Rectangle {
                                                required property int index
                                                x: index ? 48 : 2; y: 2; width: 16; height: 16; radius: 8; color: "#eee5f7"
                                                RotationAnimation on rotation { running: page.visible && lkMouse.containsMouse; from: 0; to: 360; duration: 1600; loops: Animation.Infinite }
                                                Rectangle { anchors.centerIn: parent; width: 10; height: 2; color: "#2a2438" }
                                                Rectangle { anchors.centerIn: parent; width: 2; height: 10; color: "#2a2438" }
                                            }
                                        }
                                    }
                                }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 60; width: 36; height: 6; radius: 3; color: "#40ffffff" }
                            }
                            // pill
                            Item {
                                visible: lk.modelData.id === "pill"
                                anchors.centerIn: parent; width: 170; height: 30
                                Rectangle { anchors.fill: parent; radius: 15; gradient: Gradient { GradientStop { position: 0; color: stage.glassTop } GradientStop { position: 1; color: stage.glassBot } } border.width: 1; border.color: "#60e4d4f6" }
                                Rectangle { width: 92; height: 30; radius: 15; color: "#26c5a6e9" }
                                Rectangle { x: 4; y: 4; width: 22; height: 22; radius: 11; color: Tokens.neon }
                                Rectangle { x: 32; y: 8; width: 60; height: 4; radius: 2; color: "#faf6ff" }
                                Rectangle { x: 32; y: 16; width: 38; height: 3; radius: 1.5; color: "#aee6ddef" }
                                Row { x: 126; y: 10; spacing: 6; Repeater { model: 3; Rectangle { width: 7; height: 10; radius: 2; color: "#f2edf8" } } }
                            }
                            // round
                            Item {
                                visible: lk.modelData.id === "round"
                                anchors.centerIn: parent; width: 84; height: 96
                                Rectangle { width: 84; height: 84; radius: 42; gradient: Gradient { GradientStop { position: 0; color: stage.glassTop } GradientStop { position: 1; color: stage.glassBot } } border.width: 1; border.color: "#60e4d4f6" }
                                Rectangle { x: 5; y: 5; width: 74; height: 74; radius: 37; color: "transparent"; border.width: 3; border.color: "#c5a6e9" }
                                Rectangle { x: 13; y: 13; width: 58; height: 58; radius: 29; color: Tokens.neon }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 88; width: 56; height: 8; radius: 4; color: "#552a2438"; border.width: 1; border.color: "#40e4d4f6" }
                            }
                        }
                        Column {
                            x: 14; y: 122; width: parent.width - 28
                            spacing: 2
                            RowLayout {
                                width: parent.width
                                Text { Layout.fillWidth: true; text: lk.modelData.name; font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.Bold; color: Tokens.text }
                                Text { visible: lk.current; text: "✓"; font.pixelSize: 14; font.weight: Font.Bold; color: Tokens.neon }
                            }
                        }
                        MouseArea { id: lkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setOpt("style", lk.modelData.id) }
                    }
                }
            }

            // Погода
            Heading { visible: page.tab === "weather"; title: "Вид" }
            GridLayout {
                visible: page.tab === "weather"
                Layout.fillWidth: true
                columns: page.width > 760 ? 4 : 3
                columnSpacing: 12; rowSpacing: 12
                Repeater {
                    model: [
                        { id: "sky",    name: "Небо" },
                        { id: "full",   name: "Сводка" },
                        { id: "thermo", name: "Термометр" },
                        { id: "window", name: "Окно" },
                        { id: "board",  name: "Табло" },
                        { id: "dial",   name: "Циферблат" },
                        { id: "type",   name: "Типографика" }
                    ]
                    Item {
                        id: wl
                        required property var modelData
                        readonly property bool current: (page.live && page.live.look ? page.live.look : (page.opts.look || "sky")) === modelData.id
                        Layout.fillWidth: true; Layout.preferredWidth: 1
                        implicitHeight: 154
                        Rectangle {
                            anchors.fill: parent; radius: Tokens.radius
                            color: wlMouse.containsMouse ? Tokens.cardStrong : Tokens.card
                            border.width: wl.current ? 2 : 1; border.color: wl.current ? Tokens.neon : Tokens.line
                        }
                        ClippingRectangle {
                            x: 10; y: 10; width: parent.width - 20; height: 104
                            radius: Math.max(0, Tokens.radius - 4)
                            color: "#1a1622"
                            Image { anchors.fill: parent; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; sourceSize.width: 400; opacity: .3; asynchronous: true }

                            // sky
                            Item {
                                visible: wl.modelData.id === "sky"
                                anchors.centerIn: parent; width: 120; height: 56
                                Rectangle { anchors.fill: parent; radius: 12; gradient: Gradient { GradientStop { position: 0; color: "#2f6fd1" } GradientStop { position: 1; color: "#8cc0f2" } } }
                                Rectangle { x: 54; y: -6; width: 40; height: 18; radius: 9; color: "#ffffff"; opacity: .6 }
                                Text { x: 8; y: 6; text: "4°"; color: "#ffffff"; font.pixelSize: 22; font.weight: Font.Light }
                                Row { x: 60; y: 36; spacing: 4; Repeater { model: 6; Rectangle { width: 5; height: 5; radius: 2.5; color: "#ffffff" } } }
                            }
                            // full
                            Item {
                                visible: wl.modelData.id === "full"
                                anchors.centerIn: parent; width: 58; height: 90
                                Rectangle { anchors.fill: parent; radius: 10; gradient: Gradient { GradientStop { position: 0; color: "#24324f" } GradientStop { position: 1; color: "#0e121c" } } }
                                Text { x: 6; y: 3; text: "4°"; color: "#ffffff"; font.pixelSize: 16; font.weight: Font.Light }
                                Canvas { x: 4; y: 28; width: 50; height: 16; onPaint: { var c = getContext("2d"); c.strokeStyle = "#8fe3a8"; c.lineWidth = 2; c.beginPath(); c.moveTo(0, 12); c.bezierCurveTo(15, 12, 20, 2, 50, 4); c.stroke(); } }
                                Repeater { model: 5; Rectangle { required property int index; x: 6; y: 50 + index * 7; width: 46; height: 3; radius: 1.5; color: "#30ffffff"
                                    Rectangle { x: 8 + (index * 7) % 14; width: 16 + (index * 5) % 10; height: 3; radius: 1.5; color: index % 2 ? "#ffd36b" : "#8fe3a8" } } }
                            }
                            // thermometer
                            Item {
                                visible: wl.modelData.id === "thermo"
                                anchors.centerIn: parent; width: 50; height: 92
                                Rectangle { anchors.fill: parent; radius: 12; color: "#1b2030" }
                                Rectangle { x: 10; y: 8; width: 8; height: 62; radius: 4; color: "#30ffffff" }
                                Rectangle {
                                    x: 12; width: 4; radius: 2; color: "#7fd4ff"
                                    height: wlMouse.containsMouse ? 52 : 26; y: 70 - height
                                    Behavior on height { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                                }
                                Rectangle { x: 6; y: 66; width: 16; height: 16; radius: 8; color: "#7fd4ff" }
                                Text { x: 26; y: 10; text: "4°"; color: "#ffffff"; font.pixelSize: 14 }
                                Repeater { model: 6; Rectangle { required property int index; x: 20; y: 12 + index * 10; width: 4; height: 1; color: "#80ffffff" } }
                            }
                            // window
                            Item {
                                visible: wl.modelData.id === "window"
                                anchors.centerIn: parent; width: 72; height: 88
                                Rectangle { width: 72; height: 66; radius: 5; color: "#efe6d8" }
                                Rectangle { x: 5; y: 5; width: 62; height: 56; radius: 2; gradient: Gradient { GradientStop { position: 0; color: "#20304a" } GradientStop { position: 1; color: "#3c4a6a" } } }
                                Repeater { model: 7; Rectangle { required property int index; x: 8 + index * 8; y: 10 + (index * 13) % 40; width: 3; height: 4; radius: 1.5; color: "#90ffffff" } }
                                Rectangle { x: 34; y: 5; width: 4; height: 56; color: "#efe6d8" }
                                Rectangle { x: 5; y: 31; width: 62; height: 4; color: "#efe6d8" }
                                Rectangle { x: -3; y: 64; width: 78; height: 5; radius: 2; color: "#e3d6c2" }
                                Rectangle { x: 6; y: 72; width: 60; height: 14; radius: 3; color: "#2e3a33"; border.width: 1.5; border.color: "#7a5a3c"
                                    Rectangle { x: 8; y: 6; width: 36; height: 2; radius: 1; color: "#eef2ea" } }
                            }
                            // board
                            Item {
                                visible: wl.modelData.id === "board"
                                anchors.centerIn: parent; width: 120; height: 80
                                Rectangle { anchors.fill: parent; radius: 6; color: "#121214"; border.width: 1; border.color: "#2b2b30" }
                                Rectangle { x: 8; y: 7; width: 50; height: 4; radius: 2; color: "#ffb000" }
                                Row { x: 8; y: 16; spacing: 2; Repeater { model: 3; Rectangle { required property int index; width: 13; height: 18; radius: 2; color: "#1d1d20"
                                    Rectangle { y: 9; width: 13; height: 1; color: "#000000" }
                                    Text { anchors.centerIn: parent; text: ["", "", "4"][parent.index]; color: "#f4f0e6"; font.family: "JetBrains Mono"; font.pixelSize: 12; font.weight: Font.Bold } } } }
                                Repeater { model: 4; Rectangle { required property int index; x: 8; y: 42 + index * 9; width: 104; height: 3; radius: 1.5; color: "#3a3833"
                                    Rectangle { width: 18; height: 3; radius: 1.5; color: "#f4f0e6" } } }
                            }
                            // dial
                            Item {
                                visible: wl.modelData.id === "dial"
                                anchors.centerIn: parent; width: 88; height: 88
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var c = getContext("2d"), r = width / 2 - 8, cols = ["#7fd4ff", "#8fe3a8", "#ffd36b", "#ff8a4c"];
                                        c.lineWidth = 10;
                                        for (var i = 0; i < 24; i++) { c.strokeStyle = cols[Math.floor(Math.abs(Math.sin(i / 7)) * 3.99)]; c.beginPath(); c.arc(width / 2, height / 2, r, i / 24 * 6.283 - 1.57 + .03, (i + 1) / 24 * 6.283 - 1.57 - .03); c.stroke(); }
                                    }
                                }
                                Text { anchors.centerIn: parent; text: "4°"; color: "#ffffff"; font.pixelSize: 18; font.weight: Font.Light }
                            }
                            // type
                            Item {
                                visible: wl.modelData.id === "type"
                                anchors.centerIn: parent; width: 120; height: 80
                                Rectangle { anchors.fill: parent; radius: 3; color: "#f3efe7" }
                                Rectangle { width: 3; height: parent.height; color: "#7fd4ff" }
                                Text { x: 8; y: 2; text: "4"; font.family: "Georgia"; font.pixelSize: 54; font.weight: Font.Bold; color: "#17140f" }
                                Text { x: 46; y: 16; text: "пасмурно"; font.family: "Georgia"; font.italic: true; font.pixelSize: 13; color: "#17140f" }
                                Rectangle { x: 46; y: 36; width: 60; height: 2; color: "#4a453d"; opacity: .5 }
                                Canvas { x: 8; y: 60; width: 104; height: 14; onPaint: { var c = getContext("2d"); c.strokeStyle = "#17140f"; c.lineWidth = 1; c.beginPath(); c.moveTo(0, 10); c.lineTo(20, 3); c.lineTo(40, 8); c.lineTo(60, 9); c.lineTo(80, 6); c.lineTo(104, 4); c.stroke(); } }
                            }
                        }
                        Column {
                            x: 14; y: 122; width: parent.width - 28; spacing: 2
                            RowLayout {
                                width: parent.width
                                Text { Layout.fillWidth: true; text: wl.modelData.name; font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.Bold; color: Tokens.text }
                                Text { visible: wl.current; text: "✓"; font.pixelSize: 14; font.weight: Font.Bold; color: Tokens.neon }
                            }
                        }
                        MouseArea { id: wlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setOpt("look", wl.modelData.id) }
                    }
                }
            }

            Heading { visible: page.tab === "weather"; title: "Данные" }
            Group {
                visible: page.tab === "weather"
                SettingRow {
                    label: "Город"
                    StyledTextField {
                        width: 180
                        placeholderText: "авто"
                        text: page.opts.city || ""
                        onEditingFinished: if (text.trim() !== (page.opts.city || "")) page.setOpt("city", text.trim())
                    }
                    StyledButton { visible: !!page.opts.city; text: "Авто"; onClicked: page.setOpt("city", "") }
                }
                SettingRow {
                    label: "Температура"
                    Segmented { model: ["°C", "°F"]; current: page.opts.units === "f" ? 1 : 0; onActivated: index => page.setOpt("units", index ? "f" : "c") }
                }
                SettingRow {
                    label: "Ветер"
                    Segmented { model: ["м/с", "км/ч"]; current: page.opts.wind === "kmh" ? 1 : 0; onActivated: index => page.setOpt("wind", index ? "kmh" : "ms") }
                }
                SettingRow {
                    label: "Обновлять"
                    Segmented {
                        readonly property var values: [10, 20, 30, 60]
                        model: ["10 мин", "20 мин", "30 мин", "час"]
                        current: Math.max(0, values.indexOf(page.opts.refresh || 20))
                        onActivated: index => page.setOpt("refresh", values[index])
                    }
                    StyledButton { text: "Сейчас"; enabled: page.running; onClicked: page.ipc(["refresh"]) }
                }
                SettingRow {
                    label: "Живое небо"
                    StyledCheckBox { checked: page.opts.live !== false; onClicked: page.setOpt("live", checked) }
                }
            }

            Heading { visible: page.tab === "weather"; title: "Примерить небо" }
            Flow {
                visible: page.tab === "weather"
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: [["", "Настоящее"], ["clear", "Ясно"], ["partly", "Облачно"], ["cloudy", "Пасмурно"], ["fog", "Туман"],
                            ["drizzle", "Морось"], ["rain", "Дождь"], ["snow", "Снег"], ["storm", "Гроза"]]
                    StyledButton {
                        required property var modelData
                        text: modelData[1]
                        highlighted: (page.opts.demo || "") === modelData[0]
                        primary: (page.opts.demo || "") === modelData[0]
                        onClicked: page.setOpt("demo", modelData[0])
                    }
                }
            }

            // Память
            Heading { visible: page.tab === "memory"; title: "Вид" }
            GridLayout {
                visible: page.tab === "memory"
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 12; rowSpacing: 12
                Repeater {
                    model: [
                        { id: "card", name: "Карточка" },
                        { id: "ring", name: "Кольцо" },
                        { id: "pill", name: "Капсула" }
                    ]
                    Item {
                        id: ml
                        required property var modelData
                        readonly property bool current: (page.live && page.live.look ? page.live.look : (page.opts.look || "card")) === modelData.id
                        Layout.fillWidth: true; Layout.preferredWidth: 1
                        implicitHeight: 154
                        Rectangle {
                            anchors.fill: parent; radius: Tokens.radius
                            color: mlMouse.containsMouse ? Tokens.cardStrong : Tokens.card
                            border.width: ml.current ? 2 : 1; border.color: ml.current ? Tokens.neon : Tokens.line
                        }
                        ClippingRectangle {
                            x: 10; y: 10; width: parent.width - 20; height: 104
                            radius: Math.max(0, Tokens.radius - 4)
                            color: "#1a1622"
                            Image { anchors.fill: parent; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; sourceSize.width: 400; opacity: .3; asynchronous: true }
                            Rectangle {   // card
                                visible: ml.modelData.id === "card"
                                anchors.centerIn: parent; width: 124; height: 84; radius: 12; color: "#d0141019"; border.width: 1; border.color: "#33ffffff"
                                Canvas { x: 8; y: 10; width: 40; height: 40; onPaint: { var c = getContext("2d"); c.lineWidth = 5; c.lineCap = "round"; c.strokeStyle = "#20ffffff"; c.beginPath(); c.arc(20, 20, 16, 0, 7); c.stroke(); c.strokeStyle = "#8fe3a8"; c.beginPath(); c.arc(20, 20, 16, -1.57, -1.57 + 2.2); c.stroke(); } }
                                Text { x: 56; y: 10; text: "4,5 ГБ"; color: "#ffffff"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Canvas { x: 56; y: 32; width: 60; height: 16; onPaint: { var c = getContext("2d"); c.strokeStyle = "#8fe3a8"; c.lineWidth = 1.5; c.beginPath(); c.moveTo(0, 12); c.lineTo(15, 10); c.lineTo(28, 13); c.lineTo(40, 6); c.lineTo(60, 8); c.stroke(); } }
                                Repeater { model: 3; Rectangle { required property int index; x: 8; y: 58 + index * 8; width: 108; height: 3; radius: 1.5; color: "#18ffffff"
                                    Rectangle { width: [80, 40, 26][parent.index]; height: 3; radius: 1.5; color: "#8fe3a8"; opacity: parent.index ? .55 : 1 } } }
                            }
                            Item {   // ring
                                visible: ml.modelData.id === "ring"
                                anchors.centerIn: parent; width: 84; height: 84
                                Rectangle { anchors.fill: parent; radius: 42; color: "#d0141019"; border.width: 1; border.color: "#33ffffff" }
                                Canvas { anchors.fill: parent; onPaint: { var c = getContext("2d"); c.lineWidth = 7; c.lineCap = "round"; c.strokeStyle = "#20ffffff"; c.beginPath(); c.arc(42, 42, 34, 0, 7); c.stroke(); c.strokeStyle = "#607fb4ff"; c.beginPath(); c.arc(42, 42, 34, -1.57 + 2.6, -1.57 + 3.6); c.stroke(); c.strokeStyle = "#ffd36b"; c.beginPath(); c.arc(42, 42, 34, -1.57, -1.57 + 2.6); c.stroke(); } }
                                Text { anchors.centerIn: parent; text: "41%"; color: "#ffffff"; font.pixelSize: 20; font.weight: Font.Light }
                            }
                            Rectangle {   // pill
                                visible: ml.modelData.id === "pill"
                                anchors.centerIn: parent; width: 140; height: 26; radius: 13; color: "#d0141019"; border.width: 1; border.color: "#33ffffff"
                                Rectangle { x: 12; y: 10; width: 62; height: 6; radius: 3; color: "#20ffffff"
                                    Rectangle { width: 34; height: 6; radius: 3; color: "#607fb4ff" }
                                    Rectangle { width: 20; height: 6; radius: 3; color: "#8fe3a8" } }
                                Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "4,5 / 31"; color: "#ffffff"; font.pixelSize: 10; font.weight: Font.DemiBold }
                            }
                        }
                        Column {
                            x: 14; y: 122; width: parent.width - 28; spacing: 2
                            RowLayout {
                                width: parent.width
                                Text { Layout.fillWidth: true; text: ml.modelData.name; font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.Bold; color: Tokens.text }
                                Text { visible: ml.current; text: "✓"; font.pixelSize: 14; font.weight: Font.Bold; color: Tokens.neon }
                            }
                        }
                        MouseArea { id: mlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.setOpt("look", ml.modelData.id) }
                    }
                }
            }

            Heading { visible: page.tab === "memory"; title: "Данные" }
            Group {
                visible: page.tab === "memory"
                SettingRow {
                    label: "Обновлять"
                    Segmented {
                        readonly property var values: [1, 2, 5]
                        model: ["1 с", "2 с", "5 с"]
                        current: Math.max(0, values.indexOf(page.opts.interval || 2))
                        onActivated: index => page.setOpt("interval", values[index])
                    }
                }
                SettingRow {
                    label: "Топ процессов"
                    StyledCheckBox { checked: page.opts.procs !== false; onClicked: page.setOpt("procs", checked) }
                }
                SettingRow {
                    label: "Плотность стекла, " + Math.round((page.opts.opacity === undefined ? .82 : page.opts.opacity) * 100) + "%"
                    StyledSlider { width: 200; from: 30; to: 100; stepSize: 5; value: (page.opts.opacity === undefined ? .82 : page.opts.opacity) * 100; onMoved: page.setOpt("opacity", Math.round(value / 5) * 5 / 100) }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Heading { title: "Место" }
                Item { Layout.fillWidth: true }
                StyledButton { visible: !page.running; text: "Запустить"; primary: true; onClicked: { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/" + page.target.bin]); refresh.restart(); } }
                StyledButton { visible: page.running && page.tab === "music" && (page.opts.style || "classic") === "classic"; text: page.live && page.live.karaoke ? "Свернуть текст" : "Текст песни"; onClicked: page.ipc(["karaoke"]) }
                StyledButton {
                    visible: page.running; text: "Перезапустить"
                    onClicked: Quickshell.execDetached(["sh", "-c", "qs kill -c " + page.target.qs + "; sleep .3; ~/.local/bin/" + page.target.bin])
                }
            }

            // mini desktop
            ClippingRectangle {
                id: desk
                Layout.fillWidth: true
                Layout.preferredHeight: width * page.screenH / page.screenW
                radius: Tokens.radius
                color: Tokens.well
                border.width: 1; border.color: Tokens.line
                readonly property real k: width / page.screenW
                Image {
                    anchors.fill: parent
                    source: page.wallpaper
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 960
                }
                Rectangle {   // the bar area the widget can't enter
                    width: parent.width; height: page.deskTop * desk.k
                    color: "#55000000"
                    Rectangle { x: 10 * desk.k; y: 10 * desk.k; width: parent.width - 20 * desk.k; height: 30 * desk.k; radius: height / 2; color: "#40ffffff" }
                }
                Text {
                    visible: !page.running
                    anchors.centerIn: parent
                    text: page.target.qs + " не запущен"
                    font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: "#ffffff"
                    style: Text.Outline; styleColor: "#80000000"
                }
                Item {
                    id: ghost
                    visible: page.running
                    width: page.live ? page.live.width * desk.k : 0
                    height: page.live ? page.live.height * desk.k : 0
                    function sync() { if (page.live && !page.dragging) { x = page.live.x * desk.k; y = (page.live.y + page.deskTop) * desk.k; } }
                    Connections { target: page; function onLiveChanged() { ghost.sync(); } }
                    Connections { target: desk; function onWidthChanged() { ghost.sync(); } }
                    opacity: page.live && !page.live.shown ? .4 : 1
                    // a faithful miniature of the real widget: same gradient, rim and art tile
                    Rectangle {
                        anchors.fill: parent
                        radius: { var l = page.live ? page.live.look : "classic", w = width, h = height;
                            return l === "pill" ? h / 2 : l === "round" || l === "ring" ? w / 2 : l === "square" ? 28 * (page.live ? page.live.scale : 1) * desk.k : 26 * (page.live ? page.live.scale : 1) * desk.k; }
                        gradient: Gradient {
                            GradientStop { position: 0; color: page.tab === "memory" ? "#e0141019" : page.tab === "weather" ? "#2f6fd1" : "#555c506e" }
                            GradientStop { position: .45; color: page.tab === "memory" ? "#d0141019" : page.tab === "weather" ? "#4a7cc0" : "#402a2438" }
                            GradientStop { position: 1; color: page.tab === "memory" ? "#c03a5a44" : page.tab === "weather" ? "#8cc0f2" : "#70201c2a" }
                        }
                        border.width: drag.drag.active || drag.containsMouse ? 2 : 1
                        border.color: drag.drag.active || drag.containsMouse ? Tokens.neon : "#60e4d4f6"
                        Rectangle {
                            x: parent.height * .125; y: x; width: parent.height * .65; height: width
                            radius: width * .15; color: "#35b9a3d3"
                            Text { anchors.centerIn: parent; text: page.tab === "memory" ? String.fromCodePoint(0xF035B) : "♫"; font.family: page.tab === "memory" ? "JetBrainsMono Nerd Font" : Tokens.font; color: page.tab === "memory" ? "#8fe3a8" : "#e8ddf5"; font.pixelSize: Math.max(8, parent.height * .4) }
                        }
                        Text {
                            x: parent.height * .9; y: parent.height * .15
                            width: parent.width - x - 8; elide: Text.ElideRight
                            text: page.tab === "memory" ? (page.live ? page.live.percent + "%" : "") : page.tab === "weather" ? (page.live && page.live.temp !== null ? Math.round(page.live.temp) + "°" : "") : page.live && page.live.player ? page.live.player : "RiceMusic"
                            color: "#faf6ff"; font.family: Tokens.font; font.pixelSize: Math.max(8, parent.height * .14); font.weight: Font.DemiBold
                        }
                    }
                    Rectangle {
                        visible: drag.drag.active
                        anchors.bottom: parent.top; anchors.bottomMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                        width: coords.implicitWidth + 10; height: 18; radius: 4; color: "#d0000000"
                        Text { id: coords; anchors.centerIn: parent; color: "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 10
                            text: Math.round(ghost.x / desk.k) + ", " + Math.round(ghost.y / desk.k - page.deskTop) }
                    }
                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: ghost
                        drag.minimumX: 0; drag.maximumX: desk.width - ghost.width
                        drag.minimumY: page.deskTop * desk.k; drag.maximumY: desk.height - ghost.height
                        onPressed: page.dragging = true
                        onReleased: {
                            page.dragging = false;
                            page.ipc(["place", String(Math.round(ghost.x / desk.k)), String(Math.round(ghost.y / desk.k - page.deskTop))]);
                        }
                        onCanceled: page.dragging = false
                    }
                }
            }

            // corner presets
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: "Быстро:"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
                Repeater {
                    model: [["tl", "↖"], ["tc", "↑"], ["tr", "↗"], ["cc", "•"], ["bl", "↙"], ["bc", "↓"], ["br", "↘"]]
                    StyledButton {
                        required property var modelData
                        implicitWidth: 38
                        text: modelData[1]
                        enabled: page.running
                        onClicked: page.preset(modelData[0])
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Heading { title: "Поведение" }
            Group {
                SettingRow {
                    label: "Показывать на рабочем столе"
                    StyledCheckBox {
                        checked: page.opts.visible !== false
                        onClicked: { page.setOpt("visible", checked); page.ipc([checked ? "show" : "hide"]); }
                    }
                }
                SettingRow {
                    label: "Поверх окон"
                    StyledCheckBox { checked: !!page.opts.onTop; onClicked: page.setOpt("onTop", checked) }
                }
                SettingRow {
                    visible: page.tab === "music"
                    label: "Сразу открывать текст песни"
                    StyledCheckBox { checked: !!page.opts.lyricsOnStart; onClicked: page.setOpt("lyricsOnStart", checked) }
                }
                SettingRow {
                    label: "Запускать вместе с системой"
                    StyledCheckBox { checked: page.autostart; onClicked: page.setAutostart(checked) }
                }
            }

            Heading { visible: page.tab === "music"; title: "Плеер" }
            Group {
                visible: page.tab === "music"
                SettingRow {
                    label: "Предпочитать"
                    StyledComboBox {
                        id: playerBox
                        width: 200
                        readonly property var choices: {
                            var seen = ["Авто"];
                            (page.live ? page.live.players : []).concat(page.opts.player ? [page.opts.player] : [])
                                .forEach(p => { if (p && seen.indexOf(p) < 0) seen.push(p); });
                            return seen;
                        }
                        model: choices
                        currentIndex: page.opts.player ? Math.max(0, choices.indexOf(page.opts.player)) : 0
                        onActivated: page.setOpt("player", currentIndex === 0 ? "" : choices[currentIndex])
                    }
                }
            }

        }
    }
}
