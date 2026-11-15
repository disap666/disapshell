pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Live cheat sheet built from `hyprctl binds -j`.
ColumnLayout {
    id: page
    readonly property bool busy: reader.running
    readonly property bool dirty: false
    property bool loaded: false
    property string status: ""
    property string filter: ""
    property var sections: []
    spacing: 14

    readonly property var mods: [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]]
    readonly property var scripts: ({
        "rice-settings": "Настройки райса", "rice-apps": "Поиск приложений", "rice-power": "Меню питания",
        "rice-lock": "Заблокировать экран", "rice-notifications": "Центр уведомлений", "dolphin-glass": "Файлы",
        "wallpaper-picker": "Галерея обоев", "rice-music": "Музыкальный виджет", "connectivity-widget": "Bluetooth", "rice-themes": "Карусель тем", "rice-gamemode": "Игровой режим"
    })

    function keyName(b) {
        var k = b.key;
        if (!k && b.keycode) {
            if (b.keycode >= 10 && b.keycode <= 18) k = String(b.keycode - 9);
            else if (b.keycode === 19) k = "0";
            else k = ({31: "I", 55: "V", 49: "`"})[b.keycode] || ("код " + b.keycode);
        }
        return ({
            "mouse:272": "ЛКМ", "mouse:273": "ПКМ", "Return": "Enter", "SPACE": "Пробел", "Print": "PrtSc",
            "left": "←", "right": "→", "up": "↑", "down": "↓", "Tab": "Tab", "Escape": "Esc",
            "XF86AudioRaiseVolume": "Громкость +", "XF86AudioLowerVolume": "Громкость −", "XF86AudioMute": "Без звука",
            "XF86AudioPlay": "Play", "XF86AudioNext": "Next", "XF86AudioPrev": "Prev",
            "XF86MonBrightnessUp": "Яркость +", "XF86MonBrightnessDown": "Яркость −"
        })[k] || k;
    }
    function combo(b) {
        var parts = mods.filter(m => b.modmask & m[0]).map(m => m[1]);
        parts.push(keyName(b));
        return parts;
    }
    function describe(b) {
        var d = b.dispatcher, a = (b.arg || "").trim();
        if (b.description) return [b.description, "Другое"];
        if (d === "exec") {
            if (b.modmask & 1 && a.indexOf("--toggle") >= 0) return ["Показать или скрыть музыкальный виджет", "Приложения и меню"];
            if (a.indexOf("--dnd") >= 0) return ["Не беспокоить", "Приложения и меню"];
            if (a.indexOf("--random") >= 0) return ["Случайные обои", "Приложения и меню"];
            for (var s in scripts) if (a.indexOf(s) >= 0) return [scripts[s], "Приложения и меню"];
            if (a === "kitty" || a.indexOf("$terminal") >= 0) return ["Терминал", "Приложения и меню"];
            if (a.indexOf("slurp") >= 0) return ["Скриншот области в буфер", "Экран"];
            if (a.indexOf("grim") >= 0) return ["Скриншот экрана в буфер", "Экран"];
            if (a.indexOf("SIGUSR1") >= 0 && a.indexOf("waybar") >= 0) return ["Показать или скрыть Waybar", "Экран"];
            if (a.indexOf("set-volume") >= 0) return [a.indexOf("+") >= 0 ? "Громче" : "Тише", "Звук и медиа"];
            if (a.indexOf("set-mute") >= 0) return ["Выключить звук", "Звук и медиа"];
            if (a.indexOf("playerctl") >= 0) return [({ "play-pause": "Пауза / воспроизведение", "next": "Следующий трек", "previous": "Предыдущий трек" })[a.split(" ").pop()] || a, "Звук и медиа"];
            if (a.indexOf("brightnessctl") >= 0) return [a.indexOf("+") >= 0 ? "Ярче" : "Темнее", "Экран"];
            return [a.replace(Quickshell.env("HOME"), "~"), "Другое"];
        }
        var map = {
            "killactive": ["Закрыть окно", "Окна"], "togglefloating": ["Плавающее окно", "Окна"],
            "fullscreen": [a === "1" ? "Развернуть окно" : "Полный экран", "Окна"],
            "exit": ["Выйти из Hyprland", "Окна"], "movewindow": [a ? "Переместить окно " + ({ l: "влево", r: "вправо", u: "вверх", d: "вниз" })[a] : "Перетаскивать окно", "Окна"],
            "resizewindow": ["Менять размер окна", "Окна"], "movefocus": ["Фокус " + ({ l: "влево", r: "вправо", u: "вверх", d: "вниз" })[a], "Окна"],
            "cyclenext": [a === "prev" ? "Предыдущее окно" : "Следующее окно", "Окна"], "bringactivetotop": ["", "Окна"],
            "workspace": ["Рабочий стол " + a, "Рабочие столы"], "movetoworkspace": ["Окно на рабочий стол " + a, "Рабочие столы"],
            "togglespecialworkspace": ["Скрытый рабочий стол", "Рабочие столы"],
            "spatialoverview:overview": ["Холст со всеми окнами", "Рабочие столы"]
        };
        return map[d] || [d + (a ? " " + a : ""), "Другое"];
    }
    function build(list) {
        var order = ["Приложения и меню", "Окна", "Рабочие столы", "Экран", "Звук и медиа", "Другое"];
        var groups = {}, seen = {};
        order.forEach(g => groups[g] = []);
        list.filter(b => !b.submap).forEach(b => {
            var info = describe(b);
            if (!info[0]) return;
            var keys = combo(b), id = keys.join("+") + info[0];
            if (seen[id]) return;
            seen[id] = true;
            // fold Super+1...9 style rows
            var num = /^\d$/.test(keys[keys.length - 1]) && (b.dispatcher === "workspace" || b.dispatcher === "movetoworkspace");
            if (num) {
                var label = b.dispatcher === "workspace" ? "Рабочий стол 1–9" : "Окно на рабочий стол 1–9";
                var foldId = label;
                if (seen[foldId]) return;
                seen[foldId] = true;
                keys = keys.slice(0, -1).concat(["1…9"]);
                info = [label, info[1]];
            }
            var existing = groups[info[1]].find(r => r.text === info[0]);
            if (existing) existing.combos.push(keys);
            else groups[info[1]].push({ text: info[0], combos: [keys] });
        });
        // flatten combos into key caps with "или" between alternatives
        order.forEach(g => groups[g].forEach(r => {
            r.keys = [];
            r.combos.forEach((c, i) => { if (i) r.keys.push("|"); r.keys = r.keys.concat(c); });
        }));
        sections = order.filter(g => groups[g].length).map(g => ({ title: g, rows: groups[g] }));
        loaded = true;
    }
    function read() { if (!reader.running) reader.running = true; }
    function matches(row) { return !filter || row.text.toLowerCase().includes(filter) || row.keys.join(" ").toLowerCase().includes(filter); }
    onVisibleChanged: if (visible) read()
    Component.onCompleted: read()
    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { page.build(JSON.parse(text)); page.status = ""; } catch (e) { page.status = "Не удалось прочитать бинды: " + e; } } }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledTextField { Layout.fillWidth: true; placeholderText: "Найти действие или клавишу"; onTextChanged: page.filter = text.trim().toLowerCase() }
        StyledButton { text: "Открыть конфиг"; onClicked: Quickshell.execDetached(["kitty", "-e", "nvim", Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"]) }
    }
    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentHeight: body.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            width: parent.width - 12; spacing: 18
            Repeater {
                model: page.sections
                Group {
                    id: section
                    required property var modelData
                    title: modelData.title
                    visible: modelData.rows.some(r => page.matches(r))
                    Repeater {
                        model: section.modelData.rows
                        SettingRow {
                            id: row
                            required property var modelData
                            visible: page.matches(modelData)
                            label: modelData.text
                            Repeater {
                                model: row.modelData.keys
                                Rectangle {
                                    required property string modelData
                                    readonly property bool sep: modelData === "|"
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    width: sep ? cap.implicitWidth + 6 : Math.max(26, cap.implicitWidth + 14); height: 24; radius: 6
                                    color: sep ? "transparent" : Tokens.cardStrong
                                    border.width: sep ? 0 : 1; border.color: Tokens.line
                                    Rectangle { visible: !parent.sep; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 1; height: 2; radius: 1; color: "#26000000" }
                                    Text { id: cap; anchors.centerIn: parent; anchors.verticalCenterOffset: parent.sep ? 0 : -1; text: parent.sep ? "или" : modelData; font.family: Tokens.font; font.pixelSize: Tokens.px(11); font.weight: parent.sep ? Font.Normal : Font.Medium; color: parent.sep ? Tokens.text3 : Tokens.text }
                                }
                            }
                        }
                    }
                }
            }
            Text {
                visible: page.loaded && !page.sections.some(s => s.rows.some(r => page.matches(r)))
                Layout.fillWidth: true; Layout.topMargin: 30; horizontalAlignment: Text.AlignHCenter
                text: "Ничего не найдено"; font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: Tokens.text3
            }
        }
    }
    ApplyBar { showApply: false; error: page.status }
}
