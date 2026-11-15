pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page
    property var settings: ({})
    property bool dirty: false
    readonly property bool busy: worker.running
    property bool loaded: false
    property bool canRestore: false
    property string status: "Загрузка…"
    property string error: ""
    readonly property var fonts: Qt.fontFamilies().sort()
    readonly property var suggested: ["Noto Sans", "Adwaita Sans", "Inter", "Manrope", "Rubik", "JetBrains Mono"].filter(f => fonts.indexOf(f) >= 0)
    spacing: 18
    function set(key,value) { if(worker.running || settings[key]===value)return;var next=Object.assign({},settings);next[key]=value;settings=next;dirty=true;error=""; }
    function run(action) { if(worker.running)return;error="";worker.command=["python3",Quickshell.env("HOME")+"/.local/share/rice-settings/global_style.py",action];worker.running=true; }
    Component.onCompleted: run("read")
    Process {
        id: worker
        stdinEnabled: true
        onStarted: { if(command[2]==="apply")write(JSON.stringify(page.settings));stdinEnabled=false; }
        onExited: stdinEnabled=true
        stdout: StdioCollector { onStreamFinished: { try { var d=JSON.parse(text);if(d.error){page.error=d.error;return;}page.settings=d.settings;page.loaded=true;page.dirty=false;page.canRestore=d.canRestore;page.status=d.message || "Все изменения сохранены"; }catch(e){page.error=String(e);} } }
    }

    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentHeight: body.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            width: parent.width - 12
            spacing: 18

            // Specimen in the draft font, over the draft glass density.
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 128
                radius: Tokens.radius
                color: Qt.rgba(Tokens.base.r * .8, Tokens.base.g * .8, Tokens.base.b * .8, Math.min(1, .78 * (page.settings.glassOpacity || 1)))
                border.width: 1; border.color: Tokens.line
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 20
                    spacing: 4
                    Text { text: page.settings.fontFamily || "Noto Sans"; font.family: Tokens.font; font.pixelSize: Tokens.px(11); color: Tokens.text3 }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Съешь же ещё этих мягких булок"; font.family: page.settings.fontFamily || "Noto Sans"; font.pixelSize: 26 * (page.settings.textScale || 1); color: Tokens.text }
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "The quick brown fox · 0123456789 · 14:30"; font.family: page.settings.fontFamily || "Noto Sans"; font.pixelSize: 14 * (page.settings.textScale || 1); color: Tokens.text2 }
                }
            }

            Group {
                title: "Шрифт"
                SettingRow {
                    label: "Шрифт интерфейса"
                    StyledComboBox { width: 260; model: page.fonts; currentIndex: Math.max(0, page.fonts.indexOf(page.settings.fontFamily || "Noto Sans")); onActivated: page.set("fontFamily", currentText) }
                }
                SettingRow {
                    label: "Масштаб текста"
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight; text: Math.round((page.settings.textScale || 1) * 100) + "%"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
                    StyledSlider { width: 200; from: 80; to: 150; stepSize: 5; value: (page.settings.textScale || 1) * 100; onMoved: page.set("textScale", Math.round(value / 5) * 5 / 100) }
                }
            }
            Group {
                title: "Стекло"
                SettingRow {
                    label: "Плотность стекла"
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight; text: Math.round((page.settings.glassOpacity || 1) * 100) + "%"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); color: Tokens.text2 }
                    StyledSlider { width: 200; from: 30; to: 150; stepSize: 5; value: (page.settings.glassOpacity || 1) * 100; onMoved: page.set("glassOpacity", Math.round(value / 5) * 5 / 100) }
                }
            }
        }
    }
    ApplyBar {
        dirty: page.dirty; busy: worker.running; loaded: page.loaded; canRestore: page.canRestore
        status: page.status; error: page.error
        onApply: page.run("apply"); onRevert: page.run("read"); onRestore: page.run("restore")
    }
}
