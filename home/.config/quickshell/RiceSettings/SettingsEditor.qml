pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Effects
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Generic page driven by a python backend that returns {settings, fields, presets}.
ColumnLayout {
    id: page
    required property string backendName
    property string kind: "apps"
    property var backendArgs: []
    property string filter: ""
    property string wallpaper: ""
    readonly property bool busy: worker.running
    readonly property bool valid: fields.every(function(f) { var v=settings[f.key]; return f.kind!=="color" || /^#[0-9a-fA-F]{6}$/.test(v || ""); })
    property var settings: ({})
    property var fields: []
    property var presets: []
    property bool loaded: false
    property bool dirty: false
    property bool canRestore: false
    property string status: "Загрузка…"
    property string error: ""
    readonly property var groups: {
        var seen = [];
        fields.forEach(f => { var g = groupOf(f); if (seen.indexOf(g) < 0) seen.push(g); });
        return seen;
    }
    spacing: 14

    function groupOf(f) { return f.group || ({color:"Цвета", bool:"Поведение"})[f.kind] || "Основное"; }
    function set(key,value) { if(worker.running || settings[key]===value)return;var next=Object.assign({},settings);next[key]=value;settings=next;error="";touched(); }

    // live (desktop look + kitty): changes reach the screen ~0.3 s later. The first write of a
    //    session keeps a backup ("apply"), the rest skip it ("preview"); "Откатить" undoes the session.
    readonly property bool liveCapable: kind === "desktop" || kind === "kitty"
    readonly property bool live: liveCapable && Tokens.opt.liveApply !== false
    property bool liveBackedUp: false
    property bool livePending: false
    function touched() { if (live && loaded && valid) { dirty=false; liveTimer.restart(); } else dirty=true; }
    Timer { id: liveTimer; interval: 300; onTriggered: page.pushLive() }
    function pushLive() {
        if (previewer.running) { livePending=true; return; }
        previewer.command=["python3",Quickshell.env("HOME")+"/.local/share/rice-settings/"+backendName].concat(backendArgs).concat([liveBackedUp ? "preview" : "apply"]);
        liveBackedUp=true; previewer.running=true;
    }
    onLiveChanged: if (live && dirty && valid) { dirty=false; pushLive(); }
    Process {
        id: previewer
        stdinEnabled: true
        onStarted: { write(JSON.stringify(page.settings)); stdinEnabled=false; }
        onExited: { stdinEnabled=true; if (page.livePending) { page.livePending=false; page.pushLive(); } }
        stdout: StdioCollector { onStreamFinished: {
            try { var r=JSON.parse(text); if (r.error) { page.error=r.error; return; } page.canRestore=true; page.status=""; }
            catch(e) { page.error="Ошибка: "+e; }
        } }
    }
    function read() { run("read"); }
    function hex(value, fallback) { return /^#[0-9a-fA-F]{6}$/.test(value || "") ? value : fallback; }
    function html(value) { return String(value || "").replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); }
    function promptPreview() {
        var s=settings, accent=hex(s.accent,"#c6acee"), directory=hex(s.directory,"#a8c9f5"), success=hex(s.success,"#b4d3ad");
        var line='<font color="'+accent+'">'+html(s.prefix)+'</font> ';
        if(s.showTime)line+='12:30 ';
        if(s.showUser)line+=html(Quickshell.env("USER"));if(s.showHost)line+=(s.showUser ? '@' : '')+'arch';
        line+=' <font color="'+directory+'">~/projects</font>';
        if(s.showGit)line+=' <font color="'+accent+'">git:main</font>';
        if(s.style!=="minimal")line+='<br><font color="'+accent+'">'+html(s.bottomPrefix)+'</font>';
        line+=' <font color="'+success+'">'+html(s.symbol)+'</font> ls';
        return s.bold ? '<b>'+line+'</b>' : line;
    }
    function run(action) { if(worker.running)return;error="";worker.command=["python3",Quickshell.env("HOME")+"/.local/share/rice-settings/"+backendName].concat(backendArgs).concat([action]);worker.running=true; }
    function matches(f) { return !filter || f.label.toLocaleLowerCase().includes(filter) || groupOf(f).toLocaleLowerCase().includes(filter); }
    Component.onCompleted: run("read")
    Process {
        id: worker
        stdinEnabled: true
        onStarted: { if(command[command.length-1]==="apply")write(JSON.stringify(page.settings));stdinEnabled=false; }
        onExited: (exitCode, exitStatus) => { stdinEnabled=true; }
        stderr: StdioCollector { onStreamFinished: { if(text.trim())console.warn(page.backendName+": "+text); } }
        stdout: StdioCollector { onStreamFinished: {
            try {var d=JSON.parse(text);if(d.error){page.error=d.error;return;}page.settings=d.settings;if(d.fields)page.fields=d.fields;if(d.presets)page.presets=d.presets;page.loaded=true;page.dirty=false;page.liveBackedUp=false;page.canRestore=d.canRestore;page.status=d.message || "Все изменения сохранены";}catch(e){page.error="Ошибка: "+e;}
        } }
    }

    // Preview
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: page.kind === "lock" ? 250 : 168
        radius: Tokens.radius; color: Tokens.well; clip: true
        border.width: 1; border.color: Tokens.alpha(Tokens.text, .05)

        // desktop: wallpaper + two windows reflecting gaps, borders, rounding, dim
        ClippingRectangle {
            visible: page.kind === "desktop"
            anchors.fill: parent; anchors.margins: 1; radius: Tokens.radius - 1
            color: "#171421"
            Image { anchors.fill: parent; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: .9 }
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: page.settings.dimInactive ? .08 : 0 }
            Row {
                id: desk
                readonly property real g: (page.settings.gapsIn || 0) * .5
                anchors.fill: parent
                anchors.margins: 8 + (page.settings.gapsOut || 0) * .45
                anchors.topMargin: 22 + (page.settings.gapsOut || 0) * .45
                spacing: 2 + g * 2
                Repeater {
                    model: 2
                    Item {
                        id: win
                        required property int index
                        readonly property bool focused: index === 0
                        width: index === 0 ? (desk.width - desk.spacing) * .58 : (desk.width - desk.spacing) * .42
                        height: desk.height
                        opacity: focused ? 1 : (page.settings.inactiveOpacity || 100) / 100
                        Rectangle {
                            anchors.fill: parent
                            radius: (page.settings.rounding || 0) * .6
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: win.focused ? page.hex(page.settings.activeBorder, "#c6acee") : page.hex(page.settings.inactiveBorder, "#493957") }
                                GradientStop { position: 1; color: win.focused ? page.hex(page.settings.activeBorder2, "#a8c9f5") : page.hex(page.settings.inactiveBorder, "#493957") }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent; anchors.margins: Math.min(3, page.settings.borderSize || 0)
                            radius: Math.max(0, (page.settings.rounding || 0) * .6 - anchors.margins)
                            color: Tokens.base
                            Column {
                                x: 10; y: 10; spacing: 6
                                Repeater {
                                    model: win.focused ? [.7, .45, .55, .3] : [.5, .35]
                                    Rectangle { required property real modelData; width: (win.width - 24) * modelData; height: 4; radius: 2; color: Tokens.alpha(Tokens.text, .18) }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                x: 8 + (page.settings.gapsOut || 0) * .45; y: 6
                width: parent.width - x * 2; height: 10; radius: 5; color: Tokens.alpha(Tokens.base, .8)
            }
        }

        // lock: the real layout of the chosen style on a 16:9 screen
        ClippingRectangle {
            id: lockBox
            visible: page.kind === "lock"
            readonly property bool classic: page.settings.style === "Чёрная дыра"
            readonly property var st: page.settings
            function opt(key, fallback) { return st[key] === undefined ? fallback : st[key]; }
            anchors.fill: parent; anchors.margins: 1; radius: Tokens.radius - 1
            color: "#0c0b12"
            Image {
                visible: lockBox.classic
                anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true
                source: "file://" + Quickshell.env("HOME") + "/.config/hypr/lock-assets/black-hole-fallback.png"
                opacity: page.settings.video === false ? .35 : Math.max(.25, page.settings.videoOpacity === undefined ? 1 : page.settings.videoOpacity)
            }
            Column {
                visible: lockBox.classic
                anchors.centerIn: parent; spacing: 6
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: page.settings.clock24 === false ? "2:30" : "14:30"; font.family: Tokens.font; font.weight: Font.Light; font.pixelSize: (page.settings.clockSize || 138) * .3; color: "#eee3fa" }
                Text { visible: !!page.settings.showDate; anchors.horizontalCenter: parent.horizontalCenter; text: Qt.locale("ru_RU").toString(new Date(), "dddd  /  d MMMM"); font.family: Tokens.font; font.pixelSize: 9; color: "#bda9d1" }
                Text { visible: !!page.settings.showUser; anchors.horizontalCenter: parent.horizontalCenter; text: Quickshell.env("USER"); font.family: Tokens.font; font.pixelSize: 10; color: "#eee3fa" }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: (page.settings.inputWidth || 320) * .42; height: 20; radius: Math.min(10, (page.settings.rounding || 0) * .5)
                    color: "#d935283f"; border.width: 1; border.color: "#66d8c0f2"
                    Text { anchors.centerIn: parent; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: page.settings.placeholder || "Введите пароль"; font.family: Tokens.font; font.pixelSize: 8; color: "#bda9d1" }
                }
            }
            FileView { id: lockWallFile; path: Quickshell.env("HOME") + "/.local/state/wallpaper-picker/current"; preload: true; watchChanges: true; printErrors: false; onFileChanged: reload() }
            ClippingRectangle {
                id: lockCover
                visible: !lockBox.classic
                anchors.centerIn: parent
                height: parent.height - 16; width: height * 16 / 9
                radius: 8; color: "#000000"
                readonly property string wallpaper: { var w = lockWallFile.text().trim(); return w ? "file://" + w : ""; }
                Item {
                    id: lockWall
                    anchors.fill: parent; visible: false
                    Image { anchors.fill: parent; source: lockCover.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 640 }
                }
                MultiEffect {
                    anchors.fill: parent; source: lockWall
                    blurEnabled: true; blurMax: 16; blur: lockBox.opt("blur", 55) / 100
                    saturation: .15; scale: 1.04
                }
                Rectangle { anchors.fill: parent; color: "#000000"; opacity: lockBox.opt("dim", 25) / 100 }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#59000000" }
                        GradientStop { position: .35; color: "#00000000" }
                        GradientStop { position: .7; color: "#00000000" }
                        GradientStop { position: 1; color: "#80000000" }
                    }
                }
                Item {
                    width: 1920; height: 1080
                    scale: lockCover.height / 1080; transformOrigin: Item.TopLeft
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 110; spacing: -6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !!lockBox.opt("showDate", true)
                            text: { var d = new Date().toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM"); return d.charAt(0).toUpperCase() + d.slice(1); }
                            font.family: Rice.Theme.fontFamily; font.pixelSize: 26 * Rice.Theme.textScale; font.weight: Font.DemiBold
                            color: "#e6ffffff"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: lockBox.opt("clock24", true) ? "14:30" : "2:30"
                            font.family: Rice.Theme.fontFamily; font.pixelSize: lockBox.opt("clockSize", 138) * 1.25 * Rice.Theme.textScale; font.weight: Font.Bold
                            font.letterSpacing: -4
                            color: "#f2ffffff"
                        }
                    }
                    Row {
                        visible: !!lockBox.opt("showWidgets", true)
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 400; spacing: 12
                        Repeater {
                            model: [[0xF0079, "100%"], [0xF030C, "EN"]]
                            Rectangle {
                                id: lockPill
                                required property var modelData
                                width: lockPillRow.implicitWidth + 28; height: 38; radius: 19
                                color: "#33ffffff"; border.width: 1; border.color: "#26ffffff"
                                Row {
                                    id: lockPillRow
                                    anchors.centerIn: parent; spacing: 8
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: Tokens.glyph(lockPill.modelData[0]); font.family: Tokens.iconFont; font.pixelSize: 18; color: "#ffffff" }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: lockPill.modelData[1]; font.family: Rice.Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: "#ffffff" }
                                }
                            }
                        }
                    }
                    Rectangle {   // now playing
                        visible: !!lockBox.opt("showMedia", true)
                        x: 48; y: 1080 - 48 - height
                        width: 460; height: 120; radius: 28
                        color: "#2effffff"; border.width: 1; border.color: "#26ffffff"
                        Rectangle { x: 16; y: 16; width: 88; height: 88; radius: 18; color: "#40ffffff" }
                        Rectangle { x: 122; y: 40; width: 150; height: 14; radius: 7; color: "#ffffff" }
                        Rectangle { x: 122; y: 66; width: 96; height: 12; radius: 6; color: "#a0ffffff" }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                            spacing: 16
                            Repeater {
                                model: [0xF04AE, 0xF03E4, 0xF04AD]
                                Text {
                                    required property int modelData
                                    required property int index
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Tokens.glyph(modelData); font.family: Tokens.iconFont; font.pixelSize: index === 1 ? 30 : 22; color: "#d8ffffff"
                                }
                            }
                        }
                    }
                    Column {   // avatar, name, password
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 780; spacing: 14
                        ClippingRectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 84; height: 84; radius: 42
                            color: Rice.Theme.palette.colors ? Rice.Theme.palette.colors.accent : "#c6acee"
                            border.width: 2; border.color: "#59ffffff"
                            Image { anchors.fill: parent; anchors.margins: 2; source: Qt.resolvedUrl("assets/banner.png"); fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 168 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !!lockBox.opt("showUser", true)
                            text: Quickshell.env("USER")
                            font.family: Rice.Theme.fontFamily; font.pixelSize: 20 * Rice.Theme.textScale; font.weight: Font.DemiBold
                            color: "#ffffff"
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: lockBox.opt("inputWidth", 320); height: 46
                            radius: Math.min(height / 2, lockBox.opt("rounding", 19) + 4)
                            color: "#40ffffff"; border.width: 1; border.color: "#80ffffff"
                            Text {
                                x: 20; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 68; elide: Text.ElideRight
                                text: lockBox.opt("placeholder", "Введите пароль")
                                font.family: Rice.Theme.fontFamily; font.pixelSize: 15 * Rice.Theme.textScale; color: "#b3ffffff"
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32; radius: 16; color: "#26ffffff"
                                Text { anchors.centerIn: parent; text: Tokens.glyph(0xF0054); font.family: Tokens.iconFont; font.pixelSize: 18; color: "#b3ffffff" }
                            }
                        }
                    }
                    Row {   // power
                        visible: !!lockBox.opt("powerButtons", true)
                        anchors.right: parent.right; anchors.rightMargin: 48
                        y: 1080 - 48 - 74; spacing: 22
                        Repeater {
                            model: [[0xF04B2, "Сон"], [0xF0709, "Перезагрузка"], [0xF0425, "Выключение"]]
                            Column {
                                id: lockPower
                                required property var modelData
                                spacing: 6
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 48; height: 48; radius: 24
                                    color: "#33ffffff"; border.width: 1; border.color: "#26ffffff"
                                    Text { anchors.centerIn: parent; text: Tokens.glyph(lockPower.modelData[0]); font.family: Tokens.iconFont; font.pixelSize: 22; color: "#ffffff" }
                                }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: lockPower.modelData[1]; font.family: Rice.Theme.fontFamily; font.pixelSize: 12; color: "#b0ffffff" }
                            }
                        }
                    }
                }
            }
        }

        // apps: launcher footprint on a 16:9 screen
        Item {
            visible: page.kind === "apps"
            anchors.fill: parent; anchors.margins: 14
            Rectangle {
                id: screenBox
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height; width: height * 16 / 9
                radius: 8; color: "#171421"; border.width: 1; border.color: Tokens.line
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 8, (page.settings.width || 600) / 1920 * parent.width)
                    height: Math.min(parent.height - 8, (page.settings.height || 454) / 1080 * parent.height)
                    radius: 6; color: Tokens.cardStrong; border.width: 1; border.color: Tokens.alpha(Tokens.accent, .5)
                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 4
                        Rectangle { visible: !!page.settings.showSearch; width: parent.width; height: 6; radius: 3; color: Tokens.alpha(Tokens.text, .25) }
                        Row { visible: !!page.settings.showCategories; spacing: 3; Repeater { model: 4; Rectangle { width: 12; height: 3; radius: 1.5; color: Tokens.alpha(Tokens.text2, .5) } } }
                        Grid {
                            id: appGrid
                            readonly property int cols: page.settings.columns || 6
                            width: parent.width; columns: cols; spacing: 3
                            Repeater {
                                model: appGrid.cols * (page.settings.rows || 3)
                                Rectangle { width: Math.max(2, (appGrid.width - 3 * (appGrid.cols - 1)) / appGrid.cols); height: width * .8; radius: 2; color: Tokens.alpha(Tokens.accent, .55) }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.left: screenBox.right; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: (page.settings.width || 600) + " × " + (page.settings.height || 454); font.family: Tokens.font; font.pixelSize: Tokens.px(20); font.weight: Font.Medium; color: Tokens.text }
                Text { text: "сетка " + (page.settings.columns || 6) + " × " + (page.settings.rows || 3) + " · иконки " + (page.settings.iconSize || 35) + " px"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
            }
        }

        // kitty: a real-looking terminal with the draft colours
        Rectangle {
            visible: page.kind === "kitty"
            anchors.fill: parent; anchors.margins: 14
            radius: 8; color: page.hex(page.settings.background, "#252236")
            opacity: Math.max(.55, page.settings.background_opacity === undefined ? 1 : page.settings.background_opacity)
            Text {
                anchors.fill: parent; anchors.margins: 6 + Math.min(18, (page.settings.window_padding_width || 0) * .6)
                textFormat: Text.RichText; clip: true
                font.family: page.settings.font_family || "monospace"; font.pixelSize: Math.min(18, page.settings.font_size || 12)
                color: page.hex(page.settings.foreground, "#eeeaf6")
                text: "<span style='color:" + page.hex(page.settings.cursor, "#c6acee") + "'>❯</span> ls<br>README.md&nbsp;&nbsp;src/&nbsp;&nbsp;<span style='background:" + page.hex(page.settings.selection_background, "#675181") + ";color:" + page.hex(page.settings.selection_foreground, "#fbf8ff") + "'>notes.txt</span><br><span style='color:" + page.hex(page.settings.cursor, "#c6acee") + "'>❯</span> <span style='background:" + page.hex(page.settings.cursor, "#c6acee") + "'>&nbsp;</span>"
            }
        }

        // prompt: draft zsh prompt
        Rectangle {
            visible: page.kind === "prompt"
            anchors.fill: parent; anchors.margins: 14; radius: 8; color: "#252236"
            Text { anchors.fill: parent; anchors.margins: 14; text: page.promptPreview(); textFormat: Text.RichText; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#eeeaf6"; wrapMode: Text.Wrap; clip: true }
        }

        // system: keyboard layouts + night light tint
        Item {
            visible: page.kind === "system"
            anchors.fill: parent; anchors.margins: 16
            Rectangle {
                id: tint
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: 220; height: parent.height; radius: 8
                readonly property real warm: page.settings.nightMode && page.settings.nightMode !== "Выключен" ? Math.max(0, Math.min(1, (6500 - (page.settings.nightTemp || 4500)) / 4000)) : 0
                color: "#171421"
                Image { anchors.fill: parent; anchors.margins: 1; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                Rectangle { anchors.fill: parent; radius: 8; color: "#ff9a3c"; opacity: tint.warm * .38 }
                Text {
                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 8
                    text: tint.warm > 0 ? (page.settings.nightTemp || 4500) + " K" : "6500 K"
                    font.family: Tokens.font; font.pixelSize: 11; color: "#ffffff"; style: Text.Outline; styleColor: "#40000000"
                }
            }
            Column {
                anchors.left: tint.right; anchors.leftMargin: 22; anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Row {
                    spacing: 6
                    Repeater {
                        model: String(page.settings.layouts || "us").split(",").filter(s => s.trim())
                        Rectangle {
                            required property string modelData
                            width: lay.implicitWidth + 16; height: 26; radius: 6; color: Tokens.cardStrong
                            Text { id: lay; anchors.centerIn: parent; text: modelData.trim().toUpperCase(); font.family: Tokens.font; font.pixelSize: 12; font.weight: Font.Medium; color: Tokens.text }
                        }
                    }
                }
                Text { text: "Переключение: " + (page.settings.layoutSwitch || "Alt + Shift"); font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
                Text { text: page.settings.gestures ? "Свайп тремя пальцами переключает рабочие столы" : "Жесты тачпада выключены"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
            }
        }
    }

    // Presets + search
    RowLayout {
        Layout.fillWidth: true
        visible: page.presets.length > 0 || page.fields.length > 10
        spacing: 6
        Text { visible: page.presets.length > 0; text: "Наборы"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text3; Layout.rightMargin: 4 }
        Repeater {
            model: page.presets
            StyledButton { required property var modelData; text: modelData.name; enabled: !page.busy; onClicked: { page.settings = Object.assign({}, page.settings, modelData.settings); page.touched(); } }
        }
        Item { Layout.fillWidth: true }
        StyledTextField {
            visible: page.fields.length > 10
            Layout.preferredWidth: 200
            placeholderText: "Найти параметр"
            onTextChanged: page.filter = text.trim().toLocaleLowerCase()
        }
    }

    // Fields
    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentHeight: body.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        ColumnLayout {
            id: body
            width: parent.width - 12
            spacing: 18
            Repeater {
                model: page.groups
                Group {
                    id: group
                    required property string modelData
                    title: modelData
                    visible: page.fields.some(f => page.groupOf(f) === group.modelData && page.matches(f))
                    Repeater {
                        model: page.fields.filter(f => page.groupOf(f) === group.modelData)
                        SettingRow {
                            id: row
                            required property var modelData
                            readonly property var value: page.settings[modelData.key]
                            label: modelData.label
                            visible: page.matches(modelData)
                            enabled: page.loaded && !worker.running

                            StyledSpinBox {
                                visible: row.modelData.kind === "number" && !row.modelData.slider
                                from: row.modelData.min || 0; to: row.modelData.max || 100; stepSize: row.modelData.step || 1; editable: true
                                value: Math.round((row.value || 0) * (row.modelData.factor || 1))
                                textFromValue: function(value, locale) { return row.modelData.key === "font_size" ? (value / 10).toFixed(1) : String(value); }
                                valueFromText: function(text, locale) { return Math.round(Number(text.replace(",", ".")) * (row.modelData.key === "font_size" ? 10 : 1)); }
                                onValueModified: page.set(row.modelData.key, value / (row.modelData.factor || 1))
                            }
                            ValueSlider {
                                visible: row.modelData.kind === "number" && !!row.modelData.slider
                                from: row.modelData.min || 0; to: row.modelData.max || 100; step: row.modelData.step || 1
                                unit: row.modelData.unit || ""
                                defaultValue: row.modelData.default === undefined ? NaN : row.modelData.default * (row.modelData.factor || 1)
                                value: Math.round((row.value || 0) * (row.modelData.factor || 1))
                                onEdited: v => page.set(row.modelData.key, v / (row.modelData.factor || 1))
                            }
                            StyledCheckBox { visible: row.modelData.kind === "bool"; checked: !!row.value; onToggled: page.set(row.modelData.key, checked) }
                            StyledComboBox {
                                visible: row.modelData.kind === "choice" || row.modelData.kind === "font"
                                width: 240
                                model: row.modelData.kind === "font" ? Array.from(new Set([String(row.value || "Noto Sans")].concat(Qt.fontFamilies().sort()))) : (row.modelData.values || [])
                                currentIndex: Math.max(0, model.indexOf(String(row.value || "")))
                                onActivated: page.set(row.modelData.key, currentText)
                            }
                            StyledTextField {
                                visible: row.modelData.kind === "text"
                                width: 220
                                maximumLength: row.modelData.maxLength || 32
                                text: String(row.value || "")
                                placeholderText: row.modelData.placeholder || ""
                                onTextEdited: page.set(row.modelData.key, text)
                            }
                            // colour: chip opens the inline picker
                            ColorField {
                                visible: row.modelData.kind === "color"
                                title: row.modelData.label
                                value: String(row.value || "")
                                onEdited: h => page.set(row.modelData.key, h)
                            }
                        }
                    }
                }
            }
            Text {
                visible: page.loaded && page.filter.length > 0 && !page.fields.some(f => page.matches(f))
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; Layout.topMargin: 30
                text: "Ничего не найдено"; font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: Tokens.text3
            }
            Item { Layout.preferredHeight: 4 }
        }
    }

    ApplyBar {
        dirty: page.dirty; busy: worker.running; loaded: page.loaded; valid: page.valid; canRestore: page.canRestore
        liveCapable: page.liveCapable
        status: page.status
        error: !page.valid ? "Цвет нужен в формате #RRGGBB" : page.error
        onApply: page.run("apply")
        onRevert: page.run("read")
        onRestore: page.run("restore")
    }
}
