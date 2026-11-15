pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Wallpaper grid backed by ~/.local/share/wallpaper-picker/backend.py (--list / --set / --random).
ColumnLayout {
    id: page
    required property var store            // shell-level wallpaper model (items, current, refresh())
    readonly property bool busy: setter.running
    readonly property bool dirty: false
    readonly property bool loaded: store.loaded
    property string status: ""
    property string filter: ""
    readonly property var items: store.items.filter(i => !filter || i.name.toLowerCase().includes(filter))
    readonly property var currentItem: store.items.find(i => i.path === store.current) || null
    spacing: 14

    // ~/.config/rice-theme/wallpaper.json, read by backend.py and RiceDesktop
    property int tab: 0
    property var prefs: ({})
    readonly property var opt: Object.assign({ transition: "fade", duration: 0.7, resize: "crop", interval: 0 }, prefs)
    readonly property var transitions: [["fade", "Затухание"], ["simple", "Простой"], ["wipe", "Шторка"], ["wave", "Волна"], ["grow", "Круг из точки"],
        ["center", "Круг из центра"], ["outer", "Круг к центру"], ["left", "Слева"], ["right", "Справа"], ["top", "Сверху"], ["bottom", "Снизу"],
        ["random", "Случайный"], ["none", "Без перехода"]]
    readonly property var resizes: [["crop", "Заполнить"], ["fit", "Вписать"], ["stretch", "Растянуть"], ["no", "Как есть"]]
    readonly property var intervals: [[0, "Выкл"], [5, "5 мин"], [15, "15 мин"], [30, "30 мин"], [60, "1 ч"], [180, "3 ч"]]
    FileView {
        id: prefsFile
        path: Quickshell.env("HOME") + "/.config/rice-theme/wallpaper.json"
        watchChanges: true; preload: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.prefs = JSON.parse(text()); } catch (e) { page.prefs = {}; } }
    }
    function setPref(key, value, reapply) {
        var next = Object.assign({}, prefs);
        next[key] = value;
        prefs = next;
        prefsFile.setText(JSON.stringify(next, null, 2) + "\n");
        if (reapply && store.current && !setter.running) {
            setter.command = ["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--restore"];
            setter.running = true;
        }
    }

    function choose(path) {
        if (setter.running || path === store.current) return;
        setter.command = ["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--set", path];
        setter.running = true;
    }
    function random() {
        if (setter.running) return;
        setter.command = ["python3", Quickshell.env("HOME") + "/.local/share/wallpaper-picker/backend.py", "--random"];
        setter.running = true;
    }
    Process {
        id: setter
        stderr: StdioCollector { id: setterErr }
        onExited: (code) => { page.status = code === 0 ? "" : "Не удалось сменить обои: " + setterErr.text.trim(); page.store.refresh(); }
    }

    // Current wallpaper, large.
    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(230, width * 9 / 16 * .55)
        radius: Tokens.radius
        color: Tokens.well
        AnimatedImage {
            anchors.fill: parent
            fillMode: page.opt.resize === "fit" ? Image.PreserveAspectFit : page.opt.resize === "stretch" ? Image.Stretch : page.opt.resize === "no" ? Image.Pad : Image.PreserveAspectCrop
            asynchronous: true; cache: false
            source: page.store.current ? "file://" + page.store.current : ""
            playing: page.visible
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 64
            gradient: Gradient { GradientStop { position: 0; color: "#00000000" } GradientStop { position: 1; color: "#a0000000" } }
        }
        RowLayout {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 14
            ColumnLayout {
                spacing: 1
                Text { text: page.currentItem ? page.currentItem.name : "Обои не выбраны"; font.family: Tokens.font; font.pixelSize: Tokens.px(14); font.weight: Font.Medium; color: "#ffffff" }
                Text { text: page.store.items.length + " в ~/wallpapers" + (page.currentItem && page.currentItem.gif ? " · анимированные" : ""); font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: "#d0ffffff" }
            }
            Item { Layout.fillWidth: true }
            StyledButton { text: "Случайные"; enabled: !page.busy && page.store.items.length > 1; onClicked: page.random() }
            StyledButton { text: "Открыть папку"; onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/dolphin-glass", page.store.root || (Quickshell.env("HOME") + "/wallpapers")]) }
        }
    }

    Segmented { model: ["Коллекция", "Настройки"]; current: page.tab; onActivated: index => page.tab = index }

    ColumnLayout {
        visible: page.tab === 1
        Layout.fillWidth: true; Layout.fillHeight: true
        spacing: 14
        Group {
            title: "Смена обоев"
            SettingRow {
                label: "Переход"
                StyledComboBox {
                    width: 220
                    model: page.transitions.map(t => t[1])
                    currentIndex: Math.max(0, page.transitions.findIndex(t => t[0] === page.opt.transition))
                    onActivated: page.setPref("transition", page.transitions[currentIndex][0], false)
                }
            }
            SettingRow {
                label: "Длительность перехода"
                ValueSlider {
                    enabled: page.opt.transition !== "none"
                    from: 0.1; to: 3; step: 0.1; decimals: 1; unit: " с"; defaultValue: 0.7
                    value: page.opt.duration
                    onEdited: value => page.setPref("duration", value, false)
                }
            }
            SettingRow {
                label: "Менять автоматически"
                Segmented {
                    model: page.intervals.map(i => i[1])
                    current: Math.max(0, page.intervals.findIndex(i => i[0] === page.opt.interval))
                    onActivated: index => page.setPref("interval", page.intervals[index][0], false)
                }
            }
        }
        Group {
            title: "Изображение"
            SettingRow {
                label: "Размер"
                Segmented {
                    model: page.resizes.map(r => r[1])
                    current: Math.max(0, page.resizes.findIndex(r => r[0] === page.opt.resize))
                    onActivated: index => page.setPref("resize", page.resizes[index][0], true)
                }
            }
        }
        Item { Layout.fillHeight: true }
    }

    RowLayout {
        visible: page.tab === 0
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: "Коллекция"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2; Layout.leftMargin: 4 }
        StyledTextField { visible: page.store.items.length > 8; Layout.preferredWidth: 180; placeholderText: "Найти по имени"; onTextChanged: page.filter = text.trim().toLowerCase() }
        StyledButton { text: "Обновить"; flat: true; onClicked: page.store.refresh() }
    }

    GridView {
        id: grid
        visible: page.tab === 0
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; boundsBehavior: Flickable.StopAtBounds
        readonly property int columns: Math.max(2, Math.floor(width / 190))
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.round(cellWidth * 9 / 16) + 12
        model: page.items
        ScrollBar.vertical: ScrollBar {}
        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool current: modelData.path === page.store.current
            width: grid.cellWidth; height: grid.cellHeight
            ClippingRectangle {
                id: tile
                anchors.fill: parent; anchors.margins: 6
                radius: 10
                color: Tokens.well
                scale: area.pressed ? .97 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Image {
                    anchors.fill: parent
                    source: cell.modelData.thumb ? "file://" + cell.modelData.thumb : ""
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                    sourceSize.width: 400
                }
                Rectangle { anchors.fill: parent; color: "#000000"; opacity: area.containsMouse && !cell.current ? .12 : 0 }
                Rectangle {
                    visible: cell.modelData.gif
                    x: 8; y: 8; width: gifLabel.implicitWidth + 10; height: 18; radius: 5; color: "#99000000"
                    Text { id: gifLabel; anchors.centerIn: parent; text: "GIF"; font.family: Tokens.font; font.pixelSize: 9; font.weight: Font.DemiBold; color: "#ffffff" }
                }
                Rectangle {
                    visible: cell.current
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                    width: 22; height: 22; radius: 11; color: Tokens.accent
                    Text { anchors.centerIn: parent; text: Tokens.glyph(0xF012C); font.family: Tokens.iconFont; font.pixelSize: 14; color: Tokens.onAccent }
                }
            }
            Rectangle {
                anchors.fill: tile; anchors.margins: -3; radius: 13
                color: "transparent"
                border.width: 2; border.color: cell.current ? Tokens.accent : area.containsMouse ? Tokens.alpha(Tokens.text, .25) : "transparent"
            }
            MouseArea {
                id: area
                anchors.fill: tile; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: page.choose(cell.modelData.path)
                ToolTip.visible: containsMouse; ToolTip.delay: 600; ToolTip.text: cell.modelData.name
            }
        }
        Text {
            anchors.centerIn: parent
            visible: page.store.loaded && page.items.length === 0
            text: page.store.items.length ? "Ничего не найдено" : "Положи картинки или GIF в ~/wallpapers"
            font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: Tokens.text3
        }
    }

    ApplyBar {
        status: page.busy ? "Меняю обои…" : ""
        error: page.status
        busy: page.busy
        dirty: false
        showApply: false
    }
}
