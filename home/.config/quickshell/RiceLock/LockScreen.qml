pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

// Lock screen: PAM service "hyprlock" + WlSessionLock. Two styles:
//   "Обложка": blurred wallpaper, big clock, macOS-like widgets and avatar
//   "Чёрная дыра": looping video, clock and password field
ShellRoot {
    id: root
    property bool preview: false
    property var appearance: ({style:"Обложка",blur:55,dim:25,video:true,showDate:true,showUser:true,clock24:true,clockSize:138,inputWidth:320,rounding:19,videoOpacity:1,placeholder:"Введите пароль",showMedia:true,showWidgets:true,powerButtons:true})
    FileView {
        path: Quickshell.env("HOME")+"/.config/rice-theme/lock.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.appearance=Object.assign({},root.appearance,JSON.parse(text())); } catch(e) { console.warn("Lock appearance:",e); } }
    }
    FileView { id: faceFile; path: Quickshell.env("HOME")+"/.face"; preload: true; printErrors: false; blockLoading: false }
    FileView { id: wallFile; path: Quickshell.env("HOME")+"/.local/state/wallpaper-picker/current"; preload: true; printErrors: false }
    readonly property string wallpaper: { var p = wallFile.text().trim(); return p ? "file://" + p : ""; }

    property string pending: ""
    property string statusText: ""
    property bool waiting: false
    property int animationFrames: 0
    property int failures: 0
    property int mediaPing: 0   // IPC: toggle the full-screen player
    function submit(password) {
        if (waiting || !password.length) return;
        if (root.preview) { statusText="Предпросмотр · Esc: закрыть";return; }
        pending = password;
        waiting = true;
        statusText = "Проверка…";
        if (!pam.start()) {
            pending = "";
            waiting = false;
            statusText = "Не удалось начать проверку";
        }
    }
    // Answer a pending PAM prompt, otherwise start a new conversation.
    function accept(response) {
        if (pam.active && pam.responseRequired && !root.waiting) {
            root.waiting = true;
            pam.respond(response);
        } else root.submit(response);
    }
    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: {
            if (responseRequired) {
                if (root.pending.length) {
                    const response = root.pending;
                    root.pending = "";
                    respond(response);
                } else {
                    root.statusText = message;
                    root.waiting = false;
                }
            }
        }
        onCompleted: result => {
            root.pending = "";
            root.waiting = false;
            if (result === PamResult.Success) {
                session.locked = false;
                Qt.quit();
            } else {
                root.failures++;
                root.statusText = "Неверный пароль. Попробуй ещё раз";
            }
        }
        onError: { root.pending="";root.waiting=false;root.statusText="Ошибка проверки пароля"; }
    }
    SystemClock { id: clock; precision: SystemClock.Seconds }
    IpcHandler {
        target: "lockStatus"
        function status(): string { return JSON.stringify({preview: root.preview, secure: session.secure, frames: root.animationFrames}); }
        function toggleMedia(): void { root.mediaPing++; }
    }
    WlSessionLock {
        id: session
        locked: !root.preview
        WlSessionLockSurface {
            id: surface
            color: "#000000"
            LockView { anchors.fill: parent }
        }
    }
    FloatingWindow {
        visible: root.preview
        title: "Rice Lock Preview"
        implicitWidth: 1280; implicitHeight: 720
        color: "#000000"
        Loader { anchors.fill: parent; active: root.preview; sourceComponent: LockView {} }
    }

    component LockView: Item {
        Loader {
            anchors.fill: parent
            sourceComponent: root.appearance.style === "Чёрная дыра" ? classicView : coverView
        }
        Component { id: coverView; CoverView {} }
        Component { id: classicView; ClassicView {} }
    }

    // "Обложка"
    component CoverView: Item {
        id: cover
        readonly property real factor: Math.min(width / 1920, height / 1080)
        readonly property color accent: Rice.Theme.palette.colors ? Rice.Theme.palette.colors.accent : "#c6acee"
        property real intro: 0
        NumberAnimation on intro { from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic; running: true }

        // Media: playing player first, then Spotify, then anything; demo track in preview
        QtObject {
            id: demo
            property string trackTitle: "Демо-трек"
            property string trackArtist: "Предпросмотр экрана блокировки"
            property string trackAlbum: ""
            property string trackArtUrl: root.wallpaper
            property bool isPlaying: true
            property real length: 214
            property real position: 71
            property bool canSeek: false
            function previous() {} function next() {}
            function togglePlaying() { isPlaying = !isPlaying; }
        }
        readonly property var player: {
            const ps = Mpris.players.values;
            return ps.find(p => p.isPlaying) || ps.find(p => /spotify/i.test(p.identity)) || ps[0] || (root.preview ? demo : null);
        }
        readonly property string art: player ? (player.trackArtUrl || root.wallpaper) : ""
        readonly property string title: player ? (player.trackTitle || "Без названия") : ""
        readonly property string artist: player ? (player.trackArtist || "") : ""
        readonly property bool playing: !!player && player.isPlaying
        readonly property real length: player && player.length > 0 ? player.length : 0
        property real position: 0
        readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
        Timer {
            interval: 1000; repeat: true; triggeredOnStart: true
            running: cover.player !== null
            onTriggered: { if (cover.player) { if (cover.player === demo && demo.isPlaying) demo.position = (demo.position + 1) % demo.length; cover.position = Math.max(0, cover.player.position); } }
        }
        function control(act) {
            var p = player; if (!p) return;
            if (act === "prev") p.previous(); else if (act === "next") p.next(); else p.togglePlaying();
        }
        function mmss(t) { t = Math.max(0, Math.floor(t)); return Math.floor(t / 60) + ":" + (t % 60 < 10 ? "0" : "") + t % 60; }

        // Full-screen now playing
        property bool expanded: false
        property real expandT: expanded ? 1 : 0
        Behavior on expandT { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
        onPlayerChanged: if (!player) expanded = false
        Connections { target: root; function onMediaPingChanged() { if (cover.player) cover.expanded = !cover.expanded; } }

        // background: wallpaper -> blur -> dim
        Item {
            id: backdrop
            anchors.fill: parent
            visible: false
            AnimatedImage {
                anchors.fill: parent
                source: root.wallpaper
                fillMode: Image.PreserveAspectCrop
                playing: /\.gif$/i.test(root.wallpaper)
                asynchronous: true
            }
        }
        MultiEffect {
            anchors.fill: parent
            source: backdrop
            blurEnabled: true
            blurMax: 64
            blur: root.appearance.blur / 100
            saturation: .15
            scale: 1.04 + .04 * (1 - cover.intro)   // slow settle, hides blurred edges
        }
        Rectangle { anchors.fill: parent; color: "#000000"; opacity: root.appearance.dim / 100 }
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
            anchors.centerIn: parent
            scale: cover.factor

            // Date + clock
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 110 - 30 * (1 - cover.intro)
                opacity: cover.intro * (1 - cover.expandT)
                spacing: -6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.appearance.showDate
                    text: { var d = clock.date.toLocaleDateString(Qt.locale("ru_RU"), "dddd, d MMMM"); return d.charAt(0).toUpperCase() + d.slice(1); }
                    font.family: Rice.Theme.fontFamily; font.pixelSize: 26 * Rice.Theme.textScale; font.weight: Font.DemiBold
                    color: "#e6ffffff"
                }
                Text {
                    id: bigClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, root.appearance.clock24 ? "HH:mm" : "h:mm")
                    font.family: Rice.Theme.fontFamily; font.pixelSize: root.appearance.clockSize * 1.25 * Rice.Theme.textScale; font.weight: Font.Bold
                    font.letterSpacing: -4
                    color: "#f2ffffff"
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#60000000"; shadowBlur: .6; shadowVerticalOffset: 4 }
                }
            }

            // Pills under the clock: battery, layout
            Row {
                visible: root.appearance.showWidgets
                anchors.horizontalCenter: parent.horizontalCenter
                y: 400
                opacity: cover.intro * (1 - cover.expandT)
                spacing: 12
                Pill {
                    visible: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
                    icon: { var d = UPower.displayDevice; return d && d.state === UPowerDeviceState.Charging ? 0xF0084 : 0xF0079; }
                    label: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) + "%" : ""
                }
                Pill { icon: 0xF030C; label: cover.layout; visible: cover.layout.length > 0 }
            }

            // Now playing card (bottom-left); the cover opens full screen
            Item {
                id: media
                visible: root.appearance.showMedia && cover.player !== null
                x: 48; y: 1080 - 48 - height
                width: 460; height: 120
                opacity: cover.intro * (1 - cover.expandT)
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 28
                    color: "#2effffff"
                    border.width: 1; border.color: "#26ffffff"
                    Image {
                        anchors.fill: parent; opacity: .3
                        source: cover.art
                        fillMode: Image.PreserveAspectCrop; sourceSize.width: 48; asynchronous: true
                    }
                    Rectangle {   // progress along the bottom edge
                        anchors.left: parent.left; anchors.bottom: parent.bottom
                        height: 3; width: parent.width * cover.progress
                        color: cover.accent
                        Behavior on width { NumberAnimation { duration: 900 } }
                    }
                }
                Item {   // where the cover sits when collapsed (the morph starts here)
                    id: miniSlot
                    x: 16; y: 16; width: 88; height: 88
                }
                Column {
                    x: 122; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 122 - 132
                    spacing: 3
                    Text { width: parent.width; elide: Text.ElideRight; text: cover.title; font.family: Rice.Theme.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; color: "#ffffff" }
                    Text { width: parent.width; elide: Text.ElideRight; text: cover.artist; font.family: Rice.Theme.fontFamily; font.pixelSize: 15; color: "#c8ffffff" }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    Repeater {
                        model: [[0xF04AE, "prev"], [cover.playing ? 0xF03E4 : 0xF040A, "play"], [0xF04AD, "next"]]
                        Text {
                            id: mctl
                            required property var modelData
                            text: String.fromCodePoint(modelData[0])
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: modelData[1] === "play" ? 30 : 22
                            color: mctlMouse.containsMouse ? "#ffffff" : "#d8ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                id: mctlMouse
                                anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                                onClicked: { cover.control(mctl.modelData[1]); field.forceActiveFocus(); }
                            }
                        }
                    }
                }
            }

            // Avatar, name, password
            Column {
                id: login
                anchors.horizontalCenter: parent.horizontalCenter
                y: 1080 - 300 + 40 * (1 - cover.intro)
                opacity: cover.intro * (1 - cover.expandT)
                spacing: 14
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 84; height: 84; radius: 42
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(cover.accent, 1.25) }
                        GradientStop { position: 1; color: cover.accent }
                    }
                    border.width: 2; border.color: "#59ffffff"
                    ClippingRectangle {
                        anchors.fill: parent; anchors.margins: 2; radius: width / 2; color: "transparent"
                        visible: avatarImg.status === Image.Ready
                        Image { id: avatarImg; anchors.fill: parent; source: faceFile.loaded ? "file://" + faceFile.path : "file://" + Quickshell.env("HOME") + "/.config/quickshell/RiceSettings/assets/banner.png"; fillMode: Image.PreserveAspectCrop; sourceSize.width: 200 }
                    }
                    Text {
                        visible: avatarImg.status !== Image.Ready
                        anchors.centerIn: parent
                        text: Quickshell.env("USER").charAt(0).toUpperCase()
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 38; font.weight: Font.DemiBold; color: "#ffffff"
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.appearance.showUser
                    text: Quickshell.env("USER")
                    font.family: Rice.Theme.fontFamily; font.pixelSize: 20 * Rice.Theme.textScale; font.weight: Font.DemiBold
                    color: "#ffffff"
                }
                Item {
                    id: fieldBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.appearance.inputWidth; height: 46
                    property real shake: 0
                    transform: Translate { x: fieldBox.shake }
                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: fieldBox; property: "shake"; to: -14; duration: 50 }
                        NumberAnimation { target: fieldBox; property: "shake"; to: 12; duration: 70 }
                        NumberAnimation { target: fieldBox; property: "shake"; to: -8; duration: 60 }
                        NumberAnimation { target: fieldBox; property: "shake"; to: 5; duration: 50 }
                        NumberAnimation { target: fieldBox; property: "shake"; to: 0; duration: 50 }
                    }
                    Connections { target: root; function onFailuresChanged() { shakeAnim.restart(); } }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(height / 2, root.appearance.rounding + 4)
                        color: "#40ffffff"
                        border.width: 1
                        border.color: root.statusText.startsWith("Неверный") ? "#ff8a8a" : field.activeFocus ? "#80ffffff" : "#30ffffff"
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 48
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 16 * Rice.Theme.textScale; font.letterSpacing: 3
                        color: "#ffffff"; selectionColor: "#60ffffff"
                        passwordCharacter: "●"
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        focus: true
                        readOnly: root.waiting
                        onAccepted: { const response = text; text = ""; root.accept(response); }
                        Keys.onEscapePressed: { if (cover.expanded) { cover.expanded = false; return; } text = ""; if (root.preview) Qt.quit(); }
                        Keys.onSpacePressed: event => { if (cover.expanded && text.length === 0) { cover.control("play"); event.accepted = true; } else event.accepted = false; }
                        Component.onCompleted: forceActiveFocus()
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; x: 20
                        visible: field.text.length === 0
                        text: root.waiting ? "Проверка…" : root.appearance.placeholder
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 15 * Rice.Theme.textScale
                        color: "#b3ffffff"
                    }
                    Rectangle {   // submit arrow / spinner
                        anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32; radius: 16
                        color: field.text.length || root.waiting ? "#ffffff" : "#26ffffff"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.waiting
                            text: String.fromCodePoint(0xF0054)
                            font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
                            color: field.text.length ? "#1d1d1f" : "#b3ffffff"
                        }
                        Rectangle {
                            visible: root.waiting
                            anchors.centerIn: parent; width: 16; height: 16; radius: 8
                            color: "transparent"; border.width: 2; border.color: "#1d1d1f"
                            Rectangle { width: 6; height: 6; radius: 3; color: "#ffffff"; x: 5; y: -2 }
                            RotationAnimation on rotation { running: root.waiting; from: 0; to: 360; duration: 800; loops: Animation.Infinite }
                        }
                        MouseArea {
                            anchors.fill: parent; enabled: field.text.length > 0 && !root.waiting
                            onClicked: { const r = field.text; field.text = ""; root.accept(r); field.forceActiveFocus(); }
                        }
                    }
                    MouseArea { anchors.fill: parent; anchors.rightMargin: 44; acceptedButtons: Qt.NoButton; cursorShape: Qt.IBeamCursor }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.statusText
                    font.family: Rice.Theme.fontFamily; font.pixelSize: 13 * Rice.Theme.textScale
                    color: root.statusText.startsWith("Неверный") ? "#ffb3b3" : "#b3ffffff"
                }
            }

            // Power (bottom-right)
            Row {
                visible: root.appearance.powerButtons
                anchors.right: parent.right; anchors.rightMargin: 48
                y: 1080 - 48 - 74
                opacity: cover.intro * (1 - cover.expandT)
                spacing: 22
                Repeater {
                    model: [
                        { g: 0xF04B2, t: "Сон",          cmd: ["systemctl", "suspend"] },
                        { g: 0xF0709, t: "Перезагрузка", cmd: ["systemctl", "reboot"] },
                        { g: 0xF0425, t: "Выключение",   cmd: ["systemctl", "poweroff"] }
                    ]
                    Column {
                        id: pw
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 48; height: 48; radius: 24
                            color: pwMouse.containsMouse ? "#59ffffff" : "#33ffffff"
                            border.width: 1; border.color: "#26ffffff"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: String.fromCodePoint(pw.modelData.g); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 22; color: "#ffffff" }
                            MouseArea {
                                id: pwMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (root.preview) root.statusText = "Предпросмотр · " + pw.modelData.t.toLowerCase() + " не выполняется";
                                    else Quickshell.execDetached(pw.modelData.cmd);
                                    field.forceActiveFocus();
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pw.modelData.t
                            font.family: Rice.Theme.fontFamily; font.pixelSize: 12; color: "#d8ffffff"
                            opacity: pwMouse.containsMouse ? 1 : .7
                        }
                    }
                }
            }
        }

        // Full-screen now playing
        Item {
            id: np
            anchors.fill: parent
            visible: cover.expandT > 0.001
            // blurred cover as the backdrop
            Item {
                id: npBack
                anchors.fill: parent
                visible: false
                Image { anchors.fill: parent; source: cover.art; fillMode: Image.PreserveAspectCrop; sourceSize.width: 400; asynchronous: true }
            }
            MultiEffect {
                anchors.fill: parent
                source: npBack
                opacity: cover.expandT
                blurEnabled: true; blurMax: 64; blur: 1
                saturation: .35
                scale: 1.15
            }
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: .42 * cover.expandT }
            Rectangle {
                anchors.fill: parent; opacity: cover.expandT
                gradient: Gradient {
                    GradientStop { position: 0; color: "#66000000" }
                    GradientStop { position: .5; color: "#00000000" }
                    GradientStop { position: 1; color: "#99000000" }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: { cover.expanded = false; field.forceActiveFocus(); } }

            Item {
                width: 1920; height: 1080
                anchors.centerIn: parent
                scale: cover.factor
                readonly property real fade: Math.max(0, (cover.expandT - .45) / .55)

                // small clock on top
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 44
                    opacity: parent.fade
                    text: Qt.formatTime(clock.date, root.appearance.clock24 ? "HH:mm" : "h:mm")
                    font.family: "Unbounded"; font.pixelSize: 34; font.weight: Font.Medium
                    color: "#e6ffffff"
                }
                // collapse chevron
                Rectangle {
                    x: 1920 - 48 - width; y: 44
                    width: 48; height: 48; radius: 24
                    opacity: parent.fade
                    color: collapseMouse.containsMouse ? "#40ffffff" : "#26ffffff"
                    border.width: 1; border.color: "#26ffffff"
                    Text { anchors.centerIn: parent; text: String.fromCodePoint(0xF0140); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 24; color: "#ffffff" }
                    MouseArea { id: collapseMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { cover.expanded = false; field.forceActiveFocus(); } }
                }

                Column {
                    id: npInfo
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 690 + 20 * (1 - parent.fade)
                    width: 640
                    opacity: parent.fade
                    spacing: 6
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: cover.title
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Bold; color: "#ffffff"
                    }
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                        text: cover.artist
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 22; color: "#c8ffffff"
                    }
                    Item { width: 1; height: 22 }
                    // progress
                    Item {
                        width: parent.width; height: 26
                        Rectangle {
                            id: track
                            width: parent.width; height: 6; radius: 3
                            color: "#33ffffff"
                            Rectangle {
                                height: parent.height; radius: 3
                                width: parent.width * cover.progress
                                color: "#ffffff"
                                Behavior on width { NumberAnimation { duration: 900 } }
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -10
                                enabled: !!cover.player && cover.player.canSeek && cover.length > 0
                                onClicked: mouse => { cover.player.position = Math.max(0, Math.min(1, (mouse.x - 10) / track.width)) * cover.length; cover.position = cover.player.position; field.forceActiveFocus(); }
                            }
                        }
                        Text { y: 14; text: cover.mmss(cover.position); font.family: Rice.Theme.fontFamily; font.pixelSize: 14; color: "#b3ffffff" }
                        Text { y: 14; anchors.right: parent.right; text: cover.length ? "−" + cover.mmss(cover.length - cover.position) : "--:--"; font.family: Rice.Theme.fontFamily; font.pixelSize: 14; color: "#b3ffffff" }
                    }
                    Item { width: 1; height: 14 }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 56
                        Repeater {
                            model: [[0xF04AE, "prev", 46], [cover.playing ? 0xF03E4 : 0xF040A, "play", 64], [0xF04AD, "next", 46]]
                            Text {
                                id: bigCtl
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                text: String.fromCodePoint(modelData[0])
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: modelData[2]
                                color: bigMouse.containsMouse ? "#ffffff" : "#e0ffffff"
                                scale: bigMouse.pressed ? .88 : 1
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                MouseArea {
                                    id: bigMouse
                                    anchors.fill: parent; anchors.margins: -12; hoverEnabled: true
                                    onClicked: { cover.control(bigCtl.modelData[1]); field.forceActiveFocus(); }
                                }
                            }
                        }
                    }
                }

                // password stays usable: dots + hint at the bottom
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1080 - 96
                    opacity: parent.fade
                    spacing: 10
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        height: 10
                        Repeater {
                            model: Math.min(24, field.text.length)
                            Rectangle { width: 10; height: 10; radius: 5; color: "#ffffff" }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.waiting ? "Проверка…" : root.statusText
                        font.family: Rice.Theme.fontFamily; font.pixelSize: 14
                        color: root.statusText.startsWith("Неверный") ? "#ffb3b3" : "#99ffffff"
                    }
                }
            }
        }

        // The cover itself: morphs between the card and the centre
        Item {
            width: 1920; height: 1080
            anchors.centerIn: parent
            scale: cover.factor
            visible: media.visible
            readonly property real t: cover.expandT
            readonly property real big: 500
            ClippingRectangle {
                id: morph
                readonly property real sx: media.x + miniSlot.x
                readonly property real sy: media.y + miniSlot.y
                readonly property real bx: (1920 - parent.big) / 2
                readonly property real by: 160
                x: sx + (bx - sx) * parent.t
                y: sy + (by - sy) * parent.t
                width: miniSlot.width + (parent.big - miniSlot.width) * parent.t
                height: width
                radius: 16 + 8 * parent.t
                color: "#30000000"
                opacity: cover.intro
                scale: cover.expanded && !cover.playing ? .86 : 1   // like Music.app: smaller on pause
                Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                Image {
                    anchors.fill: parent
                    source: cover.art
                    fillMode: Image.PreserveAspectCrop; sourceSize.width: 600; asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !cover.player || !cover.player.trackArtUrl && !root.preview
                    text: String.fromCodePoint(0xF075A); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: Math.max(12, Math.round(morph.width * .3)); color: "#80ffffff"
                }
                layer.enabled: parent.t > 0.02
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#99000000"; shadowBlur: 1; shadowVerticalOffset: 18 * parent.t }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { cover.expanded = !cover.expanded; field.forceActiveFocus(); }
                }
            }
        }

        // keyboard layout, polled while the lock is up
        property string layout: ""
        Process {
            id: kb
            command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap' | head -1"]
            stdout: StdioCollector { onStreamFinished: { var t = text.trim(); cover.layout = t.indexOf("Russian") >= 0 ? "RU" : t.indexOf("Ukrainian") >= 0 ? "UA" : t ? "EN" : ""; } }
        }
        Timer { interval: 700; repeat: true; running: root.appearance.showWidgets; triggeredOnStart: true; onTriggered: if (!kb.running) kb.running = true }
    }

    component Pill: Rectangle {
        id: pill
        property int icon
        property string label
        width: pillRow.implicitWidth + 28; height: 38; radius: 19
        color: "#33ffffff"; border.width: 1; border.color: "#26ffffff"
        Row {
            id: pillRow
            anchors.centerIn: parent; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; text: String.fromCodePoint(pill.icon); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18; color: "#ffffff" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: pill.label; font.family: Rice.Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: "#ffffff" }
        }
    }

    // "Чёрная дыра"
    component ClassicView: Item {
        id: view
        property real factor: Math.min(width / 1920, height / 1080)
        Rectangle { anchors.fill: parent; color: Rice.Theme.color("#000000") }
        Item {
            width: 1920; height: 1080
            anchors.centerIn: parent
            scale: view.factor
            MediaPlayer {
                id: movie
                source: "@HOME@/.config/hypr/lock-assets/black-hole-loop.mp4"
                videoOutput: planet
                loops: MediaPlayer.Infinite
                Component.onCompleted: { if(root.appearance.video)play(); }
            }
            Connections { target: root; function onAppearanceChanged() { if(root.appearance.video)movie.play();else movie.pause(); } }
            VideoOutput {
                id: planet
                visible: root.appearance.video
                opacity: root.appearance.videoOpacity
                x: 420; y: 170; width: 1080; height: 624
            }
            Connections {
                target: planet.videoSink
                function onVideoFrameChanged() { root.animationFrames++; }
            }
            Text {
                x: 450; y: 160; width: 1020; height: 190
                text: Qt.formatDateTime(clock.date, root.appearance.clock24 ? "HH:mm" : "h:mm AP")
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                color: Rice.Theme.color("#eee3fa"); font.family: Rice.Theme.fontFamily; font.weight: Font.Light; font.pixelSize: (root.appearance.clockSize * Rice.Theme.textScale)
                style: Text.Outline; styleColor: Rice.Theme.color("#302333")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: 345
                visible: root.appearance.showDate
                text: Qt.locale().toString(clock.date, "dddd  /  d MMMM")
                color: Rice.Theme.color("#bda9d1"); font.family: Rice.Theme.fontFamily; font.pixelSize: (15 * Rice.Theme.textScale)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: 708
                visible: root.appearance.showUser
                text: Quickshell.env("USER")
                color: Rice.Theme.color("#eee3fa"); font.family: Rice.Theme.fontFamily; font.pixelSize: (19 * Rice.Theme.textScale)
            }
            Rectangle {
                x: (1920-width)/2; y: 752; width: root.appearance.inputWidth; height: 56; radius: root.appearance.rounding
                color: Rice.Theme.color("#d935283f"); border.width: 1
                border.color: root.statusText.startsWith("Неверный") ? Rice.Theme.color("#dfa3b7") : Rice.Theme.color("#a88ab9")
                TextInput {
                    id: password
                    anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    font.family: Rice.Theme.fontFamily; font.pixelSize: (16 * Rice.Theme.textScale)
                    color: Rice.Theme.color("#eee3fa"); selectionColor: Rice.Theme.color("#79628e")
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    focus: true
                    readOnly: root.waiting
                    onAccepted: { const response = text; text = ""; root.accept(response); }
                    Keys.onEscapePressed: { text = ""; if (root.preview) Qt.quit(); }
                    Component.onCompleted: forceActiveFocus()
                }
                Text {
                    anchors.centerIn: parent
                    visible: password.text.length === 0
                    text: root.waiting ? "Проверка…" : root.appearance.placeholder
                    color: Rice.Theme.color("#bda9d1"); font.family: Rice.Theme.fontFamily; font.pixelSize: (15 * Rice.Theme.textScale)
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; cursorShape: Qt.IBeamCursor }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter; y: 830
                text: root.statusText
                color: root.statusText.startsWith("Неверный") ? Rice.Theme.color("#dfa3b7") : Rice.Theme.color("#9e8eb5")
                font.family: Rice.Theme.fontFamily; font.pixelSize: (11 * Rice.Theme.textScale)
            }
        }
    }
}
