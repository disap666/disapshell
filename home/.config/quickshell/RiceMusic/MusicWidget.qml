pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

// One widget of the merged RiceDesktop process (see ../RiceDesktop/shell.qml).
Scope {
    id: root
    property bool shown: true
    property bool karaoke: false
    // Options from ~/.config/rice-theme/music.json (Settings, Виджеты, Музыка).
    property var opts: ({ visible: true, onTop: false, player: "", lyricsOnStart: false, opacity: 1, style: "classic" })
    property bool optsReady: false
    FileView {
        path: Quickshell.env("HOME") + "/.config/rice-theme/music.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.opts = Object.assign({ visible: true, onTop: false, player: "", lyricsOnStart: false, opacity: 1, style: "classic" }, JSON.parse(text())); } catch (e) {}
            root.shown = root.opts.visible !== false;
            if (!root.optsReady && root.opts.lyricsOnStart && root.look === "classic") root.karaoke = true;
            root.optsReady = true;
        }
        onLoadFailed: root.optsReady = true
    }
    // "classic" is drawn here; the other looks live in Look*.qml.
    readonly property string look: ["classic", "vinyl", "square", "cassette", "pill", "round"].indexOf(opts.style) >= 0 ? opts.style : "classic"
    readonly property var lookSizes: ({ classic: [640, 160], vinyl: [300, 380], square: [260, 260], cassette: [380, 250], pill: [440, 76], round: [250, 300] })
    readonly property real baseWidth: lookSizes[look][0]
    readonly property real baseHeight: lookSizes[look][1]
    readonly property real expandedHeight: look === "classic" ? baseHeight + 234 : baseHeight
    onLookChanged: if (look !== "classic") karaoke = false
    Settings {
        id: saved
        location: Qt.resolvedUrl("position.ini")
        property real left: -1
        property real top: 70
        property real widgetScale: 1
        property string lookScales: "{}"
    }
    readonly property real curScale: {
        if (look === "classic") return saved.widgetScale;
        try { var m = JSON.parse(saved.lookScales); return m[look] || 1; } catch (e) { return 1; }
    }
    function setScale(v) {
        if (look === "classic") { saved.widgetScale = v; return; }
        var m = {}; try { m = JSON.parse(saved.lookScales); } catch (e) {}
        m[look] = v; saved.lookScales = JSON.stringify(m);
    }
    property var lyrics: []
    property bool synced: false
    property string lyricsStatus: ""
    property string requestKey: ""
    readonly property string trackKey: player ? JSON.stringify([player.trackTitle, player.trackArtist, player.trackAlbum, Math.round(player.length)]) : ""
    readonly property int activeLine: {
        let found = -1;
        if (synced) for (let i = 0; i < lyrics.length; i++) {
            if (lyrics[i].time > elapsed) break;
            found = i;
        }
        return found;
    }
    onActiveLineChanged: if (synced && activeLine >= 0) lyricList.positionViewAtIndex(activeLine, ListView.Center)
    onTrackKeyChanged: {
        lyrics = []; synced = false; lyricsStatus = "";
        if (karaoke) lyricDelay.restart();
    }
    onKaraokeChanged: {
        if (karaoke && lyrics.length === 0) lyricDelay.restart();
        Qt.callLater(() => { card.y = Math.max(0, Math.min(card.y, desktop.height - card.height)); });
    }
    function fetchLyrics() {
        if (!karaoke || !player || !player.trackTitle) { lyricsStatus = "Включи музыку в плеере"; return; }
        if (lyricProcess.running) return;
        requestKey = trackKey;
        lyricsStatus = "Поиск текста…";
        lyricProcess.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/RiceMusic/lyrics.py", requestKey];
        lyricProcess.running = true;
    }
    Timer { id: lyricDelay; interval: 350; onTriggered: root.fetchLyrics() }
    Process {
        id: lyricProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.requestKey !== root.trackKey) { if (root.karaoke) lyricDelay.restart(); return; }
                try {
                    const result = JSON.parse(text);
                    root.lyrics = result.lines || [];
                    root.synced = !!result.synced;
                    root.lyricsStatus = result.message || "";
                    Qt.callLater(() => { if (root.activeLine >= 0) lyricList.positionViewAtIndex(root.activeLine, ListView.Center); });
                } catch (e) { root.lyricsStatus = "Не удалось загрузить текст. Открой обложку повторно."; }
            }
        }
    }
    readonly property var player: {
        const players = Mpris.players.values;
        const want = (root.opts.player || "").toLowerCase();
        const preferred = want ? players.filter(p => (p.identity || "").toLowerCase().indexOf(want) >= 0) : [];
        return preferred.find(p => p.isPlaying) || preferred[0] || players.find(p => p.isPlaying) || players.find(p => /spotify/i.test(p.identity)) || players[0] || null;
    }
    readonly property bool playing: player !== null && player.isPlaying
    property real elapsed: 0
    function syncPosition() { elapsed = player ? Math.max(0, player.position) : 0; }
    onPlayerChanged: syncPosition()
    Connections {
        target: root.player
        function onPositionChanged() { root.syncPosition(); }
        function onTrackChanged() { root.syncPosition(); }
    }
    Timer { interval: root.karaoke ? 100 : 500; repeat: true; running: root.playing && root.shown; onTriggered: root.syncPosition() }
    function clock(seconds) {
        const s = Math.max(0, Math.floor(seconds || 0));
        return Math.floor(s / 60) + ":" + (s % 60).toString().padStart(2, "0");
    }
    IpcHandler {
        target: "music"
        function toggle(): void { root.shown = !root.shown; }
        function karaoke(): void { if (root.look === "classic") root.karaoke = !root.karaoke; }
        function status(): string { return JSON.stringify({shown: root.shown, karaoke: root.karaoke, x: card.x, y: card.y, width: card.width, height: card.height, scale: root.curScale, look: root.look, deskWidth: desktop.width, deskHeight: desktop.height, player: root.player ? root.player.identity : "", players: Mpris.players.values.map(p => p.identity), lines: root.lyrics.length, synced: root.synced, message: root.lyricsStatus}); }
        function show(): void { root.shown = true; }
        function hide(): void { root.shown = false; }
        function place(x: real, y: real): void {
            card.x = Math.max(0, Math.min(x, desktop.width - card.width));
            card.y = Math.max(0, Math.min(y, desktop.height - card.height));
            card.savePosition();
        }
        function resize(scale: real): void {
            root.setScale(Math.max(0.65, Math.min(1.8, scale)));
            saved.sync();
            Qt.callLater(() => { card.x = Math.max(0, Math.min(card.x, desktop.width - card.width)); card.y = Math.max(0, Math.min(card.y, desktop.height - card.height)); card.savePosition(); });
        }
    }

    component MusicButton: Rectangle {
        id: button
        property string glyph: "play"
        property bool available: true
        property bool highlighted: false
        property int glyphSize: 20
        signal clicked()
        width: 44; height: 38; radius: 13
        color: hit.pressed ? Rice.Theme.color("#35ffffff") : hit.containsMouse ? Rice.Theme.color("#18ffffff") : "transparent"
        opacity: available ? 1 : 0.3
        Behavior on color { ColorAnimation { duration: 120 } }
        PlayerGlyph { anchors.centerIn: parent; width: button.glyphSize; height: button.glyphSize; kind: button.glyph; col: button.highlighted ? Rice.Theme.color("#d9bcff") : Rice.Theme.color("#f2edf8") }
        MouseArea { id: hit; anchors.fill: parent; enabled: button.available; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }

    PanelWindow {
        id: desktop
        visible: root.shown
        anchors { top: true; right: true; bottom: true; left: true }
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "rice-music"
        WlrLayershell.layer: root.opts.onTop ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: card }
        Rectangle {
            id: card
            readonly property real uiScale: Math.min(root.curScale, desktop.width / root.baseWidth, desktop.height / root.expandedHeight)
            width: root.baseWidth * uiScale
            height: (root.karaoke ? root.expandedHeight : root.baseHeight) * uiScale
            onHeightChanged: if (y + height > desktop.height) y = Math.max(0, desktop.height - height)
            Behavior on height { NumberAnimation { duration: 460; easing.type: Easing.InOutCubic } }
            x: Math.max(0, Math.min(saved.left < 0 ? desktop.width - width - 24 : saved.left, desktop.width - width))
            y: Math.max(0, Math.min(saved.top, desktop.height - height))
            radius: 26 * uiScale
            opacity: root.opts.opacity === undefined ? 1 : root.opts.opacity
            function savePosition() { saved.left = x; saved.top = y; saved.sync(); }
            color: "transparent"
            Rectangle {   // glass of the classic look
                visible: root.look === "classic"
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: Rice.Theme.color("#555c506e") }
                    GradientStop { position: 0.45; color: Rice.Theme.color("#402a2438") }
                    GradientStop { position: 1; color: Rice.Theme.color("#70201c2a") }
                }
                border.width: 1; border.color: Rice.Theme.color("#60e4d4f6")
            }
            // other looks: drag anywhere on the body, the look's own buttons sit above
            MouseArea {
                visible: root.look !== "classic"
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: card
                drag.minimumX: 0; drag.maximumX: Math.max(0, desktop.width - card.width)
                drag.minimumY: 0; drag.maximumY: Math.max(0, desktop.height - card.height)
                drag.threshold: 3
                onReleased: card.savePosition()
                onCanceled: card.savePosition()
            }
            Loader {
                active: root.look !== "classic"
                width: root.baseWidth; height: root.baseHeight
                scale: card.uiScale; transformOrigin: Item.TopLeft
                sourceComponent: ({ vinyl: vinylLook, square: squareLook, cassette: cassetteLook, pill: pillLook, round: roundLook })[root.look] || null
            }
            Component { id: vinylLook;    LookVinyl    { music: root } }
            Component { id: squareLook;   LookSquare   { music: root } }
            Component { id: cassetteLook; LookCassette { music: root } }
            Component { id: pillLook;     LookPill     { music: root } }
            Component { id: roundLook;    LookRound    { music: root } }
            Item {
            visible: root.look === "classic"
            width: root.baseWidth; height: card.height / card.uiScale
            scale: card.uiScale; transformOrigin: Item.TopLeft
            MouseArea {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 100
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: card
                drag.minimumX: 0; drag.maximumX: Math.max(0, desktop.width - card.width)
                drag.minimumY: 0; drag.maximumY: Math.max(0, desktop.height - card.height)
                drag.threshold: 3
                onReleased: card.savePosition()
                onCanceled: card.savePosition()
            }
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 24; color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#16ffffff") }
            Rectangle { x: 28; y: 1; width: parent.width - 56; height: 1; color: Rice.Theme.color("#65ffffff") }
            Rectangle {
                id: artwork
                x: 20; y: 20; width: 104; height: 104; radius: 16
                scale: root.karaoke ? 1.06 : (coverHit.containsMouse ? 1.03 : 1)
                rotation: root.karaoke ? -4 : 0
                Behavior on scale { NumberAnimation { duration: 440; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: 440; easing.type: Easing.OutBack } }
                color: Rice.Theme.color("#35b9a3d3")
                Text { font.family: Rice.Theme.fontFamily; anchors.centerIn: parent; text: "♫"; color: Rice.Theme.color("#e8ddf5"); font.pixelSize: (34 * Rice.Theme.textScale); visible: cover.status !== Image.Ready }
                Image {
                    id: cover
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    asynchronous: true; sourceSize: Qt.size(160,160)
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask }
                }
                Rectangle { id: artMask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
                Rectangle { anchors.fill: parent; radius: 16; color: "transparent"; border.width: 1; border.color: Rice.Theme.color("#25ffffff") }
                MouseArea {
                    id: coverHit
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.karaoke = !root.karaoke
                }
            }
            Text {
                x: 144; y: 23; width: 420
                text: root.player ? (root.player.trackTitle || "Без названия") : "Сейчас не играет"
                elide: Text.ElideRight; color: Rice.Theme.color("#faf6ff"); font.family: Rice.Theme.fontFamily; font.pixelSize: (15 * Rice.Theme.textScale); font.weight: Font.DemiBold
            }
            Text {
                x: 144; y: 55; width: 185
                text: root.player ? (root.player.trackArtist || root.player.identity) : "Включи музыку в плеере"
                elide: Text.ElideRight; color: Rice.Theme.color("#aee6ddef"); font.family: Rice.Theme.fontFamily; font.pixelSize: (12 * Rice.Theme.textScale)
            }
            Row {
                x: 594; y: 34; spacing: 3
                Repeater {
                    model: 3
                    Rectangle {
                        id: bar
                        required property int index
                        width: 3; height: 6; radius: 1.5; color: Rice.Theme.color("#d8c4ef")
                        anchors.verticalCenter: parent.verticalCenter
                        SequentialAnimation on height {
                            running: root.playing && root.shown; loops: Animation.Infinite
                            NumberAnimation { to: 9 + bar.index * 5; duration: 280 + bar.index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: 380 - bar.index * 60; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Rectangle {
                id: progress
                x: 144; y: 112; width: parent.width - 168; height: 4; radius: 2; color: Rice.Theme.color("#22ffffff")
                readonly property real duration: root.player ? Math.max(0, root.player.length) : 0
                Rectangle { width: progress.width * Math.max(0, Math.min(1, progress.duration > 0 ? root.elapsed / progress.duration : 0)); height: 4; radius: 2; color: Rice.Theme.color("#c8c5a6e9") }
                MouseArea {
                    anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                    enabled: root.player !== null && root.player.canSeek && progress.duration > 0
                    cursorShape: Qt.PointingHandCursor
                    function seekAt(x) { if (root.player) root.player.position = Math.max(0, Math.min(1, x / width)) * progress.duration; }
                    onPressed: mouse => seekAt(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seekAt(mouse.x); }
                }
            }
            Text { font.family: Rice.Theme.fontFamily; x: 144; y: 125; text: root.clock(root.elapsed); color: Rice.Theme.color("#90eee5f7"); font.pixelSize: (10 * Rice.Theme.textScale) }
            Text { font.family: Rice.Theme.fontFamily; anchors.right: parent.right; anchors.rightMargin: 24; y: 125; text: "−" + root.clock(progress.duration - root.elapsed); color: Rice.Theme.color("#90eee5f7"); font.pixelSize: (10 * Rice.Theme.textScale) }
            Row {
                x: 350; y: 59; spacing: 8
                MusicButton { glyph: "shuffle"; glyphSize: 17; available: root.player !== null && root.player.shuffleSupported; highlighted: root.player !== null && root.player.shuffle; onClicked: root.player.shuffle = !root.player.shuffle }
                MusicButton { glyph: "prev"; available: root.player !== null && root.player.canGoPrevious; onClicked: root.player.previous() }
                MusicButton { glyph: root.playing ? "pause" : "play"; glyphSize: 25; available: root.player !== null && (root.playing ? root.player.canPause : root.player.canPlay); onClicked: root.player.togglePlaying() }
                MusicButton { glyph: "next"; available: root.player !== null && root.player.canGoNext; onClicked: root.player.next() }
                MusicButton { glyph: "repeat"; glyphSize: 17; available: root.player !== null && root.player.loopSupported; highlighted: root.player !== null && root.player.loopState !== MprisLoopState.None; onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None }
            }
            Item {
                x: 20; y: root.karaoke ? root.baseHeight + 2 : root.baseHeight + 16; width: parent.width - 40; height: Math.max(0, parent.height - y - 16)
                opacity: root.karaoke ? 1 : 0
                visible: opacity > 0
                clip: true
                Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }
                Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                Rectangle { width: parent.width; height: 1; color: Rice.Theme.color("#22ffffff") }
                Text { font.family: Rice.Theme.fontFamily;
                    anchors.centerIn: parent; width: parent.width - 20
                    visible: root.lyrics.length === 0
                    text: root.lyricsStatus || "Включи музыку в плеере"
                    wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    color: Rice.Theme.color("#c6b5d9"); font.pixelSize: (13 * Rice.Theme.textScale)
                }
                ListView {
                    id: lyricList
                    anchors { top: parent.top; topMargin: 16; bottom: parent.bottom; left: parent.left; right: parent.right }
                    clip: true; spacing: 12
                    model: root.lyrics
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Text { font.family: Rice.Theme.fontFamily;
                        required property var modelData
                        required property int index
                        width: lyricList.width
                        text: modelData.text || "♪"
                        wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                        color: !root.synced || index === root.activeLine ? Rice.Theme.color("#fff5ff") : Rice.Theme.color("#88c2b3d4")
                        font.pixelSize: index === root.activeLine ? 19 : 15
                        font.weight: index === root.activeLine ? Font.DemiBold : Font.Normal
                        Behavior on color { ColorAnimation { duration: 180 } }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.synced && root.player !== null && root.player.canSeek
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.player.position = parent.modelData.time
                        }
                    }
                }
            }
            }
            MouseArea {
                id: resizeHandle
                anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
                width: 24; height: 24
                cursorShape: Qt.SizeFDiagCursor
                property real startX: 0
                property real startY: 0
                property real startScale: 1
                onPressed: mouse => {
                    const p = mapToItem(desktop.contentItem, mouse.x, mouse.y);
                    startX = p.x; startY = p.y; startScale = root.curScale;
                }
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    const p = mapToItem(desktop.contentItem, mouse.x, mouse.y);
                    const delta = Math.abs(p.x-startX) >= Math.abs(p.y-startY) ? (p.x-startX)/root.baseWidth : (p.y-startY)/(root.karaoke ? root.expandedHeight : root.baseHeight);
                    const limit = Math.min(1.8, (desktop.width-card.x)/root.baseWidth, (desktop.height-card.y)/(root.karaoke ? root.expandedHeight : root.baseHeight));
                    root.setScale(Math.max(Math.min(0.65, limit), Math.min(limit, startScale + delta)));
                }
                onReleased: { saved.sync(); card.savePosition(); }
                onDoubleClicked: { root.setScale(1); saved.sync(); }
                Text { font.family: Rice.Theme.fontFamily; anchors.centerIn: parent; text: "◢"; color: resizeHandle.containsMouse ? Rice.Theme.color("#eedbff") : Rice.Theme.color("#65c6b2dc"); font.pixelSize: (13 * Rice.Theme.textScale) }
                hoverEnabled: true
            }
        }
    }
}
