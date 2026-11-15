pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

ColumnLayout {
    id: page
    property var settings: ({})
    readonly property bool busy: worker.running
    property bool loaded: false
    property bool dirty: false
    property bool canRestore: false
    property int tab: 0
    property string status: "Загрузка…"
    property string error: ""
    property string search: ""
    property string wallpaper: ""
    readonly property string backend: Quickshell.env("HOME") + "/.local/share/rice-settings/deck.py"
    readonly property var installed: DesktopEntries.applications.values.filter(a => a.name && a.id && !a.noDisplay && (!search || (a.name + " " + a.id).toLowerCase().includes(search.toLowerCase()))).sort((a,b) => a.name.localeCompare(b.name))
    spacing: 14
    function set(key,value) { if(worker.running || settings[key]===value)return;var next=Object.assign({},settings); next[key]=value; settings=next; error=""; touched(); }
    function setMany(values) { if(worker.running)return; settings=Object.assign({},settings,values); error=""; touched(); }

    // live: the dock watches deck.json, so a write shows up instantly. First write of a
    //    session keeps a backup ("apply"), the rest skip it ("preview"); "Откатить" undoes the session.
    readonly property bool live: Tokens.opt.liveApply !== false
    property bool liveBackedUp: false
    property bool livePending: false
    function touched() { if (live && loaded) { dirty=false; liveTimer.restart(); } else dirty=true; }
    Timer { id: liveTimer; interval: 160; onTriggered: page.pushLive() }
    function pushLive() {
        if (previewer.running) { livePending=true; return; }
        previewer.command=["python3",backend,liveBackedUp ? "preview" : "apply"]; liveBackedUp=true; previewer.running=true;
    }
    onLiveChanged: if (live && dirty) { dirty=false; pushLive(); }
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
    readonly property var looks: [
        { name: "Стекло",   values: { parts: 1, radius: 24, gap: 0,  opacity: .38, borderOpacity: .3,  borderWidth: 1, gradient: true,  padding: 8,  iconRadius: 14 } },
        { name: "Капсулы",  values: { parts: 3, radius: 26, gap: 12, opacity: .5,  borderOpacity: .3,  borderWidth: 1, gradient: true,  padding: 6,  iconRadius: 16 } },
        { name: "Острова",  values: { parts: 2, radius: 18, gap: 18, opacity: .72, borderOpacity: .22, borderWidth: 1, gradient: false, padding: 8,  iconRadius: 12 } },
        { name: "Пилюля",   values: { parts: 1, radius: 40, gap: 0,  opacity: .6,  borderOpacity: .45, borderWidth: 2, gradient: true,  padding: 10, iconRadius: 25 } },
        { name: "Монолит",  values: { parts: 1, radius: 0,  gap: 0,  opacity: .92, borderOpacity: 0,   borderWidth: 0, gradient: false, padding: 6,  iconRadius: 0 } },
        { name: "Невидимка", values: { parts: 1, radius: 20, gap: 0, opacity: 0,   borderOpacity: 0,   borderWidth: 0, gradient: false, padding: 4,  iconRadius: 14 } }
    ]
    function read() { run("read"); }
    function run(action) { if (worker.running) return; error=""; worker.command=["python3",backend,action]; worker.running=true; }
    function move(index,direction) { var apps=settings.apps.slice(), next=index+direction; if(next<0 || next>=apps.length) return; var item=apps.splice(index,1)[0]; apps.splice(next,0,item); set("apps",apps); }
    function add(entry) {
        if ((settings.apps || []).some(a => a.id === entry.id)) return;
        var stem=entry.startupClass || entry.id.replace(/\.desktop$/, "").split(".").pop();
        var match=stem.replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
        set("apps",(settings.apps || []).concat([{id:entry.id,name:entry.name,icon:entry.icon || "application-x-executable",match:match}]));
    }
    function hex(v, f) { return /^#[0-9a-fA-F]{6}$/.test(v || "") ? v : f; }
    Component.onCompleted: read()
    Process {
        id: worker
        stdinEnabled: true
        onStarted: { if (command[2] === "apply") write(JSON.stringify(page.settings)); stdinEnabled=false; }
        onExited: stdinEnabled=true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result=JSON.parse(text);
                    if(result.error) { page.error=result.error; return; }
                    page.settings=result.settings; page.loaded=true; page.dirty=false; page.canRestore=result.canRestore; page.liveBackedUp=false;
                    page.status=result.message || "Все изменения сохранены";
                } catch(e) { page.error="Ошибка: "+e; }
            }
        }
    }

    component Num: SettingRow {
        id: num
        property string key
        property real min: 0
        property real max: 100
        property real factor: 1
        property string unit: ""
        property real def: NaN
        ValueSlider {
            from: num.min; to: num.max; unit: num.unit; defaultValue: num.def * num.factor
            value: Math.round((page.settings[num.key] || 0) * num.factor)
            onEdited: v => page.set(num.key, v / num.factor)
        }
    }
    component Toggle: SettingRow {
        id: tog
        property string key
        property bool fallback: false
        StyledCheckBox { checked: page.settings[tog.key] === undefined ? tog.fallback : !!page.settings[tog.key]; onToggled: page.set(tog.key, checked) }
    }
    component Swatch: SettingRow {
        id: sw
        property string key
        ColorField { title: sw.label; value: page.settings[sw.key] || ""; onEdited: h => page.set(sw.key, h) }
    }

    Segmented { model: ["Форма", "Цвета", "Приложения"]; current: page.tab; onActivated: index => page.tab = index }
    BarStage {
        Layout.fillWidth: true
        visible: page.loaded && page.tab < 2
        kind: "deck"; appearance: page.settings; wallpaper: page.wallpaper; live: page.live
        onAppearanceEdited: (key, value) => page.set(key, value)
    }

    Flickable {
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; contentHeight: body.implicitHeight; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: body
            enabled: !page.busy && page.loaded
            width: parent.width - 12; spacing: 18

            // Form
            Group {
                visible: page.tab === 0; title: "Готовые стили"
                Item {
                    Layout.fillWidth: true; implicitHeight: deckLooks.implicitHeight + 24
                    PresetStrip {
                        id: deckLooks
                        x: 12; y: 12; width: parent.width - 24
                        presets: page.looks; base: page.settings; wallpaper: page.wallpaper; dock: true; alphaScale: 1
                        onChosen: values => page.setMany(values)
                    }
                }
            }
            Group {
                visible: page.tab === 0; title: "Расположение"
                SettingRow {
                    label: "Положение"
                    Segmented { model: ["Слева", "По центру", "Справа"]; current: Math.max(0, ["left","center","right"].indexOf(page.settings.alignment || "center")); onActivated: index => page.set("alignment", ["left","center","right"][index]) }
                }
                Num { label: "Отступ от нижнего края"; key: "bottomMargin"; max: 100; unit: " px"; def: 10 }
                Num { label: "Размер дока"; key: "scale"; min: 70; max: 180; factor: 100; unit: "%"; def: 1.25 }
            }
            Group {
                visible: page.tab === 0; title: "Форма"
                SettingRow {
                    label: "Блоки"
                    PartsPicker { dock: true; labels: ["Цельный", "2 блока", "3 блока", "4 блока"]; current: page.settings.parts || 1; onChosen: n => page.set("parts", n) }
                }
                Num { label: "Скругление блоков"; key: "radius"; max: 40; unit: " px"; def: 23 }
                Num { label: "Скругление плиток"; key: "iconRadius"; max: 25; unit: " px"; def: 13 }
                Num { label: "Отступ между блоками"; key: "gap"; max: 60; unit: " px"; def: 0 }
                Num { label: "Внутренние отступы"; key: "padding"; max: 24; unit: " px"; def: 7 }
                Num { label: "Толщина рамки"; key: "borderWidth"; max: 5; unit: " px"; def: 1 }
            }
            Group {
                visible: page.tab === 0; title: "Поведение"
                Toggle { label: "Скрывать автоматически"; key: "autoHide" }
                SettingRow {
                    label: "Задержка скрытия"
                    visible: !!page.settings.autoHide
                    ValueSlider { from: 0; to: 3000; step: 50; unit: " мс"; defaultValue: 450; value: page.settings.hideDelay === undefined ? 450 : page.settings.hideDelay; onEdited: v => page.set("hideDelay", v) }
                }
                Toggle { label: "Увеличивать иконки при наведении"; key: "zoom" }
                Toggle { label: "Кнопка поиска приложений"; key: "showLauncher" }
                Toggle { label: "Показывать открытые незакреплённые"; key: "showRunning" }
            }

            // Colours
            Group {
                visible: page.tab === 1; title: "Поверхность"
                Swatch { label: "Фон"; key: "background" }
                Swatch { label: "Верх градиента"; key: "highlight" }
                Toggle { label: "Градиент фона"; key: "gradient" }
                Num { label: "Непрозрачность фона"; key: "opacity"; factor: 100; unit: "%"; def: .86 }
            }
            Group {
                visible: page.tab === 1; title: "Детали"
                Swatch { label: "Иконки и акценты"; key: "accent" }
                Toggle { label: "Окрашивать иконки в цвет акцента"; key: "tintIcons"; fallback: true }
                Swatch { label: "Текст подсказок"; key: "foreground" }
                Swatch { label: "Рамка"; key: "border" }
                Num { label: "Непрозрачность рамки"; key: "borderOpacity"; factor: 100; unit: "%"; def: .5 }
            }

            // Apps
            DockBuilder { visible: page.tab === 2 && page.loaded; Layout.fillWidth: true; page: page; wallpaper: page.wallpaper }
            Group {
                visible: page.tab === 2
                title: "Закреплены · " + (page.settings.apps || []).length
                Repeater {
                    model: page.settings.apps || []
                    SettingRow {
                        id: pinned
                        required property var modelData
                        required property int index
                        label: modelData.name
                        icon: modelData.icon || ""
                        StyledButton { flat: true; implicitWidth: 30; text: "↑"; enabled: pinned.index > 0; onClicked: page.move(pinned.index, -1) }
                        StyledButton { flat: true; implicitWidth: 30; text: "↓"; enabled: pinned.index < (page.settings.apps || []).length - 1; onClicked: page.move(pinned.index, 1) }
                        StyledButton { flat: true; text: "Открепить"; onClicked: { var apps = page.settings.apps.slice(); apps.splice(pinned.index, 1); page.set("apps", apps); } }
                    }
                }
            }
            RowLayout {
                visible: page.tab === 2
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; Layout.leftMargin: 4; text: "Установленные"; font.family: Tokens.font; font.pixelSize: Tokens.px(12); font.weight: Font.Medium; color: Tokens.text2 }
                StyledTextField { Layout.preferredWidth: 220; placeholderText: "Найти приложение"; onTextEdited: page.search = text }
            }
            Group {
                visible: page.tab === 2
                Repeater {
                    model: page.tab === 2 ? page.installed : []
                    SettingRow {
                        id: entry
                        required property var modelData
                        readonly property bool pinned: (page.settings.apps || []).some(a => a.id === modelData.id)
                        label: modelData.name
                        icon: modelData.icon || ""
                        StyledButton { text: entry.pinned ? "В доке" : "Закрепить"; flat: entry.pinned; enabled: !entry.pinned; onClicked: page.add(entry.modelData) }
                    }
                }
                SettingRow { visible: page.installed.length === 0; label: "Ничего не найдено" }
            }
        }
    }
    ApplyBar {
        dirty: page.dirty; busy: worker.running; loaded: page.loaded; canRestore: page.canRestore
        liveCapable: true
        status: page.status; error: page.error
        onApply: page.run("apply"); onRevert: page.read(); onRestore: page.run("restore")
    }
}
