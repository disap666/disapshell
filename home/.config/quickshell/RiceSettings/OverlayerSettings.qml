pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "file:@HOME@/.config/quickshell/RiceTheme" as Rice

ColumnLayout {
    id: page
    spacing: 12
    property int overviewTab: 0
    readonly property bool dirty: globalPage.dirty
    readonly property bool busy: worker.running || globalPage.busy
    property var presets: []
    property string selected: "lavender"
    property string active: ""
    property bool canRestore: false
    property bool autoTheme: false
    property bool waybarDirty: false
    property string wallpaper: ""
    property string status: "Загрузка заготовок…"
    readonly property string backend: Quickshell.env("HOME") + "/.local/share/rice-settings/presets.py"
    signal applied()
    component Action: StyledButton {}
    function run(action, id) {
        if (worker.running) return;
        worker.command = ["python3", backend, action];
        if (id) worker.command = ["python3", backend, action, id];
        worker.running = true;
    }
    Component.onCompleted: run("list", "")
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    if (data.error) { page.status = data.error; return; }
                    page.active = data.active || "";
                    page.canRestore = data.canRestore;
                    if (data.autoTheme !== undefined) page.autoTheme = data.autoTheme;
                    if (data.presets) {
                        page.presets = data.presets;
                        page.selected = page.active || "lavender";
                        page.status = "";
                    } else { page.status = data.message; page.applied(); }
                } catch (e) { page.status = "Ошибка: " + e; }
            }
        }
    }
    Segmented { model: ["Палитры", "Шрифт и стекло"]; current: page.overviewTab; onActivated: index => page.overviewTab = index }
    GlobalSettings { id: globalPage; visible: page.overviewTab === 1; Layout.fillWidth: true; Layout.fillHeight: true }
    ColumnLayout {
        visible: page.overviewTab === 0
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 12
    // Colours from the wallpaper
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 72
        radius: Tokens.radius + 2
        color: page.active === "wallpaper" ? Tokens.alpha(Tokens.accent, .10) : Tokens.card
        border.width: 1
        border.color: page.active === "wallpaper" ? Tokens.alpha(Tokens.accent, .45) : Tokens.line
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 14
            spacing: 14
            ClippingRectangle {
                Layout.preferredWidth: 84; Layout.preferredHeight: 48
                radius: 8; color: Tokens.well
                Image { anchors.fill: parent; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 200 }
                Row {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 4
                    spacing: 3
                    visible: page.active === "wallpaper" && !!Rice.Theme.palette.colors
                    Repeater {
                        model: ["background", "surface", "accent", "foreground"]
                        Rectangle { required property string modelData; width: 10; height: 10; radius: 5; color: (Rice.Theme.palette.colors || {})[modelData] || "transparent"; border.width: 1; border.color: "#60000000" }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { text: "Цвета из обоев"; font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.DemiBold; color: Tokens.text }
            }
            StyledButton {
                text: "Взять сейчас"
                enabled: !worker.running && !page.waybarDirty
                onClicked: page.run("wallpaper", "")
            }
            StyledCheckBox {
                checked: page.autoTheme
                enabled: !worker.running && !page.waybarDirty
                onToggled: page.run("autotheme", checked ? "on" : "off")
            }
        }
    }
    Flickable {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true
        contentHeight: grid.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        GridLayout {
            id: grid
            width: scroll.width - 12; columns: 2; rowSpacing: 12; columnSpacing: 12
            Repeater {
                model: page.presets
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property var colors: modelData.colors
                    Layout.fillWidth: true; Layout.preferredHeight: 262
                    Layout.minimumWidth: 0
                    radius: Tokens.radius + 2
                    color: hoverCard.containsMouse ? Tokens.cardStrong : Tokens.card
                    border.width: page.selected === modelData.id ? 2 : 1
                    border.color: page.selected === modelData.id ? colors.accent : Tokens.line
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 7
                        ClippingRectangle {
                            id: preview
                            readonly property bool glassy: card.modelData.layout.opacity < 60
                            Layout.fillWidth: true; Layout.preferredHeight: 102
                            radius: 9; color: card.colors.background
                            border.width: 1; border.color: card.colors.surface
                            Image { anchors.fill: parent; visible: preview.glassy && page.wallpaper.length > 0; source: page.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 420 }
                            Rectangle { anchors.fill: parent; visible: preview.glassy; color: card.colors.background; opacity: .35 }
                            Row {
                                id: miniatureBar
                                x: card.modelData.layout.margin === 0 ? 1 : 8; y: card.modelData.layout.margin === 0 ? 1 : 7
                                width: preview.width - x * 2; height: 14
                                spacing: card.modelData.layout.parts > 1 ? 5 : 0
                                Repeater {
                                    model: card.modelData.layout.parts
                                    Rectangle {
                                        required property int index
                                        width: (miniatureBar.width - miniatureBar.spacing * (card.modelData.layout.parts - 1)) / card.modelData.layout.parts
                                        height: 14; radius: card.modelData.layout.radius === 0 ? 0 : card.modelData.layout.radius > 15 ? 7 : 3
                                        color: Qt.alpha(card.colors.surface, preview.glassy ? .45 : 1)
                                        Text { font.family: Rice.Theme.fontFamily; anchors.centerIn: parent; text: index === 0 ? "● ● ●" : index === card.modelData.layout.parts - 1 ? "⌁ ▰" : "12:30"; color: card.colors.foreground; font.pixelSize: (7 * Rice.Theme.textScale) }
                                    }
                                }
                            }
                            Rectangle {
                                x: 9; y: 31; width: parent.width * .44; height: 43; radius: 4
                                color: Qt.alpha(card.modelData.kitty.background, preview.glassy ? .55 : 1)
                                border.width: 1; border.color: card.colors.border
                                Text { x: 7; y: 6; text: "kitty  ❯ ls\nsrc/   README.md"; color: card.modelData.kitty.foreground; font.family: "monospace"; font.pixelSize: 7 }
                                Rectangle { x: 7; y: 31; width: card.modelData.kitty.cursor_shape === "block" ? 5 : 1; height: 6; color: card.modelData.kitty.cursor }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.rightMargin: 9; y: 28
                                width: parent.width * .42; height: 48; radius: 5; color: card.colors.surface
                                Column {
                                    x: 7; y: 7; spacing: 7
                                    Rectangle { width: 45; height: 3; color: card.colors.accent }
                                    Rectangle { width: 55; height: 3; color: card.colors.muted }
                                    Text { font.family: Rice.Theme.fontFamily; text: "Уведомления"; color: card.colors.foreground; font.pixelSize: (6 * Rice.Theme.textScale) }
                                }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 84; spacing: card.modelData.deck.parts > 1 ? 4 : 0
                                Repeater {
                                    model: card.modelData.deck.parts
                                    Rectangle {
                                        width: 100 / card.modelData.deck.parts; height: 13
                                        radius: card.modelData.deck.radius === 0 ? 0 : 4
                                        color: card.colors.surface; border.width: 1; border.color: card.colors.border
                                        Row {
                                            anchors.centerIn: parent; spacing: 3
                                            Repeater { model: Math.max(1, Math.floor(8 / card.modelData.deck.parts)); Rectangle { width: 5; height: 6; radius: card.modelData.deck.radius === 0 ? 0 : 2; color: card.colors.accent } }
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { font.family: Rice.Theme.fontFamily; Layout.fillWidth: true; text: card.modelData.name; color: Tokens.text; font.pixelSize: (13 * Rice.Theme.textScale); font.bold: true; elide: Text.ElideRight }
                            Text { font.family: Rice.Theme.fontFamily; text: page.active === card.modelData.id ? "сейчас" : page.selected === card.modelData.id ? "выбрана" : ""; color: card.colors.accent; font.pixelSize: Tokens.px(11) }
                        }
                        Row {
                            spacing: 5
                            Repeater {
                                model: [card.colors.background, card.colors.surface, card.colors.muted, card.colors.foreground, card.colors.accent, card.colors.border]
                                Rectangle { required property string modelData; width: 17; height: 17; radius: 8; color: modelData; border.width: 1; border.color: Rice.Theme.color("#40ffffff") }
                            }
                        }
                    }
                    MouseArea { id: hoverCard; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !worker.running; onClicked: page.selected = card.modelData.id; onDoubleClicked: if (!page.waybarDirty) page.run("apply", card.modelData.id) }
                }
            }
        }
    }
    ApplyBar {
        readonly property var chosen: page.presets.find(p => p.id === page.selected)
        dirty: page.selected !== page.active && page.presets.length > 0
        busy: worker.running
        valid: !page.waybarDirty
        canRestore: page.canRestore
        status: page.status
        error: page.waybarDirty ? "Сначала примени или сбрось изменения в Waybar, доке и терминале" : ""
        applyText: chosen ? "Применить «" + chosen.name + "»" : "Применить"
        revertText: "Оставить текущую"
        restoreText: "Вернуть предыдущую"
        onApply: page.run("apply", page.selected)
        onRevert: page.selected = page.active
        onRestore: page.run("restore", "")
    }
    }
}
