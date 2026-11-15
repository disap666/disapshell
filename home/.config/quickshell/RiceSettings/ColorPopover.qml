pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls as C

// Inline colour picker: saturation/value square, hue strip, hex, theme + recent swatches.
// Emits picked() continuously while dragging so previews update live.
C.Popup {
    id: pop
    property string title: ""
    property color initial: "#c6acee"
    property real hue: 0
    property real sat: 0
    property real val: 1
    readonly property color current: Qt.hsva(hue, sat, val, 1)
    readonly property string hex: String(current).slice(0, 7)
    signal picked(string hex)

    // last picks survive between popovers for the whole settings session
    property var recent: []
    readonly property var themeSwatches: {
        var c = Rice.Theme.palette.colors || {}, out = [];
        ["accent", "foreground", "background", "surface", "highlight", "muted", "border"].forEach(k => {
            if (c[k] && out.indexOf(String(c[k]).toLowerCase()) < 0) out.push(String(c[k]).toLowerCase());
        });
        return out;
    }
    readonly property var basics: ["#ffffff", "#c6acee", "#a8c9f5", "#9ee0e0", "#b4d3ad", "#f2d49b", "#f5a97f", "#eaa2b1", "#14161b"]

    // load(): opening: remembers the "before" colour; setColor(): just moves the picker
    function load(c) { initial = Qt.color(c); setColor(c); }
    function setColor(c) {
        c = Qt.color(c);
        sat = c.hsvSaturation; val = c.hsvValue;
        if (c.hsvHue >= 0) hue = c.hsvHue;
    }
    function emitNow() { picked(hex); }
    function remember(h) {
        var r = [h].concat(recent.filter(x => x !== h)).slice(0, 9);
        recent = r;
    }
    onClosed: if (hex !== String(initial).slice(0, 7)) remember(hex)

    width: 252
    padding: 12
    modal: false
    focus: true
    closePolicy: C.Popup.CloseOnEscape | C.Popup.CloseOnPressOutside
    enter: Transition { ParallelAnimation {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 }
        NumberAnimation { property: "scale"; from: .94; to: 1; duration: 180; easing.type: Easing.OutBack }
    } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }
    background: Rectangle {
        radius: Tokens.radius + 2
        color: Tokens.surface
        border.width: 1; border.color: Tokens.alpha(Tokens.text, .12)
    }

    contentItem: Column {
        spacing: 10
        Row {
            width: parent.width; spacing: 8
            Text { width: parent.width - 60; text: pop.title; elide: Text.ElideRight; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2; anchors.verticalCenter: parent.verticalCenter }
            // before -> after
            Row {
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 26; height: 20; radius: 5; color: pop.initial; border.width: 1; border.color: Tokens.alpha(Tokens.text, .2)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { pop.setColor(pop.initial); pop.emitNow(); } } }
                Rectangle { width: 26; height: 20; radius: 5; color: pop.current; border.width: 1; border.color: Tokens.alpha(Tokens.text, .2) }
            }
        }

        // saturation × value
        Rectangle {
            id: sv
            width: parent.width; height: 150; radius: 8; clip: true
            color: Qt.hsva(pop.hue, 1, 1, 1)
            Rectangle { anchors.fill: parent; radius: 8
                gradient: Gradient { orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "#ffffffff" }
                    GradientStop { position: 1; color: "#00ffffff" } } }
            Rectangle { anchors.fill: parent; radius: 8
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00000000" }
                    GradientStop { position: 1; color: "#ff000000" } } }
            Rectangle {
                x: pop.sat * sv.width - width / 2; y: (1 - pop.val) * sv.height - height / 2
                width: 16; height: 16; radius: 8
                color: pop.current; border.width: 3; border.color: pop.val > .55 && pop.sat < .4 ? "#202020" : "#ffffff"
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.CrossCursor; preventStealing: true
                function at(m) { pop.sat = Math.max(0, Math.min(1, m.x / width)); pop.val = Math.max(0, Math.min(1, 1 - m.y / height)); pop.emitNow(); }
                onPressed: m => at(m)
                onPositionChanged: m => { if (pressed) at(m); }
            }
        }

        // hue strip
        Rectangle {
            id: hueBar
            width: parent.width; height: 14; radius: 7
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0/6; color: "#ff0000" }
                GradientStop { position: 1/6; color: "#ffff00" }
                GradientStop { position: 2/6; color: "#00ff00" }
                GradientStop { position: 3/6; color: "#00ffff" }
                GradientStop { position: 4/6; color: "#0000ff" }
                GradientStop { position: 5/6; color: "#ff00ff" }
                GradientStop { position: 6/6; color: "#ff0000" } }
            Rectangle {
                x: pop.hue * (hueBar.width - width); y: -2
                width: 10; height: 18; radius: 4
                color: Qt.hsva(pop.hue, 1, 1, 1); border.width: 2; border.color: "#ffffff"
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; preventStealing: true
                function at(m) { pop.hue = Math.max(0, Math.min(.9999, (m.x - 4) / hueBar.width)); pop.emitNow(); }
                onPressed: m => at(m)
                onPositionChanged: m => { if (pressed) at(m); }
            }
        }

        // hex
        Row {
            width: parent.width; spacing: 8
            Text { anchors.verticalCenter: parent.verticalCenter; text: "HEX"; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
            StyledTextField {
                id: hexField
                width: parent.width - 36
                font.family: "JetBrains Mono"
                maximumLength: 7
                text: pop.hex
                onTextEdited: {
                    var t = text.trim(); if (t[0] !== "#") t = "#" + t;
                    if (/^#[0-9a-fA-F]{6}$/.test(t)) { var keep = cursorPosition; pop.setColor(t); pop.emitNow(); cursorPosition = keep; }
                }
            }
        }

        component Swatches: Flow {
            id: flow
            property var colors: []
            property string caption: ""
            width: parent.width; spacing: 6
            visible: colors.length > 0
            Text { width: flow.width; text: flow.caption; font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.text3 }
            Repeater {
                model: flow.colors
                Rectangle {
                    id: chip
                    required property string modelData
                    width: 20; height: 20; radius: 10; color: modelData
                    readonly property bool on: pop.hex.toLowerCase() === modelData.toLowerCase()
                    border.width: on ? 2 : 1
                    border.color: on ? Tokens.text : Tokens.alpha(Tokens.text, .2)
                    scale: chipArea.containsMouse ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { pop.setColor(chip.modelData); pop.emitNow(); } }
                }
            }
        }
        Swatches { caption: "Из темы"; colors: pop.themeSwatches }
        Swatches { caption: "Недавние"; colors: pop.recent }
        Swatches { caption: "Базовые"; colors: pop.basics }
    }
}
