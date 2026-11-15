pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Snapshots of the whole rice (backups.py): create, restore, delete, tidy leftovers.
ColumnLayout {
    id: page
    readonly property bool busy: worker.running
    readonly property bool dirty: false
    property bool loaded: false
    property string status: ""
    property var items: []
    property int leftovers: 0
    property string confirm: ""        // name of the backup waiting for a second click
    property string confirmAction: ""
    readonly property string backend: Quickshell.env("HOME") + "/.local/share/rice-settings/backups.py"
    spacing: 14

    function run(args) {
        if (worker.running) return;
        confirm = ""; confirmAction = "";
        worker.command = ["python3", backend].concat(args);
        worker.running = true;
    }
    function refresh() { run(["list"]); }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()

    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    if (d.error) { page.status = d.error; return; }
                    if (d.items) page.items = d.items;
                    if (d.message) page.status = d.message;
                    page.loaded = true;
                } catch (e) { page.status = "Ошибка: " + e; }
                counter.running = true;
            }
        }
    }
    Process {
        id: counter
        command: ["python3", page.backend, "leftovers"]
        stdout: StdioCollector { onStreamFinished: { try { page.leftovers = JSON.parse(text).count || 0; } catch (e) {} } }
    }

    function when(iso) {
        var d = new Date(iso);
        var today = new Date(); today.setHours(0, 0, 0, 0);
        var day = new Date(d); day.setHours(0, 0, 0, 0);
        var diff = Math.round((today - day) / 86400000);
        var t = Qt.formatTime(d, "HH:mm");
        if (diff === 0) return "Сегодня, " + t;
        if (diff === 1) return "Вчера, " + t;
        return d.toLocaleDateString(Qt.locale("ru_RU"), "d MMMM yyyy") + ", " + t;
    }
    function size(b) { return b > 1048576 ? (b / 1048576).toFixed(1) + " МБ" : Math.max(1, Math.round(b / 1024)) + " КБ"; }

    // New backup
    Group {
        title: "Новая копия"
        SettingRow {
            label: "Название"
            StyledTextField {
                id: labelField
                width: 240
                placeholderText: "Без названия"
                onAccepted: create.clicked()
            }
            StyledButton {
                id: create
                primary: true
                text: "Сделать копию"
                enabled: !page.busy
                onClicked: { page.run(["create", labelField.text]); labelField.text = ""; }
            }
        }
        SettingRow {
            visible: page.leftovers > 0
            label: "Старые .before-файлы: " + page.leftovers
            StyledButton {
                text: page.confirmAction === "tidy" ? "Подтвердить" : "Убрать"
                enabled: !page.busy
                onClicked: {
                    if (page.confirmAction === "tidy") page.run(["tidy"]);
                    else { page.confirmAction = "tidy"; page.confirm = ""; }
                }
            }
        }
    }

    // List
    RowLayout {
        Layout.fillWidth: true
        Text { text: "Копии"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
        Text { text: page.items.length ? "· " + page.items.length : ""; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text3 }
        Item { Layout.fillWidth: true }
        Text { text: page.status; elide: Text.ElideRight; Layout.maximumWidth: 420; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
    }

    Flickable {
        id: scroll
        Layout.fillWidth: true; Layout.fillHeight: true
        contentHeight: list.implicitHeight
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: list
            width: scroll.width - 12
            spacing: 8

            Text {
                visible: page.loaded && page.items.length === 0
                Layout.fillWidth: true; Layout.topMargin: 24
                horizontalAlignment: Text.AlignHCenter
                text: "Копий пока нет"
                font.family: Tokens.font; font.pixelSize: Tokens.px(13); color: Tokens.text3
            }

            Repeater {
                model: page.items
                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool auto: modelData.kind === "auto"
                    readonly property bool asking: page.confirm === modelData.name
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Tokens.radius
                    color: hover.hovered ? Tokens.cardStrong : Tokens.card
                    border.width: 1
                    border.color: row.asking ? Tokens.alpha(page.confirmAction === "delete" ? Tokens.danger : Tokens.accent, .6) : Tokens.alpha(Tokens.text, .05)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    HoverHandler { id: hover }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 10
                            color: Tokens.alpha(row.auto ? Tokens.text3 : (Tokens.duo ? Tokens.cyan : Tokens.accent), .14)
                            Text {
                                anchors.centerIn: parent
                                text: Tokens.glyph(row.auto ? 0xF0450 : 0xF0C55)
                                font.family: Tokens.iconFont; font.pixelSize: 17
                                color: row.auto ? Tokens.text2 : (Tokens.duo ? Tokens.cyan : Tokens.accent)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: row.modelData.label || page.when(row.modelData.created)
                                    font.family: Tokens.font; font.pixelSize: Tokens.px(13); font.weight: Font.DemiBold; color: Tokens.text
                                    elide: Text.ElideRight; Layout.maximumWidth: 360
                                }
                                Rectangle {
                                    visible: row.auto
                                    implicitWidth: autoText.implicitWidth + 12; implicitHeight: 18; radius: 9
                                    color: Tokens.alpha(Tokens.text, .07)
                                    Text { id: autoText; anchors.centerIn: parent; text: "авто"; font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.text2 }
                                }
                                Rectangle {
                                    visible: row.index === 0
                                    implicitWidth: lastText.implicitWidth + 12; implicitHeight: 18; radius: 9
                                    color: Tokens.alpha(Tokens.acid, .14)
                                    Text { id: lastText; anchors.centerIn: parent; text: "последняя"; font.family: Tokens.font; font.pixelSize: Tokens.px(10); color: Tokens.acid }
                                }
                            }
                            Text {
                                text: (row.modelData.label ? page.when(row.modelData.created) + " · " : "") + page.size(row.modelData.size) + (row.modelData.files ? " · файлов: " + row.modelData.files : "")
                                font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: row.asking
                            text: page.confirmAction === "delete" ? "Удалить без возврата?" : "Текущее состояние сохранится"
                            font.family: Tokens.font; font.pixelSize: Tokens.px(11)
                            color: page.confirmAction === "delete" ? Tokens.danger : Tokens.text2
                        }
                        StyledButton {
                            visible: row.asking
                            text: "Отмена"; flat: true
                            onClicked: { page.confirm = ""; page.confirmAction = ""; }
                        }
                        StyledButton {
                            visible: !row.asking || page.confirmAction === "restore"
                            primary: row.asking
                            text: "Восстановить"
                            enabled: !page.busy
                            opacity: row.asking || hover.hovered ? 1 : .75
                            onClicked: {
                                if (row.asking) page.run(["restore", row.modelData.name]);
                                else { page.confirm = row.modelData.name; page.confirmAction = "restore"; }
                            }
                        }
                        StyledButton {
                            visible: !row.asking || page.confirmAction === "delete"
                            Layout.preferredWidth: row.asking ? 96 : Tokens.controlHeight
                            flat: !row.asking
                            text: row.asking ? "Удалить" : Tokens.glyph(0xF01B4)
                            font.family: row.asking ? Tokens.font : Tokens.iconFont
                            font.pixelSize: row.asking ? Tokens.px(12) : 15
                            enabled: !page.busy
                            ToolTip.visible: hovered && !row.asking; ToolTip.delay: 400; ToolTip.text: "Удалить копию"
                            onClicked: {
                                if (row.asking) page.run(["delete", row.modelData.name]);
                                else { page.confirm = row.modelData.name; page.confirmAction = "delete"; }
                            }
                        }
                    }
                }
            }
        }
    }
}
