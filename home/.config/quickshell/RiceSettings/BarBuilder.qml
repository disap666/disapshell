pragma ComponentBehavior: Bound
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "WaybarLogic.js" as Logic

// Interactive Waybar builder: a live replica of the bar with drag & drop.
//  - drag a module to reorder it or move it to another zone
//  - drag from the tray below to add, drop on the bin to remove
//  - click to select -> inspector; ←/-> move, Delete removes, Ctrl+Z undo
//  - free placement: drag the | grips on a module's edges to push it apart from its
//    neighbours (Alt+←/-> nudges by 4 px), drop a "Распорка" for an empty gap of any width
ColumnLayout {
    id: builder
    required property var page
    property string wallpaper: ""
    readonly property var config: page.config
    readonly property var look: page.appearance
    readonly property var zoneNames: ["left", "center", "right"]
    readonly property var zones: flatten(config)
    property var selected: null            // {zone, index}
    property var drag: null                // {key, zone, index} | {key, fromTray, extension}
    property var target: null              // {zone, index} | "bin"
    property point pointer: Qt.point(0, 0)
    property var history: []
    property string trayFilter: ""
    spacing: 14
    focus: true

    // model helpers
    function flatten(c) {
        var out = { left: [], center: [], right: [] };
        zoneNames.forEach(z => (c["modules-" + z] || []).forEach(k => {
            var g = c[k];
            if (k.indexOf("group/rice-preset-") === 0 && g && g["_rice-preset-zone"]) out[g["_rice-preset-zone"]] = out[g["_rice-preset-zone"]].concat(g.modules || []);
            else out[z].push(k);
        }));
        return out;
    }
    function commit(next, extra) {
        var c = JSON.parse(JSON.stringify(config));
        history = history.concat([JSON.stringify(config)]).slice(-40);
        Object.keys(c).forEach(k => { if (k.indexOf("group/rice-preset-") === 0 && c[k] && c[k]["_rice-preset-zone"]) delete c[k]; });
        zoneNames.forEach(z => c["modules-" + z] = next[z]);
        if (extra) Object.keys(extra).forEach(k => { if (!c[k]) c[k] = extra[k]; });
        page.replaceConfig(c);
    }
    function undo() {
        if (!history.length) return;
        var prev = JSON.parse(history[history.length - 1]);
        history = history.slice(0, -1);
        page.replaceConfig(prev);
        selected = null;
    }
    function copyZones() { return { left: zones.left.slice(), center: zones.center.slice(), right: zones.right.slice() }; }
    function moveItem(fromZone, fromIndex, toZone, toIndex) {
        var z = copyZones(), key = z[fromZone].splice(fromIndex, 1)[0];
        if (fromZone === toZone && toIndex > fromIndex) toIndex--;
        toIndex = Math.max(0, Math.min(z[toZone].length, toIndex));
        z[toZone].splice(toIndex, 0, key);
        commit(z);
        selected = { zone: toZone, index: toIndex };
    }
    function insertItem(key, toZone, toIndex, settings) {
        var z = copyZones(); z[toZone].splice(toIndex, 0, key);
        var extra = {}; if (settings) extra[key] = JSON.parse(JSON.stringify(settings));
        commit(z, extra);
        selected = { zone: toZone, index: toIndex };
    }
    function removeItem(zone, index) {
        var z = copyZones(); z[zone].splice(index, 1); commit(z); selected = null;
    }
    function nudge(dir) {
        if (!selected) return;
        var z = selected.zone, i = selected.index, list = zones[z];
        if (dir < 0 && i > 0) moveItem(z, i, z, i - 1);
        else if (dir > 0 && i < list.length - 1) moveItem(z, i, z, i + 2);
        else {
            var zi = zoneNames.indexOf(z) + dir;
            if (zi < 0 || zi > 2) return;
            moveItem(z, i, zoneNames[zi], dir > 0 ? 0 : zones[zoneNames[zi]].length);
        }
    }
    // free placement: per-module margins {l, r} and spacer width {w}, stored in appearance.offsets
    readonly property real stageFit: stage.fit
    readonly property var offsets: look.offsets || ({})
    function isGap(key) { return String(key).indexOf("custom/rice-gap") === 0; }
    function offsetOf(key) { var o = offsets[key] || {}; return { l: o.l || 0, r: o.r || 0, w: o.w === undefined ? 40 : o.w }; }
    function setOffset(key, side, value) {
        var all = Object.assign({}, offsets), o = Object.assign({}, all[key] || {});
        o[side] = Math.max(side === "w" ? 4 : 0, Math.min(400, Math.round(value)));
        if (!o.l) delete o.l; if (!o.r) delete o.r;
        if (Object.keys(o).length) all[key] = o; else delete all[key];
        page.setAppearance("offsets", all);
    }
    function clearOffsets(key) { var all = Object.assign({}, offsets); delete all[key]; page.setAppearance("offsets", all); }
    function newGapKey() { var n = 1; while (config["custom/rice-gap-" + n] || zones.left.concat(zones.center, zones.right).indexOf("custom/rice-gap-" + n) >= 0) n++; return "custom/rice-gap-" + n; }
    readonly property var gapSettings: ({ "format": " ", "tooltip": false })

    readonly property var selectedKey: selected && zones[selected.zone] ? zones[selected.zone][selected.index] : ""
    Connections { target: builder.page; function onDirtyChanged() { if (!builder.page.dirty) builder.history = []; } }

    // module presentation
    readonly property var names: ({
        "custom/launcher": "Меню", "clock#date": "Дата", "custom/search": "Поиск", "hyprland/workspaces": "Рабочие столы",
        "custom/media": "Трек", "custom/previous": "Назад", "custom/play": "Пауза", "custom/next": "Вперёд", "clock": "Часы",
        "temperature": "Температура", "hyprland/language": "Раскладка", "custom/telegram": "Telegram", "network": "Сеть",
        "bluetooth": "Bluetooth", "pulseaudio": "Громкость", "battery": "Батарея", "custom/notification": "Уведомления",
        "backlight": "Яркость", "cpu": "Процессор", "memory": "Память", "disk": "Диск", "tray": "Трей",
        "idle_inhibitor": "Не засыпать", "hyprland/window": "Активное окно", "wlr/taskbar": "Панель приложений",
        "mpris": "Медиаплеер", "pulseaudio/slider": "Ползунок громкости", "network#speed": "Скорость сети", "custom/rice-settings": "Настройки"
    })
    readonly property var samples: ({
        usage: "12", percentage: "41", capacity: "87", volume: "60", temperatureC: "52", percent: "70", short: "EN",
        percentage_used: "38", bandwidthDownBytes: "1.2M", bandwidthUpBytes: "84K", artist: "Juice WRLD", title: "Come & Go", essid: "home"
    })
    function nameOf(key) {
        if (names[key]) return names[key];
        if (key.indexOf("group/") === 0) return "Группа " + key.slice(6);
        if (isGap(key)) return "Распорка";
        var ext = Logic.extensions.find(e => e.id === key);
        return ext ? ext.name : key.replace(/^custom\//, "");
    }
    // Waybar clock formats: "{:%d %b}" drawn with today's date in the system locale.
    function strftime(format, fallback) {
        var found = /\{:([^}]*)\}/.exec(typeof format === "string" ? format : "");
        var d = new Date(), loc = Qt.locale();
        var map = { H: "HH", M: "mm", S: "ss", d: "dd", m: "MM", Y: "yyyy", y: "yy", b: "MMM", B: "MMMM", a: "ddd", A: "dddd" };
        return (found ? found[1] : fallback).replace(/%([A-Za-z])/g, (all, c) =>
            c === "I" ? String(d.getHours() % 12 || 12) : c === "p" ? (d.getHours() < 12 ? "AM" : "PM") : map[c] ? loc.toString(d, map[c]) : "");
    }
    // Text in the theme font, icon glyphs in the Nerd Font, as Waybar draws them.
    function rich(key) {
        return render(key).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/ /g, "&nbsp;")
            .replace(/([\uE000-\uF8FF]|[\uDB80-\uDBFF][\uDC00-\uDFFF])+/g, run => "<span style=\"font-family:'JetBrainsMono Nerd Font'\">" + run + "</span>");
    }
    function render(key) {
        var m = config[key] || (Logic.extensions.find(e => e.id === key) || {}).settings || {};
        if (isGap(key)) return "";
        if (key === "clock" || key === "clock#date") return strftime(m["format"], key === "clock" ? "%H:%M" : "%d %b");
        if (key === "custom/media") return "Come & Go";
        if (key === "hyprland/workspaces") {
            var wsIcons = m["format-icons"] || {}, pinned = m["persistent-workspaces"] || {};
            var count = Math.max(1, (pinned["*"] || pinned[Object.keys(pinned)[0]] || [1, 2, 3, 4, 5]).length || 5);
            var row = [];
            for (var w = 0; w < count; w++) row.push(w === 0 ? (wsIcons.active || "━") : (wsIcons["default"] || "○"));
            return row.join(" ");
        }
        if (key === "tray") return "󰀻 ▪ ▪ ▪";
        if (key === "wlr/taskbar") return "  󰈹 ";
        if (key === "pulseaudio/slider") return "━━━━○───";
        if (key === "hyprland/window") return "kitty: ~/projects";
        if (key.indexOf("group/") === 0) return "⧉ " + ((m.modules || []).length) + " мод.";
        if (key === "custom/notification") return "󰂚";
        var f = m["format"];
        if (typeof f !== "string" || !f.length) f = m["format-wifi"] || m["format-connected"] || m["format-ethernet"] || "";
        if (typeof f !== "string" || !f.length) f = key === "battery" ? " {capacity}%" : "";
        var icons = m["format-icons"], icon = "";
        if (Array.isArray(icons)) icon = icons[Math.floor(icons.length / 2)] || "";
        else if (icons && typeof icons === "object") icon = icons["default"] ? (Array.isArray(icons["default"]) ? icons["default"][1] || icons["default"][0] : icons["default"]) : (icons[Object.keys(icons)[0]] || "");
        var out = f.replace(/\{([^}:]*)(:[^}]*)?\}/g, (all, name) => name === "icon" ? icon : (samples[name] !== undefined ? samples[name] : (name === "" ? (key.indexOf("custom/") === 0 ? "" : "kitty") : "")));
        out = out.trim();
        return out.length ? out : nameOf(key);
    }

    // keyboard
    Keys.onPressed: event => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) { undo(); event.accepted = true; return; }
        if (!selected) return;
        if ((event.modifiers & Qt.AltModifier) && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            var o = offsetOf(selectedKey), step = (event.modifiers & Qt.ShiftModifier) ? 16 : 4;
            if (event.key === Qt.Key_Right) { if (o.r > 0) setOffset(selectedKey, "r", o.r - step); else setOffset(selectedKey, "l", o.l + step); }
            else { if (o.l > 0) setOffset(selectedKey, "l", o.l - step); else setOffset(selectedKey, "r", o.r + step); }
            event.accepted = true; return;
        }
        if (event.key === Qt.Key_Left) { nudge(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Right) { nudge(1); event.accepted = true; }
        else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { removeItem(selected.zone, selected.index); event.accepted = true; }
        else if (event.key === Qt.Key_Escape) { selected = null; event.accepted = true; }
    }

    // drag engine (pointer in stage coords)
    function startDrag(info, item, mx, my) {
        drag = info; forceActiveFocus();
        pointer = item.mapToItem(stage, mx, my);
        updateTarget();
    }
    function moveDrag(item, mx, my) { pointer = item.mapToItem(stage, mx, my); updateTarget(); }
    function endDrag() {
        var d = drag, t = target;
        drag = null; target = null;
        if (!d || !t) return;
        if (t === "bin") { if (!d.fromTray) removeItem(d.zone, d.index); return; }
        if (d.fromTray) insertItem(d.key, t.zone, t.index, d.settings);
        else moveItem(d.zone, d.index, t.zone, t.index);
    }
    function updateTarget() {
        var p = pointer;
        var b = bin.mapFromItem(stage, p.x, p.y);
        if (drag && !drag.fromTray && bin.visible && b.x >= -10 && b.y >= -10 && b.x <= bin.width + 10 && b.y <= bin.height + 10) { target = "bin"; return; }
        var best = null, bestDist = 1e9;
        [leftZone, centerZone, rightZone].forEach(zoneItem => {
            var local = zoneItem.mapFromItem(stage, p.x, p.y);
            var dx = local.x < 0 ? -local.x : local.x > zoneItem.width ? local.x - zoneItem.width : 0;
            var dy = local.y < 0 ? -local.y : local.y > zoneItem.height ? local.y - zoneItem.height : 0;
            var dist = dx + dy * 3;
            if (dist < bestDist) { bestDist = dist; best = { item: zoneItem, x: local.x }; }
        });
        if (!best || bestDist > 140) { target = null; return; }
        var zone = best.item.zone, rep = best.item.repeater, idx = rep.count;
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i);
            if (it && best.x < it.x + it.width / 2) { idx = i; break; }
        }
        target = { zone: zone, index: idx };
    }

    // overlay for the drag ghost (outside the clipped stage)
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        Layout.bottomMargin: -builder.spacing
        z: 100
            // ghost under the pointer
        Rectangle {
            visible: !!builder.drag
            z: 50
            x: builder.pointer.x + stageFrame.x - width / 2; y: builder.pointer.y + stageFrame.y - height / 2
            width: ghostText.implicitWidth + 24; height: 32; radius: 10
            color: Qt.alpha(builder.look.background || "#201a2d", .95)
            border.width: 2; border.color: Tokens.accent
            scale: 1.08
            Rectangle { anchors.fill: parent; anchors.margins: -6; z: -1; radius: 14; color: "#000000"; opacity: .25 }
            Text { id: ghostText; anchors.centerIn: parent; text: builder.drag ? builder.rich(builder.drag.key) : ""; textFormat: Text.RichText; font.family: Rice.Theme.fontFamily; font.pixelSize: 13; color: builder.look.foreground || "#eee3fa" }
        }
    }

    // stage: wallpaper strip + the bar
    ClippingRectangle {
        id: stageFrame
        Layout.fillWidth: true
        Layout.preferredHeight: 150
        radius: Tokens.radius
        color: "#14121c"
        Image { anchors.fill: parent; source: builder.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1200; verticalAlignment: Image.AlignTop }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#30000000" } GradientStop { position: 1; color: "#a0000000" } } }
        // window silhouettes below the bar, for scale
        Row {
            x: 18; y: 84; spacing: 12; opacity: .5
            Repeater { model: [.46, .3]; Rectangle { required property real modelData; width: stageFrame.width * modelData; height: 90; radius: 10; color: Qt.alpha(Tokens.base, .7); border.width: 1; border.color: Qt.alpha(builder.look.border || "#ffffff", .3) } }
        }

        Item {
            id: stage
            anchors.fill: parent
            // natural width of all chips; scale the bar down when it would not fit
            readonly property real natural: Math.max(leftZone.implicitWidth, rightZone.implicitWidth) * 2 + centerZone.implicitWidth + 90
            readonly property real fit: Math.min(1, (width - 24) / natural)

            Item {
                id: barBox
                readonly property real m: Math.min(14, (builder.config["margin-top"] || 0))
                readonly property int parts: builder.look.layout || 3
                readonly property real h: Math.max(30, Math.min(46, builder.config.height || 40))
                readonly property color bg: builder.look.background || "#201a2d"
                readonly property color hi: builder.look.highlight || "#493957"
                readonly property real alpha: (builder.look.opacity === undefined ? 82 : builder.look.opacity) / 100
                readonly property real r: Math.min(h / 2, builder.look.radius || 0)
                readonly property color edge: Qt.alpha(builder.look.border || "#d8c0f2", (builder.look.borderOpacity === undefined ? 34 : builder.look.borderOpacity) / 100)
                width: (stage.width - 24) / stage.fit
                height: h
                x: 12; y: 12 + m * .5
                scale: stage.fit
                transformOrigin: Item.TopLeft

                readonly property bool grad: !!builder.look.gradient
                readonly property real bw: builder.look.borderWidth === undefined ? 1 : builder.look.borderWidth
                component Surface: Rectangle {
                    required property Item box
                    radius: box.r
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(box.grad ? box.hi : box.bg, box.grad ? box.alpha * .6 : box.alpha) }
                        GradientStop { position: 1; color: Qt.alpha(box.bg, box.alpha) }
                    }
                    border.width: box.bw
                    border.color: box.edge
                }
                Surface { box: barBox; visible: barBox.parts === 1; anchors.fill: parent }
                Surface { box: barBox; visible: barBox.parts >= 2; x: leftZone.x - 8; width: leftZone.width + 16; height: parent.height }
                Surface { box: barBox; visible: barBox.parts >= 3; x: centerZone.x - 8; width: centerZone.width + 16; height: parent.height }
                Surface { box: barBox; visible: barBox.parts >= 2; x: rightZone.x - 8; width: rightZone.width + 16; height: parent.height }

                Zone { id: leftZone; b: builder; box: barBox; zone: "left"; x: 8 }
                Zone { id: centerZone; b: builder; box: barBox; zone: "center"; x: (barBox.width - width) / 2 }
                Zone { id: rightZone; b: builder; box: barBox; zone: "right"; x: barBox.width - width - 8 }
            }

            // drop indicator
            Rectangle {
                id: caret
                readonly property var info: builder.target && builder.target !== "bin" ? builder.target : null
                readonly property Item zoneItem: info ? (info.zone === "left" ? leftZone : info.zone === "center" ? centerZone : rightZone) : null
                readonly property Item before: zoneItem && info.index < zoneItem.repeater.count ? zoneItem.repeater.itemAt(info.index) : null
                readonly property Item after: zoneItem && info.index > 0 ? zoneItem.repeater.itemAt(info.index - 1) : null
                readonly property real localX: !zoneItem ? 0 : before ? before.x - 3 : after ? after.x + after.width + 1 : zoneItem.width / 2
                visible: !!info
                x: zoneItem ? barBox.x + (zoneItem.x + localX) * stage.fit - 1 : 0; y: barBox.y + 4 * stage.fit
                width: 3; height: (barBox.h - 8) * stage.fit; radius: 1.5
                color: Tokens.accent
                Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                SequentialAnimation on opacity { running: caret.visible; loops: Animation.Infinite; NumberAnimation { to: .45; duration: 420 } NumberAnimation { to: 1; duration: 420 } }
            }

            // zone captions
            Repeater {
                model: [[leftZone, "Слева"], [centerZone, "Центр"], [rightZone, "Справа"]]
                Text {
                    required property var modelData
                    x: barBox.x + (modelData[0].x + modelData[0].width / 2) * stage.fit - width / 2; y: barBox.y + barBox.h * stage.fit + 8
                    text: modelData[1] + " · " + builder.zones[modelData[0].zone].length
                    font.family: Tokens.font; font.pixelSize: 11; font.weight: Font.Medium
                    color: builder.drag ? "#ffffff" : "#b0ffffff"
                    opacity: builder.drag ? 1 : .8
                }
            }

            // bin
            Rectangle {
                id: bin
                visible: !!builder.drag && !builder.drag.fromTray
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                width: binLabel.implicitWidth + 44; height: 36; radius: 18
                color: builder.target === "bin" ? Qt.alpha(Tokens.danger, .55) : Qt.alpha("#000000", .55)
                border.width: 1; border.color: Qt.alpha(Tokens.danger, builder.target === "bin" ? .9 : .4)
                scale: builder.target === "bin" ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 120 } }
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: Tokens.glyph(0xF0A7A); font.family: Tokens.iconFont; font.pixelSize: 16; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: binLabel; text: "Убрать с панели"; font.family: Tokens.font; font.pixelSize: 12; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                }
            }

        }
    }

    // a zone of chips
    component Zone: Row {
        id: zoneRow
        required property string zone
        required property var b
        required property Item box
        readonly property alias repeater: chips
        readonly property bool hot: !!zoneRow.b.target && zoneRow.b.target !== "bin" && zoneRow.b.target.zone === zone
        height: zoneRow.box.h
        spacing: Math.max(2, zoneRow.b.config.spacing || 2)
        // keep an empty zone droppable
        Rectangle {
            visible: chips.count === 0
            width: 70; height: zoneRow.box.h - 10; anchors.verticalCenter: parent.verticalCenter
            radius: 8; color: zoneRow.hot ? Qt.alpha(Tokens.accent, .2) : "transparent"
            border.width: 1; border.color: Qt.alpha("#ffffff", zoneRow.b.drag ? .5 : .18)
            Text { anchors.centerIn: parent; text: "пусто"; font.pixelSize: 10; color: "#90ffffff" }
        }
        Repeater {
            id: chips
            model: zoneRow.b.zones[zoneRow.zone]
            Item {
                id: chip
                required property string modelData
                required property int index
                readonly property bool isSelected: !!zoneRow.b.selected && zoneRow.b.selected.zone === zoneRow.zone && zoneRow.b.selected.index === index
                readonly property bool lifted: !!zoneRow.b.drag && !zoneRow.b.drag.fromTray && zoneRow.b.drag.zone === zoneRow.zone && zoneRow.b.drag.index === index
                readonly property bool battery: modelData === "battery"
                readonly property bool gap: zoneRow.b.isGap(modelData)
                readonly property var off: zoneRow.b.offsetOf(modelData)
                property bool gripping: false
                readonly property bool showGrips: (isSelected || chipHover.hovered || gripping) && !zoneRow.b.drag
                readonly property real core: gap ? off.w : label.implicitWidth + Math.max(10, (zoneRow.b.look.padding || 6) * 1.6)
                width: off.l + core + off.r
                height: zoneRow.box.h
                opacity: lifted ? .25 : 1
                HoverHandler { id: chipHover }

                // margins, shown as tinted space with the pixel count
                Repeater {
                    model: [["l", 0], ["r", 1]]
                    Rectangle {
                        id: marginBox
                        required property var modelData
                        readonly property real px: chip.off[modelData[0]]
                        visible: px > 0
                        x: modelData[1] === 0 ? 0 : chip.off.l + chip.core
                        width: px; height: chip.height - 16; y: 8; radius: 4
                        color: Qt.alpha(Tokens.accent, chip.showGrips ? .22 : .08)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; visible: parent.width > 22 && chip.showGrips; text: Math.round(marginBox.px); font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                    }
                }

                Item {
                    id: body
                    x: chip.off.l; width: chip.core; height: parent.height
                    Rectangle {
                        anchors.fill: parent; anchors.topMargin: 6; anchors.bottomMargin: 6
                        radius: Math.min(height / 2, Math.max(6, (zoneRow.b.look.radius || 0) * .6))
                        color: chip.battery ? (zoneRow.b.look.accent || "#c6acee")
                             : chip.isSelected ? Qt.alpha(Tokens.accent, .28)
                             : hover.containsMouse ? Qt.alpha("#ffffff", .12) : "transparent"
                        border.width: chip.isSelected ? 1.5 : chip.gap ? 1 : 0
                        border.color: chip.gap && !chip.isSelected ? Qt.alpha("#ffffff", .35) : Tokens.accent
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    // spacer: a dashed-looking empty slot with its width
                    Row {
                        visible: chip.gap
                        anchors.centerIn: parent; spacing: 3
                        Repeater { model: Math.max(1, Math.floor((chip.core - 12) / 7)); Rectangle { width: 4; height: 1.5; color: Qt.alpha("#ffffff", .45) } }
                    }
                    Text {
                        visible: chip.gap && chip.core > 30
                        anchors.centerIn: parent; anchors.verticalCenterOffset: -8
                        text: chip.off.w; font.pixelSize: 9; font.weight: Font.Bold; color: Qt.alpha("#ffffff", .7)
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: hover.pressed && !zoneRow.b.drag ? 1 : 0
                        text: zoneRow.b.rich(chip.modelData)
                        textFormat: Text.RichText
                        font.family: Rice.Theme.fontFamily
                        font.pixelSize: Math.max(10, zoneRow.b.look.fontSize || 12)
                        font.weight: chip.battery || chip.modelData === "clock" ? Font.Bold : Font.Normal
                        color: chip.battery ? (zoneRow.b.look.background || "#201a2d") : (zoneRow.b.look.foreground || "#eee3fa")
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: zoneRow.b.drag ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point origin
                        onPressed: mouse => { origin = Qt.point(mouse.x, mouse.y); zoneRow.b.forceActiveFocus(); }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            if (!zoneRow.b.drag && Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 6)
                                zoneRow.b.startDrag({ key: chip.modelData, zone: zoneRow.zone, index: chip.index }, hover, mouse.x, mouse.y);
                            else if (zoneRow.b.drag) zoneRow.b.moveDrag(hover, mouse.x, mouse.y);
                        }
                        onReleased: { if (zoneRow.b.drag) zoneRow.b.endDrag(); else zoneRow.b.selected = { zone: zoneRow.zone, index: chip.index }; }
                        onDoubleClicked: zoneRow.b.clearOffsets(chip.modelData)
                        ToolTip.visible: containsMouse && !zoneRow.b.drag
                        ToolTip.delay: 500
                        ToolTip.text: zoneRow.b.nameOf(chip.modelData)
                    }
                }

                // | grips: left pushes the module away from its left neighbour,
                //   right pushes the right neighbour away (for a spacer: its width)
                Repeater {
                    model: ["l", "r"]
                    Rectangle {
                        id: grip
                        required property string modelData
                        readonly property bool active: gripArea.pressed
                        property real start: 0
                        property real originX: 0
                        // stay grabbable when the replica is scaled down to fit many modules
                        readonly property real k: 1 / Math.max(.35, zoneRow.b.stageFit)
                        x: modelData === "l" ? body.x - width / 2 : body.x + body.width - width / 2
                        width: 6 * k; height: zoneRow.box.h - 14; y: 7; radius: width / 2; z: 5
                        color: active ? "#ffffff" : Tokens.accent
                        opacity: chip.showGrips ? (gripArea.containsMouse || active ? 1 : .75) : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        MouseArea {
                            id: gripArea
                            anchors.fill: parent; anchors.margins: -5 * grip.k
                            enabled: chip.showGrips
                            hoverEnabled: true; preventStealing: true
                            cursorShape: Qt.SizeHorCursor
                            onPressed: m => {
                                chip.gripping = true;
                                zoneRow.b.forceActiveFocus();
                                zoneRow.b.selected = { zone: zoneRow.zone, index: chip.index };
                                grip.originX = mapToItem(zoneRow.b, m.x, 0).x;
                                grip.start = grip.modelData === "l" ? chip.off.l : chip.gap ? chip.off.w : chip.off.r;
                            }
                            onReleased: chip.gripping = false
                            onCanceled: chip.gripping = false
                            onPositionChanged: m => {
                                if (!pressed) return;
                                var d = (mapToItem(zoneRow.b, m.x, 0).x - grip.originX) / Math.max(.1, zoneRow.b.stageFit);
                                if (grip.modelData === "l") zoneRow.b.setOffset(chip.modelData, "l", grip.start - d);
                                else zoneRow.b.setOffset(chip.modelData, chip.gap ? "w" : "r", grip.start + d);
                            }
                        }
                    }
                }
            }
        }
    }

    // inspector for the selected module
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: inspector.implicitHeight + 24
        radius: Tokens.radius
        color: Tokens.card
        border.width: 1; border.color: builder.selectedKey ? Tokens.alpha(Tokens.accent, .35) : Tokens.alpha(Tokens.text, .05)
        Behavior on border.color { ColorAnimation { duration: 150 } }
        ColumnLayout {
            id: inspector
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 10
                    color: Tokens.alpha(Tokens.accent, builder.selectedKey ? .18 : .08)
                    Text {
                        anchors.centerIn: parent
                        text: builder.selectedKey ? builder.render(builder.selectedKey).slice(0, 2) : Tokens.glyph(0xF01BE)
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16; color: Tokens.accent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: builder.selectedKey ? builder.nameOf(builder.selectedKey) : "Модуль не выбран"; font.family: Tokens.font; font.pixelSize: Tokens.px(14); font.weight: Font.Medium; color: Tokens.text }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: builder.selectedKey
                            ? builder.selectedKey + " · " + ({ left: "слева", center: "в центре", right: "справа" })[builder.selected.zone] + ", позиция " + (builder.selected.index + 1)
                            : "Клик: выбрать · ← →: переставить · края ┃: раздвинуть · Delete: убрать · Ctrl+Z: отменить. Распорка и новые модули лежат в лотке ниже."
                        font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3
                    }
                }
                StyledButton { visible: !!builder.selectedKey; flat: true; implicitWidth: 34; text: "←"; onClicked: builder.nudge(-1) }
                StyledButton { visible: !!builder.selectedKey; flat: true; implicitWidth: 34; text: "→"; onClicked: builder.nudge(1) }
                StyledButton { visible: !!builder.selectedKey && (builder.offsetOf(builder.selectedKey).l + builder.offsetOf(builder.selectedKey).r) > 0; flat: true; text: "Без отступов"; onClicked: builder.clearOffsets(builder.selectedKey) }
                StyledButton { visible: !!builder.selectedKey && !builder.isGap(builder.selectedKey); text: "Все параметры"; onClicked: { builder.page.module = builder.selectedKey; builder.page.tab = 4; } }
                StyledButton { visible: !!builder.selectedKey; text: "Убрать"; onClicked: builder.removeItem(builder.selected.zone, builder.selected.index) }
                StyledButton { visible: builder.history.length > 0; flat: true; text: "Отменить"; onClicked: builder.undo() }
            }
            // free placement
            RowLayout {
                visible: !!builder.selectedKey
                Layout.fillWidth: true
                spacing: 18
                readonly property var o: builder.offsetOf(builder.selectedKey)
                ColumnLayout {
                    spacing: 2
                    Text { text: "Отступ слева"; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
                    ValueSlider { sliderWidth: 130; from: 0; to: 400; unit: " px"; defaultValue: 0; value: parent.parent.o.l; onEdited: v => builder.setOffset(builder.selectedKey, "l", v) }
                }
                ColumnLayout {
                    spacing: 2
                    Text { text: builder.isGap(builder.selectedKey) ? "Ширина распорки" : "Отступ справа"; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
                    ValueSlider {
                        sliderWidth: 130; from: builder.isGap(builder.selectedKey) ? 4 : 0; to: 400; unit: " px"
                        defaultValue: builder.isGap(builder.selectedKey) ? 40 : 0
                        value: builder.isGap(builder.selectedKey) ? parent.parent.o.w : parent.parent.o.r
                        onEdited: v => builder.setOffset(builder.selectedKey, builder.isGap(builder.selectedKey) ? "w" : "r", v)
                    }
                }
                Item { Layout.fillWidth: true }
            }
            // quick fields for the common keys
            GridLayout {
                visible: !!builder.selectedKey && builder.selectedKey.indexOf("group/") !== 0 && !builder.isGap(builder.selectedKey)
                Layout.fillWidth: true
                columns: 2; columnSpacing: 10; rowSpacing: 8
                Repeater {
                    model: [["format", "Формат"], ["on-click", "Клик"], ["tooltip-format", "Подсказка"], ["on-click-right", "Правый клик"]]
                    ColumnLayout {
                        id: quick
                        required property var modelData
                        readonly property var value: (builder.config[builder.selectedKey] || {})[modelData[0]]
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: quick.modelData[1]; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
                        StyledTextField {
                            Layout.fillWidth: true
                            font.family: "JetBrainsMono Nerd Font"
                            text: typeof quick.value === "string" ? quick.value : ""
                            placeholderText: quick.value === undefined ? "не задано" : ""
                            onEditingFinished: {
                                var key = builder.selectedKey; if (!key) return;
                                var m = Object.assign({}, builder.config[key] || {});
                                if (text === (m[quick.modelData[0]] || "")) return;
                                if (text) m[quick.modelData[0]] = text; else delete m[quick.modelData[0]];
                                builder.page.setConfig(key, m);
                            }
                        }
                    }
                }
            }
        }
    }

    // tray of modules not on the bar
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; Layout.leftMargin: 4; text: "Модули"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
        StyledTextField { Layout.preferredWidth: 180; placeholderText: "Найти модуль"; onTextChanged: builder.trayFilter = text.trim().toLowerCase() }
    }
    Flow {
        id: tray
        Layout.fillWidth: true
        spacing: 8
        readonly property var onBar: builder.zones.left.concat(builder.zones.center, builder.zones.right)
        readonly property var items: {
            var seen = {}, out = [];
            Object.keys(builder.config).forEach(k => {
                var v = builder.config[k];
                if (v && typeof v === "object" && !Array.isArray(v) && k !== "output" && k.indexOf("group/rice-preset-") !== 0 && !builder.isGap(k) && onBar.indexOf(k) < 0) { seen[k] = true; out.push({ key: k, settings: null }); }
            });
            Logic.extensions.forEach(e => { if (!seen[e.id] && onBar.indexOf(e.id) < 0) out.push({ key: e.id, settings: e.settings, description: e.description }); });
            return out.filter(i => !builder.trayFilter || (i.key + " " + builder.nameOf(i.key)).toLowerCase().includes(builder.trayFilter));
        }
        // spacer: always available, any number of times
        Rectangle {
            width: gapRow.implicitWidth + 22; height: 34; radius: 10
            color: gapMouse.containsMouse ? Tokens.alpha(Tokens.accent, .16) : Tokens.alpha(Tokens.accent, .08)
            border.width: 1; border.color: Tokens.alpha(Tokens.accent, gapMouse.containsMouse ? .6 : .35)
            scale: gapMouse.pressed ? .96 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Row {
                id: gapRow; anchors.centerIn: parent; spacing: 8
                Text { text: "⟷"; font.pixelSize: 15; color: Tokens.accent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Распорка"; font.family: Tokens.font; font.pixelSize: 12; font.weight: Font.Medium; color: Tokens.text; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                id: gapMouse
                anchors.fill: parent; hoverEnabled: true; preventStealing: true; cursorShape: Qt.OpenHandCursor
                property point origin
                onPressed: mouse => origin = Qt.point(mouse.x, mouse.y)
                onPositionChanged: mouse => {
                    if (!pressed) return;
                    if (!builder.drag && Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 6)
                        builder.startDrag({ key: builder.newGapKey(), fromTray: true, settings: builder.gapSettings }, gapMouse, mouse.x, mouse.y);
                    else if (builder.drag) builder.moveDrag(gapMouse, mouse.x, mouse.y);
                }
                onReleased: if (builder.drag) builder.endDrag()
                onDoubleClicked: builder.insertItem(builder.newGapKey(), "right", 0, builder.gapSettings)
            }
        }
        Repeater {
            model: tray.items
            Rectangle {
                id: trayChip
                required property var modelData
                width: row.implicitWidth + 22; height: 34; radius: 10
                color: trayMouse.containsMouse ? Tokens.cardStrong : Tokens.card
                border.width: 1; border.color: trayMouse.containsMouse ? Tokens.alpha(Tokens.accent, .45) : Tokens.line
                scale: trayMouse.pressed ? .96 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Row {
                    id: row
                    anchors.centerIn: parent; spacing: 8
                    Text { readonly property var ext: Logic.extensions.find(e => e.id === trayChip.modelData.key); text: ext ? ext.icon : builder.render(trayChip.modelData.key); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Tokens.accent; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, 90); elide: Text.ElideRight }
                    Text { text: builder.nameOf(trayChip.modelData.key); font.family: Tokens.font; font.pixelSize: 12; color: Tokens.text; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true; preventStealing: true
                    cursorShape: Qt.OpenHandCursor
                    property point origin
                    onPressed: mouse => origin = Qt.point(mouse.x, mouse.y)
                    onPositionChanged: mouse => {
                        if (!pressed) return;
                        if (!builder.drag && Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y) > 6)
                            builder.startDrag({ key: trayChip.modelData.key, fromTray: true, settings: trayChip.modelData.settings }, trayMouse, mouse.x, mouse.y);
                        else if (builder.drag) builder.moveDrag(trayMouse, mouse.x, mouse.y);
                    }
                    onReleased: if (builder.drag) builder.endDrag()
                    onDoubleClicked: builder.insertItem(trayChip.modelData.key, "right", 0, trayChip.modelData.settings)
                    ToolTip.visible: containsMouse && !builder.drag
                    ToolTip.delay: 500
                    ToolTip.text: (trayChip.modelData.description || trayChip.modelData.key)
                }
            }
        }
        Text { visible: tray.items.length === 0; text: "Все модули уже на панели"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text3 }
    }
}
